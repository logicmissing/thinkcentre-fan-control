#Requires -Version 5.1
<#
.SYNOPSIS
    Reads all 256 bytes of embedded controller RAM and says whether a real EC answered.

.DESCRIPTION
    This is the one experiment that decided the whole reference project. On the
    M70t the ACPI tables said the embedded controller did not exist, yet a
    physical EC answered on ports 0x62 and 0x66 with real data. That is why the
    app can report a fan speed nothing else can.

    This script asks the same question about your board, and nothing more.

    Step 3 of 3. It READS EC RAM only. It writes two bytes to the EC ports as
    part of the standard ACPI read handshake: the read command 0x80, and the
    offset to read. It never sends the write command 0x81, and the port
    whitelist that enforces this is inside the compiled helper, not in script
    that a typo could bypass. The handshake is a copy of the one in
    src\Tcfc.Core\EcReader.cs, which is verified on real hardware.

.PARAMETER Label
    A word describing machine state during this run, used in the filename.
    Run once with "idle" and once with "load" to get two dumps you can compare.

.PARAMETER ModulePath
    Full path to LpcACPIEC.bin. Found automatically if it sits in the usual places.

.PARAMETER OutDir
    Where to write the dump. Defaults to docs\research\recon-3111.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\03-dump-ec.ps1 -Label idle
#>
[CmdletBinding()]
param(
    [string]$Label = 'idle',
    [string]$ModulePath,
    [string]$OutDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Recon.Common.ps1')

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $repoRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
    $OutDir = Join-Path (Join-Path (Join-Path $repoRoot 'docs') 'research') 'recon-3111'
}
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

# --- Elevation ---------------------------------------------------------------
$isAdmin = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
catch {
    $isAdmin = $false
}
if (-not $isAdmin) {
    Write-Host 'ERROR: this script needs Administrator rights.'
    Write-Host 'Close this window. Open PowerShell again with "Run as administrator". Then run it again.'
    exit 1
}

# --- Find the PawnIO EC module ----------------------------------------------
if ([string]::IsNullOrWhiteSpace($ModulePath)) {
    $repoRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
    $candidates = @(
        (Join-Path $PSScriptRoot 'LpcACPIEC.bin'),
        (Join-Path (Join-Path (Join-Path $repoRoot 'lib') 'pawnio') 'LpcACPIEC.bin'),
        'C:\Program Files\PawnIO\modules\LpcACPIEC.bin'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { $ModulePath = $candidate; break }
    }
}
if ([string]::IsNullOrWhiteSpace($ModulePath) -or -not (Test-Path -LiteralPath $ModulePath)) {
    Write-Host 'ERROR: LpcACPIEC.bin was not found.'
    Write-Host 'Do these steps:'
    Write-Host '  1. Install PawnIO from pawnio.eu.'
    Write-Host '  2. Download the project release ZIP. It contains LpcACPIEC.bin.'
    Write-Host '  3. Copy LpcACPIEC.bin into this scripts\recon folder.'
    Write-Host '  4. Run this script again.'
    exit 1
}

