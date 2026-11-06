# =============================================================================
# Velvet - Post-Installation Setup Script (setup.ps1)
# Interactive console setup on first desktop logon
# Launched elevated (no UAC) by the "Velvet-Setup" scheduled task (register-setup-task.ps1)
# =============================================================================

# 1. Resolve Script Path and Acquire Administrator Privilege
$scriptPath = $PSCommandPath
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) {
    $scriptPath = "$env:ProgramData\Velvet\setup.ps1"
}
if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Host "[!] setup.ps1 could not be located. Expected it at '$scriptPath'." -ForegroundColor Red
    exit 1
}
$scriptDir = Split-Path -Parent $scriptPath

$setupTaskName = "Velvet-Setup"
$setupStateKey = "HKLM:\SOFTWARE\Velvet\Setup"
$psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

# Normal path: launched by the "Velvet-Setup" scheduled task (Highest privileges) -> already elevated, no UAC.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isAdmin) {
    # Manual launch fallback: start the registered scheduled task without prompting for UAC.
    & schtasks.exe /run /tn $setupTaskName > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[+] Started elevated setup via scheduled task '$setupTaskName'." -ForegroundColor Cyan
        exit 0
    }
    Write-Host "[!] Setup is not elevated and the '$setupTaskName' task could not be started. No UAC prompt was requested." -ForegroundColor Red
    exit 1
}

# Already completed on a previous logon -> remove leftover task and exit silently
$setupState = Get-ItemProperty -Path $setupStateKey -ErrorAction SilentlyContinue
if ($setupState -and $setupState.Completed -eq 1) {
    & schtasks.exe /delete /tn $setupTaskName /f > $null 2>&1
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

# Named Mutex check to avoid concurrent duplicate runs reliably
$mutexName = "Global\VelvetPostInstallSetupMutex"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    Write-Host "[!] Another setup process is currently running. Exiting duplicate instance." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    exit 0
}

# Ensure lock file is created
New-Item -ItemType File -Path $lockFile -Force -ErrorAction SilentlyContinue | Out-Null

