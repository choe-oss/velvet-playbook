# =============================================================================
# Velvet - Windows 11 26H2 settings compatibility
# Applies supported policy/API-backed settings and verifies legacy fallbacks.
# =============================================================================
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-windows11-settings' 'Starting Windows 11 26H2 compatibility settings.'

function Set-DwordValue {
    param([string]$Path, [string]$Name, [int]$Value)
    New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force -ErrorAction SilentlyContinue | Out-Null
}

function Set-StringValue {
    param([string]$Path, [string]$Name, [string]$Value)
    New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force -ErrorAction SilentlyContinue | Out-Null
}

function Verify-Value {
    param([string]$Path, [string]$Name, [object]$Expected)
    $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    $actual = if ($item) { $item.$Name } else { $null }
    if ($null -eq $actual -or [string]$actual -ne [string]$Expected) {
        Write-Host "[WARN] $Path\$Name expected '$Expected', actual '$actual'." -ForegroundColor Yellow
    } else {
        Write-SetupProgress 'config-windows11-settings' "Verified $Name=$actual."
    }
}

# Focus Assist / Do Not Disturb: clear legacy quiet-hours profiles and schedules.
$quietHours = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\QuietHours'
Set-DwordValue $quietHours 'Profile' 0
Set-DwordValue $quietHours 'Rule' 0
Set-DwordValue $quietHours 'Schedule' 0
Set-DwordValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' 1

# PowerShell scripts: use an explicit local-machine policy and remove Mark-of-the-Web
# from staged local scripts rather than weakening execution for downloaded content.
try {
    Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
    Write-SetupProgress 'config-windows11-settings' 'PowerShell LocalMachine execution policy set to RemoteSigned.'
} catch {
    Write-Host "[WARN] Could not set LocalMachine PowerShell policy: $($_.Exception.Message)" -ForegroundColor Yellow
}
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

# Windows 11 taskbar End task toggle.
$advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-DwordValue $advanced 'TaskbarEndTask' 1
Verify-Value $advanced 'TaskbarEndTask' 1

# Registered owner/support information shown by Windows About pages.
$currentVersion = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Set-StringValue $currentVersion 'RegisteredOwner' 'VELVET-OSS'
Set-StringValue $currentVersion 'RegisteredOrganization' 'VELVET-OSS'
Set-StringValue $currentVersion 'OEMInformation' ''
$oemInfo = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
Set-StringValue $oemInfo 'Manufacturer' 'VELVET-OSS'
Set-StringValue $oemInfo 'Model' 'Velvet Windows 11'
Set-StringValue $oemInfo 'SupportURL' 'https://github.com/choe-oss/velvet-playbook'
Set-StringValue $oemInfo 'SupportPhone' ''

# Dynamic Lighting: disable policy and per-user preference where the 26H2 keys exist.
Set-DwordValue 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Lighting' 'AllowAmbientLighting' 0
Set-DwordValue 'HKCU:\Software\Microsoft\PolicyManager\current\device\Lighting' 'AllowAmbientLighting' 0
Set-DwordValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lighting' 'Enabled' 0
Verify-Value 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Lighting' 'AllowAmbientLighting' 0

# Start pinned section and taskbar/search policies. These are the supported policy
# locations; legacy Start values are retained only as compatibility fallbacks.
$startPolicy = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start'
Set-StringValue $startPolicy 'ConfigureStartPins' '{"pinnedList":[]}'
Set-StringValue $startPolicy 'ConfigureStartPinsJson' '{"pinnedList":[]}'
Set-StringValue $startPolicy 'ConfigureTaskbarLayout' '{"taskbarLayout":[]}'
Set-DwordValue 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Search' 'ConfigureSearchOnTaskbarMode' 0
Set-DwordValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0
Set-DwordValue $advanced 'SearchboxTaskbarMode' 0
Set-DwordValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration' 'IsResumeAllowed' 0
Set-DwordValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration' 'IsOneDriveResumeAllowed' 0

# Explorer Home/Gallery and Quick Access favorites. Only namespace pins and
# automatic-destination metadata are removed; user files are never deleted.
$homeClsid = '{679f85cb-0220-4080-b29b-5540cc05aab6}'
$galleryClsid = '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'
$recycleClsid = '{645FF040-5081-101B-9F08-00AA002F954E}'
foreach ($clsid in @($homeClsid, $galleryClsid)) {
    foreach ($root in @('HKCU:\Software\Classes\CLSID', 'HKLM:\SOFTWARE\Classes\CLSID')) {
        Set-DwordValue "$root\$clsid" 'System.IsPinnedToNameSpaceTree' 0
    }
    Remove-Item -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$clsid" -Recurse -Force -ErrorAction SilentlyContinue
}
Set-DwordValue "HKCU:\Software\Classes\CLSID\$recycleClsid" 'System.IsPinnedToNameSpaceTree' 1
$autoDest = Join-Path $env:APPDATA 'Microsoft\Windows\Recent\AutomaticDestinations\f01b4d95cf55d32a.automaticDestinations-ms'
Remove-Item -LiteralPath $autoDest -Force -ErrorAction SilentlyContinue

# Folder Options values matching the Explorer UI.
Set-DwordValue $advanced 'Hidden' 1
Set-DwordValue $advanced 'HideFileExt' 0
Set-DwordValue $advanced 'ShowSuperHidden' 0
Set-DwordValue $advanced 'NavPaneExpandToCurrentFolder' 0
Set-DwordValue $advanced 'LaunchTo' 1
Verify-Value $advanced 'Hidden' 1
Verify-Value $advanced 'HideFileExt' 0
Verify-Value $advanced 'ShowSuperHidden' 0

# Refresh shell after policy and namespace changes.
Write-SetupProgress 'config-windows11-settings' 'Refreshing Explorer and Start processes.'
Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe -ErrorAction SilentlyContinue | Out-Null

Write-Host '        [ OK ] Windows 11 26H2 compatibility settings applied.' -ForegroundColor Green
Write-SetupProgress 'config-windows11-settings' 'Completed successfully.'
exit 0
