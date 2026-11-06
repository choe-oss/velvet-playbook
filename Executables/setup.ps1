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
$script:StepFailures = @()
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
        $script:StepFailures += "$StepNumber ${Description}: $($_.Exception.Message)"
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

function Invoke-ChildStep {
    param (
        [string]$ScriptName,
        [object[]]$Arguments = @(),
        [int]$TimeoutMinutes = 30
    )

    $scriptPath = Resolve-SetupScript $ScriptName
    Invoke-SetupScript -Path $scriptPath -Arguments $Arguments -TimeoutMinutes $TimeoutMinutes
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
    # 1. User, Explorer, Start, Taskbar & Notification Preferences
    # -------------------------------------------------------------------------
    Run-Step "1/9" "Applying user preferences, start menu grid, taskbar and explorer tweaks" {
        Invoke-ChildStep "config-user-preferences.ps1"
    }

    # -------------------------------------------------------------------------
    # 2. Desktop Theme & Wallpapers
    # -------------------------------------------------------------------------
    Run-Step "2/9" "Applying Velvet desktop theme and wallpapers" {
        Invoke-ChildStep "config-theme.ps1"
    }

    # -------------------------------------------------------------------------
    # 3. Bloatware & Unnecessary Apps Removal
    # -------------------------------------------------------------------------
    Run-Step "3/9" "Removing bloatware, Edge, and OneDrive" {
        Invoke-ChildStep "remove-bloatware.ps1" @('-Mode', 'All')
    }

    # -------------------------------------------------------------------------
    # 4. Essential Software Packages Installation
    #    (Applications are resolved through the local WinGet source.)
    # -------------------------------------------------------------------------
    Run-Step "4/9" "Installing essential software packages" {
        Invoke-ChildStep "install-packages.ps1"
    }

    # -------------------------------------------------------------------------
    # 5. Modern Notepad Configuration
    # -------------------------------------------------------------------------
    Run-Step "5/9" "Configuring Windows Notepad" {
        Invoke-ChildStep "config-notepad.ps1"
    }

    # -------------------------------------------------------------------------
    # 6. File Extension Associations (Applied AFTER all app install/removal)
    # -------------------------------------------------------------------------
    Run-Step "6/9" "Configuring default file associations (Post-Install)" {
        Invoke-ChildStep "config-associations.ps1"
    }

    # -------------------------------------------------------------------------
    # 7. Windhawk Taskbar Styler Configuration
    # -------------------------------------------------------------------------
    Run-Step "7/9" "Configuring Windhawk Taskbar Styler" {
        Invoke-ChildStep "config-windhawk.ps1"
    }

    # -------------------------------------------------------------------------
    # 8. Temporary Files & Cache Cleanup
    # -------------------------------------------------------------------------
    Run-Step "8/9" "Running disk cleanup and purging temporary setup caches" {
        Invoke-ChildStep "cleaner.ps1"
    }

    # -------------------------------------------------------------------------
    # 9. Final Polish, Post-Install Desktop Sweep, and Time Sync
    # -------------------------------------------------------------------------
    Run-Step "9/9" "Finalizing system polish, sweeping desktop shortcuts, and syncing time" {
        # Sweep desktop again to remove any shortcuts created by software installers in Step 4
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
    # Mark first-logon setup as completed and remove the scheduled task (no re-run on next logon)
    try {
        New-Item -Path $setupStateKey -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $setupStateKey -Name "Completed" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $setupStateKey -Name "Pending" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $setupStateKey -Name "CompletedAt" -Type String -Value (Get-Date -Format s) -Force -ErrorAction SilentlyContinue
    } catch {}
    & schtasks.exe /delete /tn $setupTaskName /f > $null 2>&1

    Write-Host ""
    $resultColor = if ($script:StepFailures.Count -eq 0) { 'Green' } else { 'Yellow' }
    $resultLabel = if ($script:StepFailures.Count -eq 0) { '[ SUCCESS ]' } else { '[ WARNINGS ]' }
    Write-Host "================================================================================" -ForegroundColor $resultColor
    Write-Host "            $resultLabel Velvet Post-Installation Setup Completed!               " -ForegroundColor $resultColor
    Write-Host "================================================================================" -ForegroundColor $resultColor
    if ($script:StepFailures.Count -gt 0) {
        Write-Host " $($script:StepFailures.Count) step(s) reported errors; remaining steps continued." -ForegroundColor Yellow
        $script:StepFailures | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
    }
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
