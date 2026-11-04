# =============================================================================
# Velvet - Post-Installation Setup Script (setup.ps1)
# Interactive console setup on desktop logon
# Acquires elevated privileges reliably via standard self-elevation
# =============================================================================

# 1. Resolve Script Path and Acquire Administrator Privilege
$scriptPath = $MyInvocation.MyCommand.Path
if (-not $scriptPath) { $scriptPath = $PSCommandPath }
if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) {
    $scriptPath = "$env:ProgramData\Velvet\setup.ps1"
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isAdmin) {
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    } catch {
        Write-Host "[!] Failed to elevate privileges: $_" -ForegroundColor Red
        Start-Sleep -Seconds 5
    }
    exit 0
}

# Configure Console Window Appearance
try {
    $Host.UI.RawUI.WindowTitle = "Velvet - Post-Installation Setup"
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "White"
    Clear-Host
} catch {}

$velvetDir = "$env:ProgramData\Velvet"
$lockFile = "$env:TEMP\Velvet_Setup.lock"

# Mutex / Process check to avoid concurrent duplicate runs
$currentPid = $PID
$otherSetup = Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessId -ne $currentPid -and $_.CommandLine -match "setup\.ps1"
}
if ($otherSetup) {
    Write-Host "[!] Another setup process is currently running. Exiting duplicate instance." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    exit 0
}

# Ensure lock file is created
New-Item -ItemType File -Path $lockFile -Force -ErrorAction SilentlyContinue | Out-Null

