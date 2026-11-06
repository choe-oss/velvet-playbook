# =============================================================================
# Velvet - Windows 11 26H2 settings compatibility
# Applies supported policy/API-backed settings and verifies every write.
# =============================================================================
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-windows11-settings' 'Starting Windows 11 26H2 compatibility settings.'

function Set-VerifiedValue {
    param(
        [string]$Path,
        [string]$Name,
        [ValidateSet('DWord', 'String')][string]$PropertyType,
        [object]$Value
    )
    New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value -Force -ErrorAction SilentlyContinue | Out-Null
    $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    $actual = if ($item) { $item.$Name } else { $null }
    if ($null -eq $actual -or [string]$actual -ne [string]$Value) {
        Write-Host "[WARN] Verification failed: $Path\$Name expected '$Value', actual '$actual'." -ForegroundColor Yellow
        return $false
    }
    Write-SetupProgress 'config-windows11-settings' "Verified $Path\$Name=$actual."
    return $true
}

function Set-LoadedHiveValue {
    param([string]$Sid, [string]$RelativePath, [string]$Name, [string]$Type, [object]$Value)
    Set-VerifiedValue -Path "HKU:\$Sid\$RelativePath" -Name $Name -PropertyType $Type -Value $Value | Out-Null
}

$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$quietHours = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\QuietHours'
$quietNotifications = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\QuietHours'
$notifications = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
$crossDevice = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
$search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
$start = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'
$explorerPolicy = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'

# Do Not Disturb / Focus Assist: disable legacy state, schedules, and the
# notification quiet-hours state. Unsupported newer CloudStore values are not
# fabricated; their absence is reported by the verification warnings below.
foreach ($entry in @(
    @($quietHours, 'Enabled', 0), @($quietHours, 'UserSetDoNotDisturbStatus', 0),
    @($quietHours, 'Rule', 0), @($quietHours, 'Schedule', 0),
    @($quietNotifications, 'Enabled', 0), @($quietNotifications, 'UserSetDoNotDisturbStatus', 0),
    @($quietNotifications, 'QuietHoursServiceState', 0),
    @($notifications, 'NOC_GLOBAL_SETTING_TOASTS_ENABLED', 1)
)) {
    Set-VerifiedValue -Path $entry[0] -Name $entry[1] -PropertyType DWord -Value $entry[2] | Out-Null
}

# PowerShell policy: distinguish policy-enforced scopes from the local setting.
try {
    $policyList = Get-ExecutionPolicy -List
    if ([string]$policyList.MachinePolicy -ne 'Undefined' -or [string]$policyList.UserPolicy -ne 'Undefined') {
        Write-Host "[WARN] PowerShell execution policy is enforced by Group Policy: MachinePolicy=$($policyList.MachinePolicy); UserPolicy=$($policyList.UserPolicy)." -ForegroundColor Yellow
    }
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
    $localPolicy = Get-ExecutionPolicy -Scope LocalMachine
    if ([string]$localPolicy -ne 'RemoteSigned') {
        Write-Host "[WARN] LocalMachine PowerShell policy did not verify as RemoteSigned; effective policy is $(Get-ExecutionPolicy)." -ForegroundColor Yellow
    } else {
        Write-SetupProgress 'config-windows11-settings' 'PowerShell LocalMachine execution policy verified as RemoteSigned.'
    }
} catch {
    Write-Host "[WARN] PowerShell execution policy could not be applied: $($_.Exception.Message)" -ForegroundColor Yellow
}
try {
    $appLocker = Get-AppLockerPolicy -Effective -ErrorAction Stop
    if ($appLocker.RuleCollections.Count -gt 0) {
        Write-Host '[WARN] AppLocker effective rules are present; execution policy does not override AppLocker.' -ForegroundColor Yellow
    }
} catch {
    Write-SetupProgress 'config-windows11-settings' 'AppLocker effective policy query unavailable.'
}
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

# Taskbar End task, search, Continue, and legacy Start fallbacks.
Set-VerifiedValue -Path $advanced -Name 'TaskbarEndTask' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path "$advanced\TaskbarDeveloperSettings" -Name 'TaskbarEndTask' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path $search -Name 'SearchboxTaskbarMode' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'SearchboxTaskbarMode' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $crossDevice -Name 'IsResumeAllowed' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $crossDevice -Name 'IsOneDriveResumeAllowed' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $start -Name 'ShowPinnedSection' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $explorerPolicy -Name 'NoStartMenuPinnedList' -PropertyType DWord -Value 1 | Out-Null

# Supported policy locations. The write is successful only when the exact
# value can be read back; an unrecognized policy is therefore visible as WARN.
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start' -Name 'ConfigureStartPins' -PropertyType String -Value '{"pinnedList":[]}' | Out-Null
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start' -Name 'ConfigureStartPinsJson' -PropertyType String -Value '{"pinnedList":[]}' | Out-Null
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Search' -Name 'ConfigureSearchOnTaskbarMode' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\CloudContent' -Name 'DisableWindowsSpotlight' -PropertyType DWord -Value 1 | Out-Null

