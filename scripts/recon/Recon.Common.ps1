# Shared helpers for the recon scripts in this folder.
#
# Every function here is pure: string, byte and array work only. Nothing in
# this file touches the registry, WMI, a driver, or any hardware. That is
# deliberate - it means the logic can be tested on any machine, including a
# Linux container, by Test-ReconCommon.ps1 next to this file. The Windows-only
# work lives in the numbered scripts that dot-source this one.
#
# Targets Windows PowerShell 5.1, which is what ships with Windows 10 and 11.
# Do not use PowerShell 7-only syntax here (no ternary ?:, no ??, no
# three-argument Join-Path, no $IsWindows).

Set-StrictMode -Version Latest

# A note on the functions that return a list (Format-EcHexDump,
# Get-EcWordCandidates): PowerShell unrolls a returned array, so an empty
# result arrives as $null and a single result arrives as a bare item. Always
# wrap the call in @( ) at the call site:
#
#     $candidates = @(Get-EcWordCandidates -Bytes $bytes)
#
# Then .Count is always right, even when nothing matched, and piping still
# works normally. Every caller in this folder follows that rule.

# --- Output collection -------------------------------------------------------
# Each script collects its report in one list, prints it as it goes, and saves
# it at the end. Start-Transcript is deliberately not used: its header records
# the Windows user name, and these reports get committed to a public repo.

function Reset-Recon {
    $script:ReconLines = New-Object System.Collections.Generic.List[string]
}

function Write-Recon {
    param([string]$Text = '')
    if (-not (Test-Path variable:script:ReconLines)) { Reset-Recon }
    $script:ReconLines.Add($Text) | Out-Null
    Write-Host $Text
}

function Save-Recon {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path variable:script:ReconLines)) { Reset-Recon }
    Set-Content -Path $Path -Value $script:ReconLines.ToArray() -Encoding UTF8
}

# --- Timestamps --------------------------------------------------------------

# Always carries the UTC offset, e.g. 2026-09-13T21:04:33+08:00. A timestamp
# without an offset is the repo's bug class 1 (see
# .claude/rules/bug-class-checks.md): it reads as a different instant in a
# different timezone, silently. With the offset attached there is nothing to
# get wrong, so the recon files need no timezone convention of their own.
function Get-ReconStamp {
    return [DateTimeOffset]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz')
}

# --- Errors ------------------------------------------------------------------

# Exception messages often run to several lines. These reports are read as
# aligned single-line records, so a raw multi-line message breaks the layout
# and hides the section it belongs to. Collapse whitespace and cap the length.
function Get-ReconErrorText {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Message, [int]$MaxLength = 160)

    $flat = [regex]::Replace($Message, '\s+', ' ').Trim()
    if ($flat.Length -gt $MaxLength) {
        $flat = $flat.Substring(0, $MaxLength - 3) + '...'
    }
    return $flat
}

# --- Filenames ---------------------------------------------------------------

# Registry key paths and ACPI OEM IDs contain spaces, backslashes and padding
# characters that are not safe in a filename. Everything outside this set
# becomes an underscore.
function ConvertTo-ReconSafeName {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    return [regex]::Replace($Text, '[^A-Za-z0-9\-\.]', '_')
}

# --- ACPI table headers ------------------------------------------------------

# Decodes the 36-byte ACPI table header that every table starts with:
#   0-3   signature (e.g. DSDT, SSDT, FACP)
#   4-7   total length, little-endian
#   8     revision
#   9     checksum
#   10-15 OEM ID
#   16-23 OEM table ID
#   24-27 OEM revision
# Returns $null for anything that is not a plausible ACPI table, so the
# registry walk can skip unrelated binary values without a special case.
function Get-AcpiTableHeader {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Data)

    if ($Data.Length -lt 36) { return $null }

    $signature = [System.Text.Encoding]::ASCII.GetString($Data, 0, 4)
    # Real signatures are printable ASCII. Some tables pad with spaces, and a
    # few use '!' or '4', so the set is deliberately a little wider than A-Z.
    if ($signature -notmatch '^[A-Za-z0-9!_ ]{4}$') { return $null }

    $declaredLength = [BitConverter]::ToUInt32($Data, 4)

    return [pscustomobject]@{
        Signature      = $signature.Trim()
        DeclaredLength = [int]$declaredLength
        ActualLength   = $Data.Length
        LengthMatches  = ([int]$declaredLength -eq $Data.Length)
        Revision       = [int]$Data[8]
        OemId          = ([System.Text.Encoding]::ASCII.GetString($Data, 10, 6)).Trim()
        OemTableId     = ([System.Text.Encoding]::ASCII.GetString($Data, 16, 8)).Trim()
        OemRevision    = [int][BitConverter]::ToUInt32($Data, 24)
    }
}

# --- WMI method safety gate --------------------------------------------------