function Resolve-SetupScript {
    param ([string]$ScriptName)
    $candidates = @()
    if ($scriptDir) { $candidates += (Join-Path $scriptDir $ScriptName) }
    if ($PSScriptRoot) { $candidates += (Join-Path $PSScriptRoot $ScriptName) }
    $candidates += (Join-Path $velvetDir $ScriptName)

    return ($candidates | Select-Object -Unique | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
}

function Clear-AllDesktopItems {
    $desktops = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        "C:\Users\Public\Desktop",
        "C:\Users\Default\Desktop"
    ) | Where-Object { $_ } | Select-Object -Unique

    foreach ($desk in $desktops) {
        if (Test-Path -LiteralPath $desk) {
            foreach ($ext in @("*.lnk", "*.url", "*.bat", "*.cmd")) {
                Get-ChildItem -Path $desk -Filter $ext -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Run-Step {
    param (
        [string]$StepNumber,
        [string]$Description,
        [scriptblock]$Action
    )

    $stepMatch = [regex]::Match($StepNumber, '^\s*(\d+)\s*/\s*(\d+)\s*$')
    $stepIndex = if ($stepMatch.Success) { [int]$stepMatch.Groups[1].Value } else { 0 }
    $stepTotal = if ($stepMatch.Success) { [int]$stepMatch.Groups[2].Value } else { 9 }
    $percent = [Math]::Min(100, [Math]::Max(0, [int](($stepIndex / ($stepTotal + 1)) * 100)))
    $barWidth = 30
    $filled = [Math]::Floor(($percent / 100) * $barWidth)
    $bar = ('#' * $filled).PadRight($barWidth, '-')

    Write-Progress -Activity "Velvet Post-Installation Setup" -Status "$StepNumber $Description" -PercentComplete $percent
    Write-Host "[ $StepNumber ] $Description... [$bar] $percent%" -ForegroundColor Cyan
    try {
        & $Action
        $completedPercent = [Math]::Min(100, [int](($stepIndex / $stepTotal) * 100))
        Write-Progress -Activity "Velvet Post-Installation Setup" -Status "$StepNumber completed" -PercentComplete $completedPercent
        Write-Host "        [ OK ] $Description" -ForegroundColor Green
    } catch {
        $completedPercent = [Math]::Min(100, [int](($stepIndex / $stepTotal) * 100))
        Write-Progress -Activity "Velvet Post-Installation Setup" -Status "$StepNumber completed with warnings" -PercentComplete $completedPercent
        Write-Host "        [ WARN ] Step continued after error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Invoke-SetupScript {
    param (
        [string]$Path,
        [object[]]$Arguments = @(),
        [int]$TimeoutMinutes = 30
    )

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        throw "Required setup script was not found: $Path"
    }

    $childArguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $Path
    ) + $Arguments

    $argumentLine = ($childArguments | ForEach-Object {
        '"' + ([string]$_).Replace('"', '\"') + '"'
    }) -join ' '
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $psExe
    $startInfo.Arguments = $argumentLine
    $startInfo.WorkingDirectory = $scriptDir
    $startInfo.UseShellExecute = $false
    $child = New-Object System.Diagnostics.Process
    $child.StartInfo = $startInfo
    $child.Start() | Out-Null

    if (-not $child.WaitForExit($TimeoutMinutes * 60 * 1000)) {
        $child.Kill()
        throw "$([System.IO.Path]::GetFileName($Path)) exceeded its $TimeoutMinutes minute timeout"
    }

    if ($child.ExitCode -ne 0) {
        throw "$([System.IO.Path]::GetFileName($Path)) exited with code $($child.ExitCode)"
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
    # 0. Clean up RunOnce keys and all Desktop shortcuts/batch files
    # -------------------------------------------------------------------------
    Run-Step "0/9" "Cleaning up legacy RunOnce keys and desktop items" {
        $legacyNames = @(
            "Velvet-Setup", "VelvetSetup",
            "Hunter-Setup", "HunterSetup",
            "pcUX-Setup", "pcUXSetup",
            "SYSUX-Setup", "SYSUXSetup", "System76-OS-Setup",
            "CyberOSSetup", "YenaOSSetup",
            "BasicOSFirstLogon", "BasicOSWallpaperStartup",
            "CarbonFirstLogon", "CarbonWallpaperStartup",
            "TinyOSWallpaperStartup"
        )
        foreach ($runOnceKey in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")) {
            foreach ($valName in $legacyNames) {
                Remove-ItemProperty -Path $runOnceKey -Name $valName -ErrorAction SilentlyContinue
            }
        }
        foreach ($taskName in $legacyNames) {
            # Keep the active "Velvet-Setup" task until setup completes (allows retry on next logon)
            if ($taskName -eq $setupTaskName) { continue }
            & schtasks.exe /delete /tn $taskName /f >$null 2>&1
        }

        Clear-AllDesktopItems
        Write-Host "        [ OK ] Desktop clean-up complete." -ForegroundColor Green
    }

    # -------------------------------------------------------------------------
    # -------------------------------------------------------------------------
    # 1. Desktop Theme & Wallpapers
    # -------------------------------------------------------------------------
    Run-Step "1/9" "Applying Velvet desktop theme and wallpapers" {
        $cfgTheme = Resolve-SetupScript "config-theme.ps1"
        Invoke-SetupScript -Path $cfgTheme
    }

    # -------------------------------------------------------------------------
    # 2. Modern Notepad Configuration
    # -------------------------------------------------------------------------
    Run-Step "2/9" "Configuring Windows Notepad" {
        $cfgNotepad = Resolve-SetupScript "config-notepad.ps1"
        Invoke-SetupScript -Path $cfgNotepad
    }

    # -------------------------------------------------------------------------
    # 3. Bloatware & Unnecessary Apps Removal
    # -------------------------------------------------------------------------
    Run-Step "3/9" "Removing bloatware, Edge, and OneDrive" {
        $remBloat = Resolve-SetupScript "remove-bloatware.ps1"
        Invoke-SetupScript -Path $remBloat -Arguments @('-Mode', 'All')
    }

    # -------------------------------------------------------------------------
    # 4. Essential Software Packages Installation
    #    (Bandizip Beta, qView & KakaoTalk installed via Direct Links; PC Manager & others via WinGet)
    # -------------------------------------------------------------------------
    Run-Step "4/9" "Installing essential software packages" {
        $instPkg = Resolve-SetupScript "install-packages.ps1"
        Invoke-SetupScript -Path $instPkg
    }

    # -------------------------------------------------------------------------
    # 5. File Extension Associations (Applied AFTER all app install/removal)
    # -------------------------------------------------------------------------
    Run-Step "5/9" "Configuring default file associations (Post-Install)" {
        $cfgAssoc = Resolve-SetupScript "config-associations.ps1"
        Invoke-SetupScript -Path $cfgAssoc
    }

    # -------------------------------------------------------------------------
    # 6. Windhawk Taskbar Styler Configuration
    # -------------------------------------------------------------------------
    Run-Step "6/9" "Configuring Windhawk Taskbar Styler" {
        $cfgWindhawk = Resolve-SetupScript "config-windhawk.ps1"
        Invoke-SetupScript -Path $cfgWindhawk
    }

    # -------------------------------------------------------------------------
    # 7. Temporary Files & Cache Cleanup
    # -------------------------------------------------------------------------
    Run-Step "7/9" "Running disk cleanup and purging temporary setup caches" {
        $cleanerScript = Resolve-SetupScript "cleaner.ps1"
        Invoke-SetupScript -Path $cleanerScript
    }

    # -------------------------------------------------------------------------
    # 8. Final Polish, Post-Install Desktop Sweep, and Time Sync
    # -------------------------------------------------------------------------
    Run-Step "8/9" "Finalizing system polish, sweeping desktop shortcuts, and syncing time" {
        # Sweep desktop again to remove any shortcuts created by software installers in Step 5
        Clear-AllDesktopItems

        try {
            Set-Service -Name "w32time" -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name "w32time" -ErrorAction SilentlyContinue
            & w32tm.exe /config /syncfromflags:manual /manualpeerlist:"0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org" >$null 2>&1
            & w32tm.exe /config /update >$null 2>&1
            & w32tm.exe /resync /force >$null 2>&1
        } catch {}
    }

    # -------------------------------------------------------------------------
    # 9. Apply User Preferences, Explorer, Start, Taskbar & Notification Tweaks
    # -------------------------------------------------------------------------
    Run-Step "9/9" "Applying user preferences, start menu grid, taskbar and explorer tweaks" {
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

        New-Item -Path $expKey, $advKey, $hideDeskNew, $hideDeskCls, $schKey, $startKey, $crossKey, $notifKey, $pushKey, $themePers, $polExpKey -Force -ErrorAction SilentlyContinue | Out-Null

        # 0. Windows 10 Classic Context Menu Restoration ({86ca1aa0-34aa-4e8b-a509-50c905bae2a2})
        $oldContextClsid = "{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        & reg.exe add "HKCU\Software\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
        & reg.exe add "HKLM\SOFTWARE\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
        & reg.exe add "HKLM\SOFTWARE\WOW6432Node\Classes\CLSID\$oldContextClsid" /ve /d "" /f >$null 2>&1
        & reg.exe add "HKLM\SOFTWARE\Velvet\Services\OldContextMenu" /v state /t REG_DWORD /d 1 /f >$null 2>&1

        # 0-1. Hide All System Desktop Icons (Recycle Bin, This PC, User Files, Network, Control Panel)
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
        Set-ItemProperty -Path $expKey -Name "ShowRecent" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $expKey -Name "ShowFrequent" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $expKey -Name "ShowCloudFilesInQuickAccess" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advKey -Name "Start_TrackDocs" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue

        # 2. Toast Notifications
        Set-ItemProperty -Path $pushKey -Name "ToastEnabled" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $notifKey -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue

        # 3. File Explorer Navigation Pane & Quick Access (Favorites):
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
        Set-ItemProperty -Path $startKey -Name "ShowPinnedSection" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $startKey -Name "AllAppsViewMode" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $polExpKey -Name "NoStartMenuPinnedList" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue

        # 5. Taskbar - Search Box Hidden (0)
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

        # 10. Microsoft PC Manager Popup Management and Bandizip block toggle
        foreach ($pcm in @("HKCU:\Software\Microsoft\PCManager", "HKLM:\SOFTWARE\Microsoft\PCManager")) {
            New-Item -Path $pcm, "$pcm\PopupManagement\Bandizip", "$pcm\PopupManagement\Bandizip.exe", "$pcm\PopupManagement\Apps\Bandizip" -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $pcm -Name "EnablePopupBlock" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "PopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "BlockPopups" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "EnablePopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "AutoBlockPopup" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $pcm -Name "InterceptPopup" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
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

        # Apply across all loaded user SIDs in HKEY_USERS
        if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
            New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
        }
        $userSids = Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue | Where-Object {
            $_.PSChildName -like 'S-1-5-21-*' -and $_.PSChildName -notlike '*_Classes'
        } | Select-Object -ExpandProperty PSChildName -Unique

        foreach ($sid in $userSids) {
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
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "EnablePopupBlock" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "PopupManagement" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "BlockPopups" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Enabled" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Bandizip" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Bandizip.exe" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "Blocked" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "Enabled" /t REG_DWORD /d 1 /f >$null 2>&1
            & reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "State" /t REG_DWORD /d 1 /f >$null 2>&1
        }

        Write-Host "        [ OK ] User environment, taskbar and pop-up preferences configured." -ForegroundColor Green
    }

    # Mark first-logon setup as completed and remove the scheduled task (no re-run on next logon)
    try {
        New-Item -Path $setupStateKey -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $setupStateKey -Name "Completed" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $setupStateKey -Name "Pending" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $setupStateKey -Name "CompletedAt" -Type String -Value (Get-Date -Format s) -Force -ErrorAction SilentlyContinue
    } catch {}
    & schtasks.exe /delete /tn $setupTaskName /f > $null 2>&1

    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host "            [ SUCCESS ] Velvet Post-Installation Setup Completed!               " -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " The system will automatically restart in 10 seconds to apply all changes." -ForegroundColor Yellow
    Write-Host " (Press Enter or Spacebar to restart immediately...)" -ForegroundColor Gray
    Write-Host ""

    # Countdown with Enter/Spacebar key skip
    for ($i = 10; $i -gt 0; $i--) {
        Write-Host -NoNewline "`rRestarting in $i seconds... "
        try {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Enter' -or $key.Key -eq 'Spacebar') {
                    break
                }
            }
        } catch {}
        Start-Sleep -Seconds 1
    }

    Write-Host "`nInitiating system reboot..." -ForegroundColor Cyan
    Write-Progress -Activity "Velvet Post-Installation Setup" -Status "Setup complete; restarting Windows" -PercentComplete 100
    & shutdown.exe /r /t 0 /c "Velvet setup complete. Rebooting system..."
} finally {
    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    if ($mutex -and $createdNew) {
        try { $mutex.ReleaseMutex() } catch {}
        $mutex.Dispose()
    }
}

exit 0
