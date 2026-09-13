# Tests for the pure helpers in Recon.Common.ps1.
#
# These run anywhere PowerShell runs, including Linux and a cloud container -
# that is the point of keeping the helpers free of Windows APIs. They prove the
# parsing and formatting logic, NOT that the recon scripts talk to real
# hardware correctly. Only a run on the target machine proves that.
#
#   pwsh -NoProfile -File ./Test-ReconCommon.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Recon.Common.ps1')

$script:Passed = 0
$script:Failed = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Because)
    if ($Expected -eq $Actual) {
        $script:Passed++
        Write-Host ("  pass: {0}" -f $Because)
    }
    else {
        $script:Failed++
        Write-Host ("  FAIL: {0}`n        expected [{1}] got [{2}]" -f $Because, $Expected, $Actual)
    }
}

# Builds a synthetic but structurally valid ACPI table header.
function New-FakeAcpiTable {
    param(
        [string]$Signature = 'DSDT',
        [string]$OemId = 'LENOVO',
        [string]$OemTableId = 'TC-M5O__',
        [int]$TotalLength = 64
    )
    $data = New-Object byte[] $TotalLength
    [System.Text.Encoding]::ASCII.GetBytes($Signature).CopyTo($data, 0)
    [BitConverter]::GetBytes([uint32]$TotalLength).CopyTo($data, 4)
    $data[8] = 2
    [System.Text.Encoding]::ASCII.GetBytes($OemId.PadRight(6)).CopyTo($data, 10)
    [System.Text.Encoding]::ASCII.GetBytes($OemTableId.PadRight(8)).CopyTo($data, 16)
    [BitConverter]::GetBytes([uint32]0x13d0).CopyTo($data, 24)
    return $data
}

Write-Host "`nConvertTo-ReconSafeName"
Assert-Equal 'DSDT_LENOVO_TC-M5O__' (ConvertTo-ReconSafeName 'DSDT\LENOVO\TC-M5O__') 'backslashes become underscores'
Assert-Equal 'TC-M5O__' (ConvertTo-ReconSafeName 'TC-M5O  ') 'trailing spaces become underscores'
Assert-Equal '' (ConvertTo-ReconSafeName '') 'empty string survives'
Assert-Equal 'a.b-c_1' (ConvertTo-ReconSafeName 'a.b-c_1') 'dot, dash and digit are kept'

Write-Host "`nGet-AcpiTableHeader - valid tables"
$table = New-FakeAcpiTable
$header = Get-AcpiTableHeader -Data $table
Assert-Equal 'DSDT' $header.Signature 'signature decoded'
Assert-Equal 'LENOVO' $header.OemId 'OEM ID decoded and trimmed'
Assert-Equal 'TC-M5O__' $header.OemTableId 'OEM table ID decoded'
Assert-Equal 64 $header.DeclaredLength 'declared length decoded'
Assert-Equal $true $header.LengthMatches 'declared length matches actual'
Assert-Equal 5072 $header.OemRevision 'OEM revision decoded (0x13d0)'

Write-Host "`nGet-AcpiTableHeader - rejects non-tables"
Assert-Equal $null (Get-AcpiTableHeader -Data (New-Object byte[] 8)) 'too short to hold a header'
Assert-Equal $null (Get-AcpiTableHeader -Data (New-Object byte[] 0)) 'empty array'
$binaryJunk = New-Object byte[] 64
$binaryJunk[0] = 0x00; $binaryJunk[1] = 0xFF; $binaryJunk[2] = 0x01; $binaryJunk[3] = 0x80
Assert-Equal $null (Get-AcpiTableHeader -Data $binaryJunk) 'unprintable signature rejected'

Write-Host "`nGet-AcpiTableHeader - flags a truncated table instead of hiding it"
$truncated = New-FakeAcpiTable -TotalLength 64
[BitConverter]::GetBytes([uint32]4096).CopyTo($truncated, 4)
$truncatedHeader = Get-AcpiTableHeader -Data $truncated
Assert-Equal $false $truncatedHeader.LengthMatches 'length mismatch reported, not swallowed'

Write-Host "`nTest-ReconSafeMethod - allows real Lenovo read methods"
foreach ($name in @('GetSmartFanMode', 'GetSupportThermalMode', 'IsSupportSmartFan',
                    'GetFanSpeed', 'GetSensorTemperature', 'GetFanZoneSupportList',
                    'IsSupportFullSpeedMode', 'GetCustomModeAbility')) {
    Assert-Equal $true (Test-ReconSafeMethod $name) "allows $name"
}

Write-Host "`nTest-ReconSafeMethod - refuses anything that could change the machine"
foreach ($name in @('SetSmartFanMode', 'SetBiosSetting', 'SaveBiosSettings', 'SetFanZoneData',
                    'SetBiosPassword', 'GetBiosPassword', 'IsKeyPresent', 'GetCertificateInfo',
                    'SecureWipe', 'FlashBios', 'UpdateFirmware', '')) {
    Assert-Equal $false (Test-ReconSafeMethod $name) "refuses $name"
}

