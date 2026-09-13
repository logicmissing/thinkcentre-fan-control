#Requires -Version 5.1
<#
.SYNOPSIS
    Lists this machine's identity, its Lenovo WMI classes, and every BIOS setting.

.DESCRIPTION
    Answers three questions the fan work depends on:
      1. Which Lenovo WMI classes exist here? The app needs
         LENOVO_GAMEZONE_DATA for fan modes. A 2017 M710q may not have it.
      2. What does each read method report?
      3. What is every BIOS setting called? The app writes one setting named
         IntelligentCoolingPerformanceMode. An older BIOS may use another name,
         or have no cooling setting at all.

    This is step 2 of 3. It is read-only, and enforced as read-only twice over:
    a method is invoked only if its name starts with Get or Is AND does not
    mention a password, certificate, key, secure boot, TPM, wipe, flash or
    update. Test-ReconSafeMethod in Recon.Common.ps1 is that gate, and it has
    tests. Nothing here calls SetBiosSetting or SaveBiosSettings. Reading a
    BIOS setting does not change it.

.PARAMETER OutDir
    Where to write wmi-probe.txt. Defaults to docs\research\recon-3111.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\02-probe-wmi.ps1
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

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

# Formats whatever an Invoke-CimMethod call returned, without knowing in
# advance which out-parameters the method has.
function Format-CimResult {
    param($Result)
    if ($null -eq $Result) { return '(no result)' }
    $pairs = @()
    foreach ($property in $Result.PSObject.Properties) {
        if ($property.Name -like 'PS*') { continue }
        if ($property.Name -like 'Cim*') { continue }
        $pairs += ('{0}={1}' -f $property.Name, $property.Value)
    }
    if ($pairs.Count -eq 0) { return '(no out-parameters)' }
    return ($pairs -join ' ')
}

Reset-Recon
Write-Recon ("=== LENOVO WMI PROBE {0}  admin={1} ===" -f (Get-ReconStamp), (Test-IsAdministrator))
Write-Recon ''

# --- [0] Machine identity ----------------------------------------------------
# Written first, before anything that can fail, so the report always says which
# machine produced it.
Write-Recon '### [0] Machine identity'
$identityQueries = @(
    @{ Label = 'BaseBoard'; Class = 'Win32_BaseBoard';      Fields = @('Manufacturer', 'Product', 'Version') },
    @{ Label = 'System';    Class = 'Win32_ComputerSystem'; Fields = @('Manufacturer', 'Model', 'SystemFamily') },
    @{ Label = 'BIOS';      Class = 'Win32_BIOS';           Fields = @('Manufacturer', 'SMBIOSBIOSVersion', 'ReleaseDate') },
    @{ Label = 'CPU';       Class = 'Win32_Processor';      Fields = @('Name', 'NumberOfCores', 'NumberOfLogicalProcessors') }
)
foreach ($query in $identityQueries) {
    try {
        $instance = @(Get-CimInstance -ClassName $query.Class -ErrorAction Stop)[0]
        $pairs = @()
        foreach ($field in $query.Fields) {
            $pairs += ('{0}={1}' -f $field, $instance.$field)
        }
        Write-Recon ('{0,-10} {1}' -f $query.Label, ($pairs -join '  '))
    }
    catch {
        Write-Recon ('{0,-10} FAILED: {1}' -f $query.Label, (Get-ReconErrorText $_.Exception.Message))
    }
}
Write-Recon ''
Write-Recon 'The Product value on the BaseBoard line is the board id the app matches on.'
Write-Recon 'The reference machine is 3376. Yours should read 3111.'
Write-Recon ''

# --- [1] Which Lenovo classes exist -----------------------------------------
Write-Recon '### [1] Lenovo classes present in root\wmi'
$lenovoClasses = @()
try {
    $lenovoClasses = @(Get-CimClass -Namespace 'root\wmi' -ClassName 'Lenovo*' -ErrorAction Stop)
}
catch {
    Write-Recon ('wildcard class search failed: {0}' -f (Get-ReconErrorText $_.Exception.Message))
}