# --- Native helper -----------------------------------------------------------
# The handshake lives here rather than in PowerShell for two reasons: it mirrors
# the verified C# in EcReader.cs line for line, and the port whitelist cannot be
# bypassed by a mistake in script code.
if (-not ([System.Management.Automation.PSTypeName]'TcfcEcProbe').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class TcfcEcProbe
{
    // ACPI embedded controller interface. Fixed by the ACPI specification.
    private const int EcData = 0x62;           // data port
    private const int EcStatusCommand = 0x66;  // status (read) / command (write) port
    private const int Obf = 0x01;              // output buffer full: a byte is ready on 0x62
    private const int Ibf = 0x02;              // input buffer full: the EC has not taken our last write
    private const int RdEc = 0x80;             // command: read one byte of EC RAM

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool SetDllDirectory(string path);

    [DllImport("PawnIOLib.dll")]
    private static extern int pawnio_open(out IntPtr handle);

    [DllImport("PawnIOLib.dll")]
    private static extern int pawnio_load(IntPtr handle, byte[] blob, UIntPtr size);

    [DllImport("PawnIOLib.dll", CharSet = CharSet.Ansi)]
    private static extern int pawnio_execute(
        IntPtr handle, string name, long[] input, UIntPtr inputCount,
        long[] output, UIntPtr outputCount, out UIntPtr returned);

    [DllImport("PawnIOLib.dll")]
    private static extern int pawnio_close(IntPtr handle);

    static TcfcEcProbe()
    {
        // PawnIO's install directory is not on the default DLL search path.
        SetDllDirectory(@"C:\Program Files\PawnIO");
    }

    public static IntPtr Open(byte[] blob)
    {
        IntPtr handle;
        int hr = pawnio_open(out handle);
        if (hr != 0)
            throw new Exception("pawnio_open failed with HRESULT 0x" + hr.ToString("X8"));

        hr = pawnio_load(handle, blob, (UIntPtr)(uint)blob.Length);
        if (hr != 0)
        {
            pawnio_close(handle);
            throw new Exception("pawnio_load failed with HRESULT 0x" + hr.ToString("X8"));
        }
        return handle;
    }

    public static void Close(IntPtr handle)
    {
        if (handle != IntPtr.Zero)
            pawnio_close(handle);
    }

    // The ONLY two ports this probe may touch. Anything else throws.
    private static void RequireEcPort(int port)
    {
        if (port != EcData && port != EcStatusCommand)
            throw new ArgumentOutOfRangeException("port", port, "Only EC ports 0x62 and 0x66 are allowed.");
    }

    private static int PioRead(IntPtr handle, int port)
    {
        RequireEcPort(port);
        long[] input = new long[] { port };
        long[] output = new long[1];
        UIntPtr returned;
        int hr = pawnio_execute(handle, "ioctl_pio_read", input, (UIntPtr)1, output, (UIntPtr)1, out returned);
        if (hr != 0)
            throw new Exception("ioctl_pio_read failed with HRESULT 0x" + hr.ToString("X8"));
        return (int)(output[0] & 0xFF);
    }

    // Handshake bytes only: the read command and the offset. Never EC RAM data,
    // and never the 0x81 write command.
    private static void PioWrite(IntPtr handle, int port, int value)
    {
        RequireEcPort(port);
        if (port == EcStatusCommand && value != RdEc)
            throw new ArgumentOutOfRangeException("value", value, "Only the RD_EC (0x80) command may be sent to 0x66.");
        long[] input = new long[] { port, value };
        long[] output = new long[1];
        UIntPtr returned;
        int hr = pawnio_execute(handle, "ioctl_pio_write", input, (UIntPtr)2, output, UIntPtr.Zero, out returned);
        if (hr != 0)
            throw new Exception("ioctl_pio_write failed with HRESULT 0x" + hr.ToString("X8"));
    }

    public static int Status(IntPtr handle)
    {
        return PioRead(handle, EcStatusCommand);
    }

    private static bool WaitFlag(IntPtr handle, int mask, bool wantSet)
    {
        // No sleep: each read is a full kernel round-trip, which paces the poll.
        for (int i = 0; i < 200; i++)
        {
            int status = PioRead(handle, EcStatusCommand);
            if (((status & mask) != 0) == wantSet)
                return true;
        }
        return false;
    }

    /// <summary>One byte of EC RAM. Returns -1 if the handshake timed out.</summary>
    public static int ReadByte(IntPtr handle, int offset)
    {
        if (offset < 0 || offset > 0xFF)
            throw new ArgumentOutOfRangeException("offset", offset, "EC RAM offsets are 0x00..0xFF.");

        // Drain a stale byte left by a timed-out transaction, ours or another
        // program's. The EC only ever has one pending.
        for (int i = 0; i < 16 && (PioRead(handle, EcStatusCommand) & Obf) != 0; i++)
            PioRead(handle, EcData);

        if (!WaitFlag(handle, Ibf, false)) return -1;
        PioWrite(handle, EcStatusCommand, RdEc);
        if (!WaitFlag(handle, Ibf, false)) return -1;
        PioWrite(handle, EcData, offset);
        if (!WaitFlag(handle, Obf, true)) return -1;
        return PioRead(handle, EcData);
    }
}
'@
}