function Resolve-SetupScript {
    param ([string]$ScriptName)
    $candidates = @(
        (Join-Path $PSScriptRoot $ScriptName),
        (Join-Path $velvetDir $ScriptName)
    )
    return ($candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
}

function Run-Step {
    param (
        [string]$StepNumber,
        [string]$Description,
        [scriptblock]$Action
    )
    Write-Host "[ $StepNumber ] $Description..." -ForegroundColor Cyan
    try {
        & $Action
    } catch {
        Write-Host "        [ WARN ] Step error bypassed: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                                   Velvet                                       " -ForegroundColor Cyan
Write-Host "                 Post-Installation Setup & Optimization                         " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " All tasks will be configured cleanly for the current user and system." -ForegroundColor Gray
Write-Host " Please keep this window open until all tasks are finished." -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # -------------------------------------------------------------------------
    # 0. Clean up RunOnce keys and Desktop shortcuts/batch files
    # -------------------------------------------------------------------------
    Run-Step "0/9" "Cleaning up legacy RunOnce keys and desktop shortcuts" {
        foreach ($runOnceKey in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")) {
            foreach ($valName in @("Velvet-Setup", "VelvetSetup", "Hunter-Setup", "HunterSetup", "pcUX-Setup", "pcUXSetup", "CyberOSSetup", "YenaOSSetup", "BasicOSFirstLogon", "BasicOSWallpaperStartup")) {
                Remove-ItemProperty -Path $runOnceKey -Name $valName -ErrorAction SilentlyContinue
            }
        }
        schtasks /delete /tn "Velvet-Setup" /f 2>$null
        schtasks /delete /tn "VelvetSetup" /f 2>$null
        schtasks /delete /tn "Hunter-Setup" /f 2>$null
        schtasks /delete /tn "HunterSetup" /f 2>$null
        schtasks /delete /tn "pcUX-Setup" /f 2>$null
        schtasks /delete /tn "pcUXSetup" /f 2>$null

        $desktops = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'), "C:\Users\Public\Desktop") | Select-Object -Unique
        foreach ($desk in $desktops) {
            if ($desk -and (Test-Path -LiteralPath $desk)) {
                Get-ChildItem -Path $desk -Filter "*.bat" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                Get-ChildItem -Path $desk -Filter "*.cmd" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                Get-ChildItem -Path $desk -Filter "*.lnk" -File -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -notmatch "This PC|Recycle Bin|Chrome|VLC|Bandizip"
                } | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "        [ OK ] Desktop clean-up complete." -ForegroundColor Green
    }

    # -------------------------------------------------------------------------
    # 1. Apply User Preferences, Explorer, Start, Taskbar & Notification Tweaks
    # -------------------------------------------------------------------------
    Run-Step "1/9" "Applying user preferences, start menu grid, taskbar and explorer tweaks" {
        $expKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        $advKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $schKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
        $startKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"
        $crossKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration"
        $notifKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
        $pushKey  = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications"

        New-Item -Path $expKey, $advKey, $schKey, $startKey, $crossKey, $notifKey, $pushKey -Force -ErrorAction SilentlyContinue | Out-Null

        # 0. Windows 10 Classic Context Menu Restoration ({86ca1aa0-34aa-4e8b-a509-50c905bae2a2})
        $oldContextClsid = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        reg.exe add "HKCU\Software\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
        reg.exe add "HKLM\SOFTWARE\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
        reg.exe add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
        reg.exe add "HKLM\SOFTWARE\Velvet\Services\OldContextMenu" /v state /t REG_DWORD /d 1 /f >$null 2>&1

        # 1. File Explorer Privacy
        Set-ItemProperty -Path $expKey -Name "ShowRecent" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $expKey -Name "ShowFrequent" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $expKey -Name "ShowCloudFilesInQuickAccess" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advKey -Name "Start_TrackDocs" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

        # 2. Toast Notifications
        Set-ItemProperty -Path $pushKey -Name "ToastEnabled" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $notifKey -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v "ToastEnabled" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v "NOC_GLOBAL_SETTING_TOASTS_ENABLED" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v "ToastEnabled" /t REG_DWORD /d 1 /f >$null 2>&1

        # 3. File Explorer Network folder icon visibility (System.IsPinnedToNameSpaceTree = 0)
        reg.exe add "HKCU\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
        reg.exe add "HKLM\SOFTWARE\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
        reg.exe add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1

        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
        $userSids = @()
        Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like 'S-1-5-21-*' -and $_.PSChildName -notlike '*_Classes' } | ForEach-Object {
            $userSids += $_.PSChildName
        }
        foreach ($sid in ($userSids | Select-Object -Unique)) {
            reg.exe add "HKU\$sid\Software\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
            reg.exe add "HKU\${sid}_Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\${sid}_Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Start" /v "ShowPinnedSection" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Start" /v "AllAppsViewMode" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Policies\Microsoft\Windows\Explorer" /v "NoStartMenuPinnedList" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "SearchboxTaskbarMode" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "MMTaskbarEnabled" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsResumeAllowed" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsOneDriveResumeAllowed" /t REG_DWORD /d 0 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\PushNotifications" /v "ToastEnabled" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" /v "NOC_GLOBAL_SETTING_TOASTS_ENABLED" /t REG_DWORD /d 1 /f >$null 2>&1
        }

        # 4. Personalization - Start Menu Pinned Section Disabled & Grid View
        Set-ItemProperty -Path $startKey -Name "ShowPinnedSection" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $startKey -Name "AllAppsViewMode" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "NoStartMenuPinnedList" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Start" /v "ShowPinnedSection" /t REG_DWORD /d 0 /f >$null 2>&1
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Start" /v "AllAppsViewMode" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "NoStartMenuPinnedList" /t REG_DWORD /d 1 /f >$null 2>&1

        # 5. Taskbar - Search Box Hidden (0)
        Set-ItemProperty -Path $schKey -Name "SearchboxTaskbarMode" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advKey -Name "SearchboxTaskbarMode" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d 0 /f >$null 2>&1
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "SearchboxTaskbarMode" /t REG_DWORD /d 0 /f >$null 2>&1

        # 6. Taskbar - Task View Button Disabled (0)
        Set-ItemProperty -Path $advKey -Name "ShowTaskViewButton" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowTaskViewButton" /t REG_DWORD /d 0 /f >$null 2>&1

        # 7. Taskbar - Cross Device Resume Disabled (0)
        Set-ItemProperty -Path $crossKey -Name "IsResumeAllowed" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $crossKey -Name "IsOneDriveResumeAllowed" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsResumeAllowed" /t REG_DWORD /d 0 /f >$null 2>&1
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsOneDriveResumeAllowed" /t REG_DWORD /d 0 /f >$null 2>&1

        # 8. Taskbar Behavior - Multi-monitor Taskbar Disabled (0)
        Set-ItemProperty -Path $advKey -Name "MMTaskbarEnabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "MMTaskbarEnabled" /t REG_DWORD /d 0 /f >$null 2>&1

        # 9. Dark Mode (Apps & System)
        $themePers = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        New-Item -Path $themePers -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $themePers -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $themePers -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $themePers -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        # 10. Microsoft PC Manager Popup Management and Bandizip block button
        foreach ($pcm in @("HKCU:\Software\Microsoft\PCManager", "HKLM:\SOFTWARE\Microsoft\PCManager")) {
            New-Item -Path $pcm -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $pcm -Name "EnablePopupBlock" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "PopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "BlockPopups" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "EnablePopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "AutoBlockPopup" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "InterceptPopup" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            New-Item -Path "$pcm\PopupManagement\Bandizip" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item -Path "$pcm\PopupManagement\Bandizip.exe" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item -Path "$pcm\PopupManagement\Apps\Bandizip" -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path "$pcm\PopupManagement" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement" -Name "Bandizip" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement" -Name "Bandizip.exe" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement\Bandizip" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement\Bandizip" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement\Bandizip" -Name "State" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement\Bandizip.exe" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement\Bandizip.exe" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement\Apps\Bandizip" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$pcm\PopupManagement\Apps\Bandizip" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        # HKU default user hives
        Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like 'S-1-5-21-*' -and $_.PSChildName -notlike '*_Classes' } | ForEach-Object {
            $sid = $_.PSChildName
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "EnablePopupBlock" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "PopupManagement" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "BlockPopups" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Enabled" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Bandizip" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Bandizip.exe" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "Blocked" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "Enabled" /t REG_DWORD /d 1 /f >$null 2>&1
            reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "State" /t REG_DWORD /d 1 /f >$null 2>&1
        }

        Write-Host "        [ OK ] User environment, taskbar and pop-up preferences configured." -ForegroundColor Green
    }

    # -------------------------------------------------------------------------
    # 2. Desktop Theme & Wallpapers
    # -------------------------------------------------------------------------
    Run-Step "2/9" "Applying Velvet desktop theme and wallpapers" {
        $cfgTheme = Resolve-SetupScript "config-theme.ps1"
        if ($cfgTheme) { & $cfgTheme }
    }

    # -------------------------------------------------------------------------
    # 3. Modern Notepad Configuration
    # -------------------------------------------------------------------------
    Run-Step "3/9" "Configuring Windows Notepad" {
        $cfgNotepad = Resolve-SetupScript "config-notepad.ps1"
        if ($cfgNotepad) { & $cfgNotepad }
    }

    # -------------------------------------------------------------------------
    # 4. Bloatware & Unnecessary Apps Removal
    # -------------------------------------------------------------------------
    Run-Step "4/9" "Removing bloatware, Edge, and OneDrive" {
        $remBloat = Resolve-SetupScript "remove-bloatware.ps1"
        if ($remBloat) {
            try {
                & $remBloat -Mode "All"
            } catch {
                Write-Host "        [ NOTE ] Bloatware removal pass bypassed." -ForegroundColor DarkGray
            }
        }
    }

    # -------------------------------------------------------------------------
    # 5. Essential Software Packages Installation
    #    (Bandizip Beta, qView & KakaoTalk installed via Direct Links; PC Manager via WinGet)
    # -------------------------------------------------------------------------
    Run-Step "5/9" "Installing essential software packages" {
        $instPkg = Resolve-SetupScript "install-packages.ps1"
        if ($instPkg) {
            try {
                & $instPkg
            } catch {
                Write-Host "        [ NOTE ] Package installer pass bypassed." -ForegroundColor DarkGray
            }
        }
    }

    # -------------------------------------------------------------------------
    # 6. File Extension Associations (Applied AFTER all app install/removal)
    # -------------------------------------------------------------------------
    Run-Step "6/9" "Configuring default file associations (Post-Install)" {
        $cfgAssoc = Resolve-SetupScript "config-associations.ps1"
        if ($cfgAssoc) {
            try {
                & $cfgAssoc
            } catch {
                Write-Host "        [ NOTE ] Associations pass bypassed." -ForegroundColor DarkGray
            }
        }
    }

    # -------------------------------------------------------------------------
    # 7. Windhawk Taskbar Styler Configuration
    # -------------------------------------------------------------------------
    Run-Step "7/9" "Configuring Windhawk Taskbar Styler" {
        $cfgWindhawk = Resolve-SetupScript "config-windhawk.ps1"
        if ($cfgWindhawk) { & $cfgWindhawk }
    }

    # -------------------------------------------------------------------------
    # 8. Temporary Files & Cache Cleanup
    # -------------------------------------------------------------------------
    Run-Step "8/9" "Running disk cleanup and purging temporary setup caches" {
        $cleanerScript = Resolve-SetupScript "cleaner.ps1"
        if ($cleanerScript) { & $cleanerScript }
    }

    # -------------------------------------------------------------------------
    # 9. Final Polish, Time Sync, and Explorer Refresh
    # -------------------------------------------------------------------------
    Run-Step "9/9" "Finalizing system polish and refreshing shell" {
        try {
            Start-Service -Name "w32time" -ErrorAction SilentlyContinue
            & w32tm.exe /config /syncfromflags:manual /manualpeerlist:"0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org" >$null 2>&1
            & w32tm.exe /config /update >$null 2>&1
            & w32tm.exe /resync /force >$null 2>&1
        } catch {}

        Stop-Process -Name "StartMenuExperienceHost" -Force -ErrorAction SilentlyContinue
        $exp = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        if ($exp) {
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Start-Process "explorer.exe" -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host "            [ SUCCESS ] Velvet Post-Installation Setup Completed!               " -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " The system will automatically restart in 10 seconds to apply all changes." -ForegroundColor Yellow
    Write-Host " (Press Enter to restart immediately...)" -ForegroundColor Gray
    Write-Host ""

    # Countdown with Enter key skip
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host -NoNewline "`rRestarting in $i seconds... "
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter' -or $key.Key -eq 'Spacebar') {
                break
            }
        }
        Start-Sleep -Seconds 1
    }

    Write-Host "`nInitiating system reboot..." -ForegroundColor Cyan
    shutdown.exe /r /t 0 /c "Velvet setup complete. Rebooting system..."
} finally {
    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
}

exit 0