Write-Host "`nFormat-EcHexDump"
$ecBytes = New-Object int[] 256
for ($i = 0; $i -lt 256; $i++) { $ecBytes[$i] = $i }
$dump = @(Format-EcHexDump -Bytes $ecBytes)
Assert-Equal 17 $dump.Count '1 header row plus 16 data rows'
Assert-Equal $true ($dump[1] -like '00:*00 01 02 03 04 05 06 07  08 09*') 'first row lays out 0x00..0x0F with the mid gap'
Assert-Equal $true ($dump[16] -like 'F0:*F0 F1*') 'last row starts at 0xF0'

$withTimeout = New-Object int[] 256
$withTimeout[0] = -1
Assert-Equal $true (@(Format-EcHexDump -Bytes $withTimeout)[1] -like '00:   -- 00*') 'a timed-out offset prints as -- not 00'

# An empty dump is nonsense input, so the parameter binder should refuse it
# rather than quietly return a header with nothing under it.
$emptyRefused = $false
try { Format-EcHexDump -Bytes (New-Object int[] 0) | Out-Null }
catch { $emptyRefused = $true }
Assert-Equal $true $emptyRefused 'an empty byte array is refused, not formatted'

Write-Host "`nGet-EcVerdict"
$live = New-Object int[] 256
for ($i = 0; $i -lt 256; $i++) { $live[$i] = ($i * 7) % 251 }
Assert-Equal 'REAL EC' (Get-EcVerdict -Bytes $live).Verdict 'varied data reads as a real EC'

$allZero = New-Object int[] 256
Assert-Equal 'STUBBED OR EMPTY' (Get-EcVerdict -Bytes $allZero).Verdict 'all zeroes reads as stubbed'

$allFf = New-Object int[] 256
for ($i = 0; $i -lt 256; $i++) { $allFf[$i] = 255 }
Assert-Equal 'STUBBED OR EMPTY' (Get-EcVerdict -Bytes $allFf).Verdict 'all 0xFF reads as stubbed'

$allDead = New-Object int[] 256
for ($i = 0; $i -lt 256; $i++) { $allDead[$i] = -1 }
$deadVerdict = Get-EcVerdict -Bytes $allDead
Assert-Equal 'NO RESPONSE' $deadVerdict.Verdict 'all timeouts reads as no response'
Assert-Equal 256 $deadVerdict.BytesTimedOut 'timeout count reported'

$halfDead = New-Object int[] 256
for ($i = 0; $i -lt 256; $i++) { if ($i -lt 200) { $halfDead[$i] = -1 } else { $halfDead[$i] = $i } }
Assert-Equal 'MOSTLY TIMEOUTS' (Get-EcVerdict -Bytes $halfDead).Verdict 'mostly timeouts is called out separately'

Write-Host "`nGet-EcWordCandidates"
$tach = New-Object int[] 256
# 0x00:0x01 = 0x03A9 = 937 rpm big-endian, the reference board's real idle tach.
$tach[0] = 0x03; $tach[1] = 0xA9
$candidates = @(Get-EcWordCandidates -Bytes $tach)
$hit = @($candidates | Where-Object { $_.Offset -eq 0 -and $_.Order -eq 'big-endian' })
Assert-Equal 1 $hit.Count 'finds the 0x00 big-endian word'
Assert-Equal 937 $hit[0].Value 'decodes it as 937 rpm'

$noneInRange = New-Object int[] 256
Assert-Equal 0 (@(Get-EcWordCandidates -Bytes $noneInRange)).Count 'all-zero dump yields no candidates'

$withTimeouts = New-Object int[] 256
$withTimeouts[0] = -1; $withTimeouts[1] = 0xA9
Assert-Equal 0 (@(Get-EcWordCandidates -Bytes $withTimeouts | Where-Object { $_.Offset -eq 0 })).Count 'a timed-out byte never forms a candidate word'

Write-Host "`nGet-ReconErrorText"
Assert-Equal 'one two three' (Get-ReconErrorText "one`ntwo`r`nthree") 'newlines collapse to single spaces'
Assert-Equal 'a b' (Get-ReconErrorText "  a    b  ") 'runs of whitespace collapse and ends are trimmed'
Assert-Equal '' (Get-ReconErrorText '') 'empty message survives'
Assert-Equal 20 (Get-ReconErrorText ('x' * 500) -MaxLength 20).Length 'long message is capped to MaxLength'
Assert-Equal $true ((Get-ReconErrorText ('x' * 500) -MaxLength 20) -like '*...') 'a capped message is marked with an ellipsis'

Write-Host "`nGet-ReconStamp"
Assert-Equal $true ((Get-ReconStamp) -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$') 'carries an explicit UTC offset'

Write-Host ("`n{0} passed, {1} failed`n" -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0