# The wildcard search is the only call in this script that has never run on a
# real machine, and losing it would lose the answer to "does this board have
# the fan-mode interface at all". Fall back to asking for each known class by
# name, which uses a plainer code path.
if ($lenovoClasses.Count -eq 0) {
    Write-Recon 'wildcard search returned nothing; asking for known class names one at a time'
    $knownClassNames = @(
        'LENOVO_GAMEZONE_DATA', 'LENOVO_FAN_METHOD', 'LENOVO_OTHER_METHOD',
        'LENOVO_GAMEZONE_CPU_METHOD', 'Lenovo_BiosSetting', 'Lenovo_BiosElements',
        'Lenovo_DT_GetCPUFan', 'Lenovo_DT_GetSYSFan', 'Lenovo_DT_GetPWRFan',
        'Lenovo_DT_GetCPUTemp'
    )
    $found = @()
    foreach ($knownName in $knownClassNames) {
        try {
            $found += @(Get-CimClass -Namespace 'root\wmi' -ClassName $knownName -ErrorAction Stop)
        }
        catch {
            Write-Recon ('{0,-32} absent' -f $knownName)
        }
    }
    $lenovoClasses = @($found)
}

try {
    if ($lenovoClasses.Count -eq 0) {
        Write-Recon 'NONE. This machine exposes no Lenovo WMI classes at all.'
    }
    foreach ($class in $lenovoClasses) {
        $methodNames = @($class.CimClassMethods | ForEach-Object { $_.Name })
        if ($methodNames.Count -eq 0) {
            Write-Recon ('{0}' -f $class.CimClassName)
        }
        else {
            Write-Recon ('{0}  methods: {1}' -f $class.CimClassName, ($methodNames -join ', '))
        }
    }
}
catch {
    Write-Recon ("FAILED to enumerate root\wmi classes: {0}" -f (Get-ReconErrorText $_.Exception.Message))
}
Write-Recon ''
Write-Recon 'Look for LENOVO_GAMEZONE_DATA above. The app needs it for fan modes.'
Write-Recon 'If it is missing, FanModes.Get and FanModes.Set cannot work on this machine.'
Write-Recon ''

# --- [2] Call every safe read method ----------------------------------------
Write-Recon '### [2] Read-only method results'
foreach ($class in $lenovoClasses) {
    $className = $class.CimClassName

    # Lenovo_BiosSetting has one instance per setting - hundreds of them. It is
    # dumped properly in section [4]; calling methods per instance here would
    # add nothing and flood the report.
    if ($className -eq 'Lenovo_BiosSetting') { continue }

    $safeMethods = @($class.CimClassMethods |
        Where-Object { (Test-ReconSafeMethod $_.Name) -and (@($_.Parameters | Where-Object { $_.Qualifiers.Name -contains 'In' }).Count -eq 0) } |
        ForEach-Object { $_.Name })

    if ($safeMethods.Count -eq 0) { continue }

    Write-Recon ''
    Write-Recon ("--- {0}" -f $className)

    $instance = $null
    try {
        $instances = @(Get-CimInstance -Namespace 'root\wmi' -ClassName $className -ErrorAction Stop)
        Write-Recon ('instances: {0}' -f $instances.Count)
        if ($instances.Count -gt 0) { $instance = $instances[0] }
    }
    catch {
        Write-Recon ('no instances: {0}' -f (Get-ReconErrorText $_.Exception.Message))
    }
    if ($null -eq $instance) { continue }

    foreach ($methodName in $safeMethods) {
        try {
            $result = Invoke-CimMethod -InputObject $instance -MethodName $methodName -ErrorAction Stop
            Write-Recon ('{0,-32} -> OK   {1}' -f $methodName, (Format-CimResult $result))
        }
        catch {
            Write-Recon ('{0,-32} -> FAIL {1}' -f $methodName, (Get-ReconErrorText $_.Exception.Message))
        }
    }
}
Write-Recon ''

# --- [3] The indexed getters ------------------------------------------------
# These take one id argument, so section [2] skips them. The reference machine
# returned 0 for every fan and 65535 for every sensor, because its ACPI layer
# is stubbed. Real numbers here would mean your machine is in better shape.
Write-Recon '### [3] Indexed read methods (fan id / sensor id)'
$indexedMethods = @(
    @{ Class = 'LENOVO_GAMEZONE_DATA'; Method = 'GetFanSpeed';           Parameter = 'FanID';    Ids = 0..3 },
    @{ Class = 'LENOVO_GAMEZONE_DATA'; Method = 'GetSensorTemperature'; Parameter = 'SensorID'; Ids = 0..7 }
)
$reportedMissing = @{}
foreach ($probe in $indexedMethods) {
    $instance = $null
    try {
        $instance = @(Get-CimInstance -Namespace 'root\wmi' -ClassName $probe.Class -ErrorAction Stop)[0]
    }
    catch {
        # Several probes share a class. Say it is missing once, not per method.
        if (-not $reportedMissing.ContainsKey($probe.Class)) {
            Write-Recon ('{0}: not present on this machine' -f $probe.Class)
            $reportedMissing[$probe.Class] = $true
        }
        continue
    }
    if (-not (Test-ReconSafeMethod $probe.Method)) { continue }

    foreach ($id in $probe.Ids) {
        try {
            $arguments = @{ $probe.Parameter = [uint32]$id }
            $result = Invoke-CimMethod -InputObject $instance -MethodName $probe.Method -Arguments $arguments -ErrorAction Stop
            Write-Recon ('{0}({1}){2} -> OK   {3}' -f $probe.Method, $id, '', (Format-CimResult $result))
        }
        catch {
            Write-Recon ('{0}({1}) -> FAIL {2}' -f $probe.Method, $id, (Get-ReconErrorText $_.Exception.Message))
        }
    }
}
Write-Recon ''