Reset-Recon
Write-Recon ("=== EC RAM DUMP {0}  label={1} ===" -f (Get-ReconStamp), $Label)
Write-Recon ("module: {0}" -f $ModulePath)
Write-Recon ''

$blob = [System.IO.File]::ReadAllBytes($ModulePath)

$handle = [IntPtr]::Zero
try {
    $handle = [TcfcEcProbe]::Open($blob)
}
catch {
    Write-Recon ('ERROR: could not open PawnIO: {0}' -f (Get-ReconErrorText $_.Exception.Message))
    Write-Recon 'Check that PawnIO is installed and that this window is elevated.'
    Save-Recon -Path (Join-Path $OutDir ("ec-dump-{0}.txt" -f (ConvertTo-ReconSafeName $Label)))
    exit 1
}

# The EC lock is shared with the firmware and with every other program that
# reads the EC. Hold it per transaction only; holding it longer starves them.
$ecMutex = $null
try { $ecMutex = [System.Threading.Mutex]::OpenExisting('Global\Access_EC') }
catch {
    try { $ecMutex = New-Object System.Threading.Mutex($false, 'Global\Access_EC') }
    catch { $ecMutex = $null }
}
if ($null -eq $ecMutex) {
    Write-Recon 'NOTE: the shared EC lock could not be taken. Reads continue without it.'
    Write-Recon ''
}

$bytes = New-Object int[] 256
try {
    Write-Recon ('initial status @0x66 = 0x{0:X2}' -f [TcfcEcProbe]::Status($handle))
    Write-Recon ''

    for ($offset = 0; $offset -lt 256; $offset++) {
        $locked = $false
        if ($null -ne $ecMutex) {
            try { $locked = $ecMutex.WaitOne(500) }
            catch [System.Threading.AbandonedMutexException] { $locked = $true }
        }
        try {
            $bytes[$offset] = [TcfcEcProbe]::ReadByte($handle, $offset)
        }
        finally {
            if ($locked) { try { $ecMutex.ReleaseMutex() } catch { } }
        }
    }
}
finally {
    [TcfcEcProbe]::Close($handle)
    if ($null -ne $ecMutex) { $ecMutex.Dispose() }
}

foreach ($line in @(Format-EcHexDump -Bytes $bytes)) {
    Write-Recon $line
}
Write-Recon ''
Write-Recon '-- means that offset did not answer in time. It is not a value of zero.'
Write-Recon ''

$verdict = Get-EcVerdict -Bytes $bytes
Write-Recon ('VERDICT: {0}' -f $verdict.Verdict)
Write-Recon ('  {0}' -f $verdict.Detail)
Write-Recon ('  bytes read {0}, timed out {1}, distinct values {2}' -f `
    $verdict.BytesRead, $verdict.BytesTimedOut, $verdict.DistinctValues)
Write-Recon ''

$candidates = @(Get-EcWordCandidates -Bytes $bytes)
Write-Recon ('### 16-bit values in a plausible fan range ({0} found)' -f $candidates.Count)
Write-Recon 'On the reference board the real tachometer was offset 0x00, big-endian.'
Write-Recon 'A value landing in range proves nothing on its own. It is a shortlist.'
Write-Recon ''
foreach ($candidate in $candidates) {
    Write-Recon ('  offset 0x{0:X2}  {1,-13} {2} rpm?' -f $candidate.Offset, $candidate.Order, $candidate.Value)
}
Write-Recon ''
Write-Recon 'Next:'
Write-Recon '  1. Run this script again with -Label load while the CPU is busy.'
Write-Recon '  2. Compare the two dumps. A real tachometer rises a lot under load.'
Write-Recon '  3. A byte that rises a little is probably a temperature, not the fan.'
Write-Recon '  4. Send both dumps back. Do not write to any EC offset yet.'

$outPath = Join-Path $OutDir ("ec-dump-{0}.txt" -f (ConvertTo-ReconSafeName $Label))
Save-Recon -Path $outPath
Write-Host ''
Write-Host "dump written to $outPath"
