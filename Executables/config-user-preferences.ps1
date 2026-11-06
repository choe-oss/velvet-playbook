# =============================================================================
# Velvet - User, Explorer, Start, Taskbar and Notification Preferences
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-user-preferences' 'Starting user preference configuration.'
$expKey      = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
$advKey      = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$hideDeskNew = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
$hideDeskCls = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu"
$schKey      = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
$startKey    = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"
$crossKey    = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration"
$notifKey    = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
$pushKey     = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications"
$themePers   = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$polExpKey   = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"

Write-SetupProgress 'config-user-preferences' 'Creating user preference registry paths.'
New-Item -Path $expKey, $advKey, $hideDeskNew, $hideDeskCls, $schKey, $startKey, $crossKey, $notifKey, $pushKey, $themePers, $polExpKey -Force -ErrorAction SilentlyContinue | Out-Null

# 0. Windows 10 Classic Context Menu Restoration ({86ca1aa0-34aa-4e8b-a509-50c905bae2a2})
Write-SetupProgress 'config-user-preferences' 'Applying classic context menu settings.'
$oldContextClsid = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
& reg.exe add "HKCU\Software\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
& reg.exe add "HKLM\SOFTWARE\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
& reg.exe add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
& reg.exe add "HKLM\SOFTWARE\Velvet\Services\OldContextMenu" /v state /t REG_DWORD /d 1 /f >$null 2>&1

# 0-1. Hide All System Desktop Icons (Recycle Bin, This PC, User Files, Network, Control Panel)
Write-SetupProgress 'config-user-preferences' 'Hiding default desktop icons.'
$desktopIconClsids = @(
    "{645FF040-5081-101B-9F08-00AA002F954E}", # Recycle Bin
    "{20D04FE0-3AEA-1069-A2D8-08002B30309D}", # This PC
    "{59031a47-3f72-44a7-89c5-5595fe6b30ee}", # User's Files
    "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}", # Network
    "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"  # Control Panel
)
foreach ($clsid in $desktopIconClsids) {
    Set-ItemProperty -Path $hideDeskNew -Name $clsid -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $hideDeskCls -Name $clsid -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
}

# 1. File Explorer Privacy
Write-SetupProgress 'config-user-preferences' 'Applying File Explorer privacy settings.'
Set-ItemProperty -Path $expKey -Name "ShowRecent" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $expKey -Name "ShowFrequent" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $expKey -Name "ShowCloudFilesInQuickAccess" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $advKey -Name "Start_TrackDocs" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

# 2. Toast Notifications
Write-SetupProgress 'config-user-preferences' 'Applying notification settings.'
Set-ItemProperty -Path $pushKey -Name "ToastEnabled" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $notifKey -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue

# 3. File Explorer Navigation Pane & Quick Access (Favorites):
Write-SetupProgress 'config-user-preferences' 'Applying Explorer navigation settings.'
#    - Hide Network ({F02C1A0D-BE21-4350-88B0-7367FC96EF3C})
#    - Remove Music ({3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}, {1CF1260C-4DD0-4ebb-811F-33C572699FDE})
#    - Remove Videos ({f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}, {A0953C92-50DC-43bf-BE83-3742FED03C9C})
#    - Pin Recycle Bin ({645FF040-5081-101B-9F08-00AA002F954E})
$recycleBinClsid = "{645FF040-5081-101B-9F08-00AA002F954E}"
$hiddenNavClsids = @(
    "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}", # Network
    "{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}", # Music (This PC)
    "{1CF1260C-4DD0-4ebb-811F-33C572699FDE}", # Music (Folder)
    "{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}", # Videos (This PC)
    "{A0953C92-50DC-43bf-BE83-3742FED03C9C}"  # Videos (Folder)
)
foreach ($clsid in $hiddenNavClsids) {
    & reg.exe add "HKCU\Software\Classes\CLSID\$clsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKLM\SOFTWARE\Classes\CLSID\$clsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\$clsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
    if ($clsid -ne "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}") {
        & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$clsid" /f >$null 2>&1
        & reg.exe delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$clsid" /f >$null 2>&1
        & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$clsid\PropertyBag" /v "ThisPCPolicy" /t REG_SZ /d "Hide" /f >$null 2>&1
        & reg.exe add "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$clsid\PropertyBag" /v "ThisPCPolicy" /t REG_SZ /d "Hide" /f >$null 2>&1
    }
}