# --- [4] Every BIOS setting -------------------------------------------------
# This is the most valuable section for an older machine. It names every
# setting the BIOS exposes, so you can find this board's cooling setting
# instead of guessing that it matches the reference board's.
Write-Recon '### [4] Lenovo_BiosSetting - every setting on this machine'
$biosSettings = @()
try {
    $biosSettings = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'Lenovo_BiosSetting' -ErrorAction Stop)
    Write-Recon ('{0} setting(s) reported' -f $biosSettings.Count)
    Write-Recon ''
    foreach ($setting in $biosSettings) {
        if ([string]::IsNullOrWhiteSpace([string]$setting.CurrentSetting)) { continue }
        Write-Recon ([string]$setting.CurrentSetting)
    }
}
catch {
    Write-Recon ('FAILED: {0}' -f (Get-ReconErrorText $_.Exception.Message))
    Write-Recon 'This machine may not support the Lenovo BIOS WMI interface at all.'
}
Write-Recon ''

# --- [5] The cooling-related ones, pulled out -------------------------------
Write-Recon '### [5] Settings that look fan or cooling related'
$coolingPattern = '(?i)(fan|cool|thermal|temp|acoustic|quiet|performance|smart|speed|noise)'
$coolingHits = @($biosSettings | Where-Object { [string]$_.CurrentSetting -match $coolingPattern })
if ($coolingHits.Count -eq 0) {
    Write-Recon 'None matched. Read section [4] yourself - the name may not use any of the usual words.'
}
else {
    foreach ($hit in $coolingHits) {
        Write-Recon ([string]$hit.CurrentSetting)
    }
}
Write-Recon ''
Write-Recon 'The app writes a setting named IntelligentCoolingPerformanceMode.'
Write-Recon 'If that exact name is absent above, the Full Speed feature needs a different'
Write-Recon 'setting name on this board, or it does not exist here.'
Write-Recon ''

# --- [6] ACPI fan devices ----------------------------------------------------
# PNP0C0B is the ACPI fan device. Windows enumerated five of them on the
# reference M70t, but they all routed through its stubbed embedded controller
# and reported nothing. If this board enumerates them AND something can read a
# real RPM, the ACPI fan objects are worth investigating: _FST reports fan
# status including the tachometer, and _FIF says whether the firmware accepts
# fine-grain 0-100% levels.
Write-Recon '### [6] ACPI fan devices (PNP0C0B)'
try {
    $fanDevices = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
        Where-Object { [string]$_.PNPDeviceID -like '*PNP0C0B*' })
    if ($fanDevices.Count -eq 0) {
        Write-Recon 'None enumerated. This board exposes no ACPI fan devices to Windows.'
    }
    else {
        Write-Recon ('{0} ACPI fan device(s):' -f $fanDevices.Count)
        foreach ($fanDevice in $fanDevices) {
            Write-Recon ('  {0}  status={1}  id={2}' -f $fanDevice.Name, $fanDevice.Status, $fanDevice.PNPDeviceID)
        }
    }
}
catch {
    Write-Recon ('FAILED: {0}' -f (Get-ReconErrorText $_.Exception.Message))
}
Write-Recon ''

# --- [7] Write classes: presence only ---------------------------------------
Write-Recon '### [7] Write interfaces (checked for presence, never called)'
foreach ($className in @('Lenovo_SetBiosSetting', 'Lenovo_SaveBiosSettings', 'Lenovo_BiosPasswordSettings')) {
    $present = $false
    try {
        $found = @(Get-CimClass -Namespace 'root\wmi' -ClassName $className -ErrorAction Stop)
        $present = ($found.Count -gt 0)
    }
    catch {
        $present = $false
    }
    Write-Recon ('{0,-32} present={1}' -f $className, $present)
}
Write-Recon ''
Write-Recon 'This script never invokes any of the above. It only reports whether they exist.'

$outPath = Join-Path $OutDir 'wmi-probe.txt'
Save-Recon -Path $outPath
Write-Host ''
Write-Host "report written to $outPath"