# The WMI probe must never change anything. Two independent gates, both of
# which a method name has to pass:
#   1. It must start with Get or Is. Lenovo's read methods all do.
#   2. It must not mention a subject that can lock a machine out of its own
#      firmware, whatever its prefix says.
# The bias is deliberate: wrongly refusing a read costs one missing line in a
# report, wrongly allowing a write can brick a BIOS.
function Test-ReconSafeMethod {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name)

    if ($Name -match '(?i)(password|certif|wipe|secure|tpm|key|flash|update)') { return $false }
    return ($Name -match '^(Get|Is)')
}

# --- EC dump formatting ------------------------------------------------------

# Renders 256 EC bytes as a classic hex dump. A value of -1 means that offset's
# read handshake timed out; it prints as "--" so a failed read is never
# confused with a real 0x00 - which is exactly the mistake this whole project
# exists to avoid.
function Format-EcHexDump {
    param([Parameter(Mandatory = $true)][int[]]$Bytes)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('      00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F') | Out-Null

    for ($row = 0; $row -lt $Bytes.Length; $row += 16) {
        $cells = @()
        for ($col = 0; $col -lt 16; $col++) {
            $index = $row + $col
            if ($index -ge $Bytes.Length) {
                $cells += '  '
            }
            elseif ($Bytes[$index] -lt 0) {
                $cells += '--'
            }
            else {
                $cells += ('{0:X2}' -f $Bytes[$index])
            }
            if ($col -eq 7) { $cells += '' }
        }
        $lines.Add(('{0:X2}:   {1}' -f $row, ($cells -join ' '))) | Out-Null
    }

    # Returned unrolled on purpose; wrap the call in @( ) - see the note at the
    # top of this file.
    return $lines.ToArray()
}

# The one question this whole EC dump exists to answer: is there a real
# embedded controller behind ports 0x62/0x66, or is the ACPI layer lying and
# nothing is home? On the reference M70t all 256 offsets answered with varied
# data even though ACPI reported the EC as absent. A dump that is entirely
# 0x00, entirely 0xFF, or entirely timeouts means the opposite.
function Get-EcVerdict {
    param([Parameter(Mandatory = $true)][int[]]$Bytes)

    $good = @($Bytes | Where-Object { $_ -ge 0 })
    $distinct = @($good | Sort-Object -Unique)

    $verdict = 'REAL EC'
    $detail = 'Varied data on most offsets. A physical EC answers on 0x62/0x66.'

    if ($good.Count -eq 0) {
        $verdict = 'NO RESPONSE'
        $detail = 'Every offset timed out. No EC answered, or the driver could not reach the ports.'
    }
    elseif ($good.Count -lt ($Bytes.Length / 2)) {
        $verdict = 'MOSTLY TIMEOUTS'
        $detail = 'Over half the offsets timed out. Treat the data as unreliable and run the script again.'
    }
    elseif ($distinct.Count -le 2) {
        $verdict = 'STUBBED OR EMPTY'
        $detail = 'Almost every byte is the same value. This looks like a stub, not a live EC.'
    }

    return [pscustomobject]@{
        Verdict       = $verdict
        Detail        = $detail
        BytesRead     = $good.Count
        BytesTimedOut = ($Bytes.Length - $good.Count)
        DistinctValues = $distinct.Count
    }
}

# Finds every 16-bit word in the dump whose value falls in a plausible desktop
# fan range. On the reference board the tachometer turned out to be 0x00:0x01
# read big-endian. This does not prove anything on its own - a temperature
# pair or a voltage can land in range by chance - but it is the shortlist to
# re-check under load, which is what separates a real tach from a coincidence.
function Get-EcWordCandidates {
    param(
        [Parameter(Mandatory = $true)][int[]]$Bytes,
        [int]$MinRpm = 300,
        [int]$MaxRpm = 6000
    )

    $found = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt ($Bytes.Length - 1); $i++) {
        if ($Bytes[$i] -lt 0 -or $Bytes[$i + 1] -lt 0) { continue }

        $bigEndian = ($Bytes[$i] -shl 8) -bor $Bytes[$i + 1]
        $littleEndian = ($Bytes[$i + 1] -shl 8) -bor $Bytes[$i]

        if ($bigEndian -ge $MinRpm -and $bigEndian -le $MaxRpm) {
            $found.Add([pscustomobject]@{ Offset = $i; Order = 'big-endian'; Value = $bigEndian }) | Out-Null
        }
        if ($littleEndian -ge $MinRpm -and $littleEndian -le $MaxRpm) {
            $found.Add([pscustomobject]@{ Offset = $i; Order = 'little-endian'; Value = $littleEndian }) | Out-Null
        }
    }
    # Returned unrolled on purpose; wrap the call in @( ) - see the note at the
    # top of this file.
    return $found.ToArray()
}