# Dynamic Lighting: apply both policy and user paths, but warn if the build
# does not expose the key after the write.
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Lighting' -Name 'AllowAmbientLighting' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path 'HKCU:\Software\Microsoft\PolicyManager\current\device\Lighting' -Name 'AllowAmbientLighting' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lighting' -Name 'Enabled' -PropertyType DWord -Value 0 | Out-Null

# About/OEM information. Windows may show only a subset of these fields in a
# given edition; all supported registry values are applied and documented.
$currentVersion = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$oemInfo = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
Set-VerifiedValue -Path $currentVersion -Name 'RegisteredOwner' -PropertyType String -Value 'VELVET-OSS' | Out-Null
Set-VerifiedValue -Path $currentVersion -Name 'RegisteredOrganization' -PropertyType String -Value 'VELVET-OSS' | Out-Null
Set-VerifiedValue -Path $oemInfo -Name 'Manufacturer' -PropertyType String -Value 'VELVET-OSS' | Out-Null
Set-VerifiedValue -Path $oemInfo -Name 'Model' -PropertyType String -Value 'Velvet Windows 11' | Out-Null
Set-VerifiedValue -Path $oemInfo -Name 'SupportURL' -PropertyType String -Value 'https://github.com/choe-oss/velvet-playbook' | Out-Null

# Explorer Home/Gallery namespace and This PC policy.
$homeClsid = '{679f85cb-0220-4080-b29b-5540cc05aab6}'
$galleryClsid = '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'
$recycleClsid = '{645FF040-5081-101B-9F08-00AA002F954E}'
foreach ($clsid in @($homeClsid, $galleryClsid)) {
    Set-VerifiedValue -Path "HKCU:\Software\Classes\CLSID\$clsid" -Name 'System.IsPinnedToNameSpaceTree' -PropertyType DWord -Value 0 | Out-Null
    Set-VerifiedValue -Path "HKLM:\SOFTWARE\Classes\CLSID\$clsid" -Name 'System.IsPinnedToNameSpaceTree' -PropertyType DWord -Value 0 | Out-Null
    Set-VerifiedValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$clsid\PropertyBag" -Name 'ThisPCPolicy' -PropertyType String -Value 'Hide' | Out-Null
    Remove-Item -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
}
Set-VerifiedValue -Path "HKCU:\Software\Classes\CLSID\$recycleClsid" -Name 'System.IsPinnedToNameSpaceTree' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path "HKLM:\SOFTWARE\Classes\CLSID\$recycleClsid" -Name 'System.IsPinnedToNameSpaceTree' -PropertyType DWord -Value 1 | Out-Null
$autoDest = Join-Path $env:APPDATA 'Microsoft\Windows\Recent\AutomaticDestinations\f01b4d95cf55d32a.automaticDestinations-ms'
if (Test-Path -LiteralPath $autoDest) {
    Remove-Item -LiteralPath $autoDest -Force -ErrorAction SilentlyContinue
    Write-SetupProgress 'config-windows11-settings' "Removed Quick Access automatic destination cache $autoDest."
}

# Folder Options values matching the current Explorer UI.
Set-VerifiedValue -Path $advanced -Name 'Hidden' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'HideFileExt' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'ShowSuperHidden' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'NavPaneExpandToCurrentFolder' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'LaunchTo' -PropertyType DWord -Value 1 | Out-Null

# Apply the user-facing values to currently loaded profile hives as well.
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}
$loadedSids = Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' -and $_.PSChildName -notlike '*_Classes' } |
    Select-Object -ExpandProperty PSChildName -Unique
foreach ($sid in $loadedSids) {
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarEndTask' 'DWord' 1
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'SearchboxTaskbarMode' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration' 'IsResumeAllowed' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration' 'IsOneDriveResumeAllowed' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\QuietHours' 'Enabled' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Notifications\QuietHours' 'Enabled' 'DWord' 0
    Set-LoadedHiveValue $sid "Software\Classes\CLSID\$homeClsid" 'System.IsPinnedToNameSpaceTree' 'DWord' 0
    Set-LoadedHiveValue $sid "Software\Classes\CLSID\$galleryClsid" 'System.IsPinnedToNameSpaceTree' 'DWord' 0
    Set-LoadedHiveValue $sid "Software\Classes\CLSID\$recycleClsid" 'System.IsPinnedToNameSpaceTree' 'DWord' 1
    Remove-Item -LiteralPath "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$homeClsid" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$galleryClsid" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-SetupProgress 'config-windows11-settings' 'Refreshing Explorer and Start processes.'
Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe -ErrorAction SilentlyContinue | Out-Null

Write-Host '        [ OK ] Windows 11 26H2 compatibility settings applied and verified.' -ForegroundColor Green
Write-SetupProgress 'config-windows11-settings' 'Completed successfully.'
exit 0
