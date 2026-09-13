#Requires -Version 5.1
<#
.SYNOPSIS
    Saves every ACPI firmware table this machine reports, ready to decompile.

.DESCRIPTION
    Reads the ACPI tables Windows publishes under HKLM\HARDWARE\ACPI and writes
    each one to a .bin file, plus an index describing what was found.

    This is step 1 of 3. It is read-only. It reads the registry and writes files
    into the output folder. It touches no driver and no hardware.

    Why the registry and not the GetSystemFirmwareTable API: a machine has many
    SSDT tables and they all share the signature "SSDT", so the API can only
    hand back the first one. The registry stores each under its own name (SSDT,
    SSD1, SSD2 ...), so this way gets all of them. The reference M70t had 22.

.PARAMETER OutDir
    Where to write the files. Defaults to docs\research\recon-3111 in this repo.
    Change it if you are probing a board other than 3111.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\01-dump-acpi.ps1
#>
[CmdletBinding()]
param(
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

Reset-Recon
Write-Recon ("=== ACPI TABLE DUMP {0} ===" -f (Get-ReconStamp))
Write-Recon ("output folder: {0}" -f $OutDir)
Write-Recon ''

$acpiRoot = 'HKLM:\HARDWARE\ACPI'
if (-not (Test-Path -LiteralPath $acpiRoot)) {
    Write-Recon "ERROR: $acpiRoot does not exist. This is not a Windows machine with ACPI tables in the registry."
    Save-Recon -Path (Join-Path $OutDir 'acpi-index.txt')
    exit 1
}

$saved = 0
$skipped = 0
$usedNames = @{}

# Recurse the whole ACPI subtree rather than assuming a fixed depth. The layout
# is <TABLE>\<OEM ID>\<OEM table ID>\<OEM revision>, but depth has varied
# between Windows versions, and a wrong assumption here would silently miss
# tables instead of failing loudly.
$keys = Get-ChildItem -Path $acpiRoot -Recurse -ErrorAction SilentlyContinue
foreach ($key in $keys) {
    $valueNames = @($key.GetValueNames())
    foreach ($valueName in $valueNames) {

        if ($key.GetValueKind($valueName) -ne [Microsoft.Win32.RegistryValueKind]::Binary) { continue }

        $data = [byte[]]$key.GetValue($valueName)
        $header = Get-AcpiTableHeader -Data $data
        if ($null -eq $header) {
            $skipped++
            continue
        }

        # HKEY_LOCAL_MACHINE\HARDWARE\ACPI\DSDT\LENOVO\TC-M5O__\00013d0
        # becomes                          DSDT\LENOVO\TC-M5O__\00013d0
        $marker = '\ACPI\'
        $markerIndex = $key.Name.IndexOf($marker)
        if ($markerIndex -lt 0) { continue }
        $relative = $key.Name.Substring($markerIndex + $marker.Length)

        $stem = ConvertTo-ReconSafeName $relative
        if ($valueName -ne '00000000' -and -not [string]::IsNullOrEmpty($valueName)) {
            $stem = $stem + '_' + (ConvertTo-ReconSafeName $valueName)
        }

        # Two registry values could sanitise to the same filename. Never let one
        # table silently overwrite another: count how many times each stem has
        # been seen and add a suffix from the second one onwards.
        if ($usedNames.ContainsKey($stem)) {
            $usedNames[$stem] = $usedNames[$stem] + 1
            $fileName = 'acpireg-{0}-{1}.bin' -f $stem, $usedNames[$stem]
        }
        else {
            $usedNames[$stem] = 1
            $fileName = 'acpireg-{0}.bin' -f $stem
        }

        [System.IO.File]::WriteAllBytes((Join-Path $OutDir $fileName), $data)
        $saved++

        $lengthNote = ''
        if (-not $header.LengthMatches) {
            $lengthNote = (' TRUNCATED? header says {0} bytes' -f $header.DeclaredLength)
        }
        Write-Recon ('{0,-6} oem={1,-8} table={2,-10} rev={3,-6} {4,7} bytes  {5}{6}' -f `
            $header.Signature, $header.OemId, $header.OemTableId, $header.OemRevision, `
            $data.Length, $fileName, $lengthNote)
    }
}

Write-Recon ''
Write-Recon ("saved {0} ACPI table(s); skipped {1} binary value(s) that were not ACPI tables" -f $saved, $skipped)
Write-Recon ''

if ($saved -eq 0) {
    Write-Recon 'WARNING: no tables were saved. Run this script again from an elevated PowerShell window.'
}
else {
    Write-Recon 'Next: decompile the tables to read them.'
    Write-Recon '  1. Get iasl.exe for Windows from the ACPICA project at acpica.org.'
    Write-Recon '  2. Put iasl.exe in the output folder.'
    Write-Recon '  3. Run this command for each file:   iasl -d acpireg-<name>.bin'
    Write-Recon '  4. Search the .dsl output for these names: _FIF, _FSL, _FST, FNSL, PNP0C0B.'
    Write-Recon '  5. Also search for: OperationRegion and EmbeddedControl.'
    Write-Recon ''
    Write-Recon 'What the result means:'
    Write-Recon '  - An EmbeddedControl OperationRegion means the ACPI embedded controller is real.'
    Write-Recon '    Your machine is then NOT in the same situation as the reference M70t.'
    Write-Recon '  - No EmbeddedControl region, and an H_EC whose _STA returns Zero, means the'
    Write-Recon '    ACPI embedded controller is a stub. That matches the reference M70t.'
}

$indexPath = Join-Path $OutDir 'acpi-index.txt'
Save-Recon -Path $indexPath
Write-Host ''
Write-Host "index written to $indexPath"