# Pin Recycle Bin to Navigation Pane via Registry
& reg.exe add "HKCU\Software\Classes\CLSID\$recycleBinClsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 1 /f >$null 2>&1
& reg.exe add "HKLM\SOFTWARE\Classes\CLSID\$recycleBinClsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 1 /f >$null 2>&1
& reg.exe add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\$recycleBinClsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 1 /f >$null 2>&1

# 4. Personalization - Start Menu Pinned Section Disabled & Grid View
Write-SetupProgress 'config-user-preferences' 'Applying Start menu settings.'
Set-ItemProperty -Path $startKey -Name "ShowPinnedSection" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $startKey -Name "AllAppsViewMode" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $polExpKey -Name "NoStartMenuPinnedList" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue

# 5. Taskbar - Search Box Hidden (0)
Write-SetupProgress 'config-user-preferences' 'Applying taskbar settings.'
Set-ItemProperty -Path $schKey -Name "SearchboxTaskbarMode" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $advKey -Name "SearchboxTaskbarMode" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

# 6. Taskbar - Task View Button Disabled (0)
Set-ItemProperty -Path $advKey -Name "ShowTaskViewButton" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

# 7. Taskbar - Cross Device Resume Disabled (0)
Set-ItemProperty -Path $crossKey -Name "IsResumeAllowed" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $crossKey -Name "IsOneDriveResumeAllowed" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

# 8. Taskbar Behavior - Multi-monitor Taskbar Disabled (0)
Set-ItemProperty -Path $advKey -Name "MMTaskbarEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

# 9. Dark Mode (Apps & System) and Transparency Disabled (0)
Set-ItemProperty -Path $themePers -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themePers -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themePers -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# Apply across all loaded user SIDs in HKEY_USERS
Write-SetupProgress 'config-user-preferences' 'Enumerating loaded user registry hives.'
if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}
$userSids = Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue | Where-Object {
    $_.PSChildName -like 'S-1-5-21-*' -and $_.PSChildName -notlike '*_Classes'
} | Select-Object -ExpandProperty PSChildName -Unique

Write-SetupProgress 'config-user-preferences' "Applying settings to $(@($userSids).Count) loaded user hive(s)."
foreach ($sid in $userSids) {
    Write-SetupProgress 'config-user-preferences' "Applying loaded hive $sid."
    foreach ($clsid in $desktopIconClsids) {
        & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v $clsid /t REG_DWORD /d 1 /f >$null 2>&1
        & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu" /v $clsid /t REG_DWORD /d 1 /f >$null 2>&1
    }
    & reg.exe add "HKU\$sid\Software\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
    & reg.exe add "HKU\${sid}_Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
    foreach ($clsid in $hiddenNavClsids) {
        & reg.exe add "HKU\$sid\Software\Classes\CLSID\$clsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
        & reg.exe add "HKU\${sid}_Classes\CLSID\$clsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
    }
    & reg.exe add "HKU\$sid\Software\Classes\CLSID\$recycleBinClsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKU\${sid}_Classes\CLSID\$recycleBinClsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowRecent" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowCloudFilesInQuickAccess" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Start_TrackDocs" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Start" /v "ShowPinnedSection" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Start" /v "AllAppsViewMode" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Policies\Microsoft\Windows\Explorer" /v "NoStartMenuPinnedList" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "SearchboxTaskbarMode" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "MMTaskbarEnabled" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsResumeAllowed" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsOneDriveResumeAllowed" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v "ToastEnabled" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v "NOC_GLOBAL_SETTING_TOASTS_ENABLED" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 0 /f >$null 2>&1
}

Write-SetupProgress 'config-user-preferences' 'Completed successfully.'
exit 0