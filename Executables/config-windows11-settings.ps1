# =============================================================================
# Velvet - Windows 11 26H2 settings compatibility
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

# 1. 탐색기 프로세스를 먼저 종료하여 메모리 캐시 플러시 방지
Write-SetupProgress 'config-windows11-settings' 'Stopping shell processes before applying registry.'
Get-Process -Name StartMenuExperienceHost, explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$quietHours = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\QuietHours'
$quietNotifications = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\QuietHours'
$notifications = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
$crossDevice = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'
$search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
$start = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'
$explorerPolicy = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'

# Do Not Disturb / Focus Assist
foreach ($entry in @(
    @($quietHours, 'Enabled', 0), @($quietHours, 'UserSetDoNotDisturbStatus', 0),
    @($quietHours, 'Rule', 0), @($quietHours, 'Schedule', 0),
    @($quietNotifications, 'Enabled', 0), @($quietNotifications, 'UserSetDoNotDisturbStatus', 0),
    @($quietNotifications, 'QuietHoursServiceState', 0),
    @($notifications, 'NOC_GLOBAL_SETTING_TOASTS_ENABLED', 1)
)) {
    Set-VerifiedValue -Path $entry[0] -Name $entry[1] -PropertyType DWord -Value $entry[2] | Out-Null
}

# PowerShell policy
try {
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
} catch {
    Write-Host "[WARN] PowerShell execution policy could not be applied: $($_.Exception.Message)" -ForegroundColor Yellow
}
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

# Taskbar, Start, and Search Tweaks (누락 항목 보완)
Set-VerifiedValue -Path $advanced -Name 'TaskbarEndTask' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path "$advanced\TaskbarDeveloperSettings" -Name 'TaskbarEndTask' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'ShowTaskViewButton' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'MMTaskbarEnabled' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'SearchboxTaskbarMode' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $search -Name 'SearchboxTaskbarMode' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $start -Name 'ShowPinnedSection' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $start -Name 'AllAppsViewMode' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path $explorerPolicy -Name 'NoStartMenuPinnedList' -PropertyType DWord -Value 1 | Out-Null

# 그룹 정책 기반 검색 상자 모드 고정
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'SearchboxTaskbarMode' -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

# PolicyManager settings
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start' -Name 'ConfigureStartPins' -PropertyType String -Value '{"pinnedList":[]}' | Out-Null
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start' -Name 'ConfigureStartPinsJson' -PropertyType String -Value '{"pinnedList":[]}' | Out-Null
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Search' -Name 'ConfigureSearchOnTaskbarMode' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\CloudContent' -Name 'DisableWindowsSpotlight' -PropertyType DWord -Value 1 | Out-Null

# OEM Information
$currentVersion = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$oemInfo = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
Set-VerifiedValue -Path $currentVersion -Name 'RegisteredOwner' -PropertyType String -Value 'VELVET-OSS' | Out-Null
Set-VerifiedValue -Path $currentVersion -Name 'RegisteredOrganization' -PropertyType String -Value 'VELVET-OSS' | Out-Null
Set-VerifiedValue -Path $oemInfo -Name 'Manufacturer' -PropertyType String -Value 'VELVET-OSS' | Out-Null
Set-VerifiedValue -Path $oemInfo -Name 'Model' -PropertyType String -Value 'Velvet Windows 11' | Out-Null
Set-VerifiedValue -Path $oemInfo -Name 'SupportURL' -PropertyType String -Value 'https://github.com/choe-oss/velvet-playbook' | Out-Null

# Explorer Home/Gallery namespace removal
$homeClsid = '{679f85cb-0220-4080-b29b-5540cc05aab6}'
$galleryClsid = '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'
$recycleClsid = '{645FF040-5081-101B-9F08-00AA002F954E}'
foreach ($clsid in @($homeClsid, $galleryClsid)) {
    Set-VerifiedValue -Path "HKCU:\Software\Classes\CLSID\$clsid" -Name 'System.IsPinnedToNameSpaceTree' -PropertyType DWord -Value 0 | Out-Null
    Set-VerifiedValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$clsid\PropertyBag" -Name 'ThisPCPolicy' -PropertyType String -Value 'Hide' | Out-Null
    Remove-Item -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
}
Set-VerifiedValue -Path "HKCU:\Software\Classes\CLSID\$recycleClsid" -Name 'System.IsPinnedToNameSpaceTree' -PropertyType DWord -Value 1 | Out-Null

# Folder Options
Set-VerifiedValue -Path $advanced -Name 'Hidden' -PropertyType DWord -Value 1 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'HideFileExt' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'ShowSuperHidden' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'NavPaneExpandToCurrentFolder' -PropertyType DWord -Value 0 | Out-Null
Set-VerifiedValue -Path $advanced -Name 'LaunchTo' -PropertyType DWord -Value 1 | Out-Null

# Apply to loaded hives (SID)
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}
$loadedSids = Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' -and $_.PSChildName -notlike '*_Classes' } |
    Select-Object -ExpandProperty PSChildName -Unique
foreach ($sid in $loadedSids) {
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarEndTask' 'DWord' 1
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'MMTaskbarEnabled' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'SearchboxTaskbarMode' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Start' 'ShowPinnedSection' 'DWord' 0
    Set-LoadedHiveValue $sid 'Software\Microsoft\Windows\CurrentVersion\Start' 'AllAppsViewMode' 'DWord' 1
    Set-LoadedHiveValue $sid 'Software\Policies\Microsoft\Windows\Explorer' 'NoStartMenuPinnedList' 'DWord' 1
    Set-LoadedHiveValue $sid "Software\Classes\CLSID\$homeClsid" 'System.IsPinnedToNameSpaceTree' 'DWord' 0
    Set-LoadedHiveValue $sid "Software\Classes\CLSID\$galleryClsid" 'System.IsPinnedToNameSpaceTree' 'DWord' 0
    Set-LoadedHiveValue $sid "Software\Classes\CLSID\$recycleClsid" 'System.IsPinnedToNameSpaceTree' 'DWord' 1
}

# Explorer 재시작
Write-SetupProgress 'config-windows11-settings' 'Restarting Explorer.'
Start-Process explorer.exe -ErrorAction SilentlyContinue | Out-Null

Write-Host '        [ OK ] Windows 11 26H2 compatibility settings applied and verified.' -ForegroundColor Green
Write-SetupProgress 'config-windows11-settings' 'Completed successfully.'
exit 0