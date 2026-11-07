# =============================================================================
# Velvet - Post-Installation Setup Script (setup.ps1)
# Interactive console setup on first desktop logon or standalone execution
# Launched elevated (no UAC) via the "Velvet-Setup" scheduled task
# =============================================================================
[CmdletBinding()]
param (
    [switch]$Force,
    [switch]$NoReboot,
    [switch]$Standalone,
    [switch]$Scheduled
)

function Invoke-SchtasksSafe {
    param (
        [string[]]$Arguments
    )

    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & schtasks.exe @Arguments > $null 2>&1
        return [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevPref
    }
}

# 1. Resolve Script Path and Acquire Administrator Privilege
$scriptPath = $PSCommandPath
if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) {
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'setup.ps1'))) {
        $scriptPath = Join-Path $PSScriptRoot 'setup.ps1'
    } else {
        $scriptPath = "$env:ProgramData\Velvet\setup.ps1"
    }
}
if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Host "[!] setup.ps1 could not be located. Expected it at '$scriptPath'." -ForegroundColor Red
    exit 1
}
$scriptDir = Split-Path -Parent $scriptPath

$setupTaskName = "Velvet-Setup"
$setupStateKey = "HKLM:\SOFTWARE\Velvet\Setup"
$userStateKey  = "HKCU:\Software\Velvet\Setup"
$uacKey        = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

# Silent Elevation Check: never use -Verb RunAs (no UAC prompt).
# Trigger the pre-registered "Velvet-Setup" scheduled task (HighestAvailable, no UAC).
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
if (-not $isAdmin) {
    try {
        New-Item -Path $userStateKey -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $userStateKey -Name "ManualLaunch" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $userStateKey -Name "Force" -Type DWord -Value ([int][bool]$Force) -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $userStateKey -Name "NoReboot" -Type DWord -Value ([int][bool]$NoReboot) -Force -ErrorAction SilentlyContinue
    } catch {}

    $runCode = Invoke-SchtasksSafe -Arguments @('/run', '/tn', $setupTaskName)
    if ($runCode -eq 0) {
        Write-Host "[+] Started silently elevated setup via scheduled task '$setupTaskName'." -ForegroundColor Cyan
        exit 0
    }

    Write-Host "[!] Setup is not elevated and the '$setupTaskName' task could not be started (exit code $runCode). No UAC prompt was requested." -ForegroundColor Red
    exit 1
}

# Check if this elevated run was triggered by a standalone/manual launch
try {
    $userState = Get-ItemProperty -Path $userStateKey -ErrorAction SilentlyContinue
    if ($userState -and $userState.ManualLaunch -eq 1) {
        $Standalone = $true
        if ($userState.Force -eq 1) { $Force = $true }
        if ($userState.NoReboot -eq 1) { $NoReboot = $true }
        Set-ItemProperty -Path $userStateKey -Name "ManualLaunch" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $userStateKey -Name "Force" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $userStateKey -Name "NoReboot" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
    }
} catch {}

if (-not $Scheduled) {
    $Standalone = $true
}

function Disable-SetupLogonTrigger {
    $velvetTargetDir = "$env:ProgramData\Velvet"
    $targetSetupPath = Join-Path $velvetTargetDir 'setup.ps1'
    if (-not (Test-Path -LiteralPath $targetSetupPath)) {
        $targetSetupPath = $scriptPath
    }
    $onDemandXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Velvet</Author>
    <Description>Velvet post-installation setup (on-demand silent elevation).</Description>
    <URI>\$setupTaskName</URI>
    <SecurityDescriptor>D:(A;;FA;;;BA)(A;;FA;;;SY)(A;;FRFX;;;AU)(A;;FRFX;;;IU)</SecurityDescriptor>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>false</Enabled>
      <Delay>PT10S</Delay>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <GroupId>S-1-5-32-544</GroupId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$psExe</Command>
      <Arguments>-NoExit -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "$targetSetupPath" -Scheduled</Arguments>
      <WorkingDirectory>$velvetTargetDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
    $onDemandXml = $onDemandXml.TrimStart()
    $updated = $false
    try {
        $svc = New-Object -ComObject Schedule.Service
        $svc.Connect()
        $folder = $svc.GetFolder('\')
        [void]$folder.RegisterTask($setupTaskName, $onDemandXml, 6, $null, $null, 4)
        $updated = $true
    } catch {}
    if (-not $updated) {
        try {
            Register-ScheduledTask -TaskName $setupTaskName -Xml $onDemandXml -Force | Out-Null
            $updated = $true
        } catch {}
    }
    if (-not $updated) {
        $tmpXml = Join-Path $env:TEMP 'Velvet-Setup-OnDemand.xml'
        try {
            [System.IO.File]::WriteAllText($tmpXml, $onDemandXml, [System.Text.Encoding]::Unicode)
            [void](Invoke-SchtasksSafe -Arguments @('/create', '/tn', $setupTaskName, '/xml', $tmpXml, '/f'))
        } finally {
            Remove-Item -LiteralPath $tmpXml -Force -ErrorAction SilentlyContinue
        }
    }
}

# If launched automatically at logon (-Scheduled) and setup was already completed,
# disable the logon trigger (preserving on-demand silent elevation) and exit cleanly.
$setupState = Get-ItemProperty -Path $setupStateKey -ErrorAction SilentlyContinue
if (-not $Force -and -not $Standalone -and $setupState -and $setupState.Completed -eq 1) {
    Write-Host "[INFO] Setup was already completed. Disabling logon trigger on '$setupTaskName'." -ForegroundColor Gray
    Disable-SetupLogonTrigger
    foreach ($runOnceKey in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")) {
        Remove-ItemProperty -Path $runOnceKey -Name $setupTaskName, "VelvetSetup" -ErrorAction SilentlyContinue
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

function Write-Diagnostic {
    param (
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] $Message"
    Write-Host $line -ForegroundColor $Color
}

Write-Diagnostic "Setup process started. ScriptPath='$scriptPath'; ScriptDir='$scriptDir'." Cyan
Write-Diagnostic "Running as administrator: $isAdmin; PowerShell='$($PSVersionTable.PSVersion)'." Gray

# Named Mutex check to avoid concurrent duplicate runs reliably
$mutexName = "Global\VelvetPostInstallSetupMutex"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
$script:StepFailures = @()
if (-not $createdNew) {
    Write-Diagnostic "[WARN] Another setup process is currently running. Exiting duplicate instance." Yellow
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

    Write-Diagnostic "[STEP $StepNumber START] $Description" Cyan
    try {
        & $Action
        Write-Diagnostic "[STEP $StepNumber OK] $Description" Green
    } catch {
        $script:StepFailures += "$StepNumber ${Description}: $($_.Exception.Message)"
        Write-Diagnostic "[STEP $StepNumber WARN] Step continued after error: $($_.Exception.Message)" Yellow
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
        '-NonInteractive'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $Path
    ) + $Arguments

    function ConvertTo-ProcessArgument {
        param ([object]$Value)

        $text = [string]$Value
        if ($text -notmatch '[\s"]') {
            return $text
        }

        return '"' + ($text -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
    }

    Write-Diagnostic "[CHILD START] $Path $($Arguments -join ' ')" Cyan
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $psExe
        $startInfo.WorkingDirectory = $scriptDir
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $false
        $startInfo.Arguments = (($childArguments | ForEach-Object {
            ConvertTo-ProcessArgument $_
        }) -join ' ')
        $child = [System.Diagnostics.Process]::Start($startInfo)
        if (-not $child) {
            throw "PowerShell child process could not be started."
        }
    } catch {
        Write-Diagnostic "[CHILD START ERROR] $Path : $($_.Exception.Message)" Red
        throw
    }

    $timeoutMilliseconds = $TimeoutMinutes * 60 * 1000
    $elapsedMilliseconds = 0
    while (-not $child.HasExited -and $elapsedMilliseconds -lt $timeoutMilliseconds) {
        Start-Sleep -Seconds 10
        $elapsedMilliseconds += 10000
        if (-not $child.HasExited) {
            Write-Diagnostic "[CHILD WAIT] $Path is still running after $([math]::Round($elapsedMilliseconds / 1000)) seconds." Yellow
        }
    }

    if (-not $child.HasExited) {
        try {
            $child.Kill()
            $child.WaitForExit()
        } catch {}
        Write-Diagnostic "[CHILD TIMEOUT] $Path exceeded its $TimeoutMinutes minute timeout." Red
        throw "$([System.IO.Path]::GetFileName($Path)) exceeded its $TimeoutMinutes minute timeout"
    }
    $child.WaitForExit()
    $exitCode = $child.ExitCode
    Write-Diagnostic "[CHILD EXIT] $Path ExitCode=$exitCode" Gray
    if ($exitCode -ne 0) {
        throw "$([System.IO.Path]::GetFileName($Path)) exited with code $exitCode"
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
            # Keep the active "Velvet-Setup" task (allows retry on next logon and on-demand silent elevation)
            if ($taskName -eq $setupTaskName) { continue }
            [void](Invoke-SchtasksSafe -Arguments @('/delete', '/tn', $taskName, '/f'))
        }

        Clear-AllDesktopItems
        Write-Host "        [ OK ] Desktop clean-up complete." -ForegroundColor Green
    }

    # -------------------------------------------------------------------------
    # 1. User, Explorer, Start, Taskbar & Notification Preferences
    # -------------------------------------------------------------------------
    Run-Step "1/9" "Applying user preferences, start menu grid, taskbar and explorer tweaks" {
        Invoke-ChildStep "config-appcompat.ps1"
        Invoke-ChildStep "config-user-preferences.ps1"
        Invoke-ChildStep "config-windows11-settings.ps1"
        Invoke-ChildStep "config-shell-compatibility.ps1"
        Invoke-ChildStep "config-profile.ps1"
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
        Invoke-ChildStep "cleanup-edge-ghosts.ps1"
    }

    # -------------------------------------------------------------------------
    # 4. Essential Software Packages Installation
    #    (Applications are resolved through the local WinGet source.)
    # -------------------------------------------------------------------------
    Run-Step "4/9" "Installing essential software packages" {
        Invoke-ChildStep "install-packages.ps1"
    }

    # -------------------------------------------------------------------------
    # 5. Installed Application Settings
    # -------------------------------------------------------------------------
    Run-Step "5/9" "Configuring installed application settings" {
        Invoke-ChildStep "config-application-settings.ps1"
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

    if ($script:StepFailures.Count -gt 0) {
        Write-Host ""
        Write-Host "================================================================================" -ForegroundColor Red
        Write-Host "             [ FAILED ] Velvet Post-Installation Setup Incomplete              " -ForegroundColor Red
        Write-Host "================================================================================" -ForegroundColor Red
        Write-Host " $($script:StepFailures.Count) step(s) failed. Completion was not recorded." -ForegroundColor Yellow
        $script:StepFailures | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
        Write-Host ""
        Write-Diagnostic "[FATAL] Setup did not complete successfully. The scheduled task was preserved for retry." Red
        exit 1
    }

    # -------------------------------------------------------------------------
    # Mark first-logon setup as completed, restore UAC consent level, and disable the logon trigger
    # (Preserves the on-demand scheduled task so future standalone setup.ps1 runs elevate without UAC)
    try {
        New-Item -Path $setupStateKey -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $setupStateKey -Name "Completed" -Type DWord -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $setupStateKey -Name "Pending" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $setupStateKey -Name "CompletedAt" -Type String -Value (Get-Date -Format s) -Force -ErrorAction SilentlyContinue

        $savedConsent = (Get-ItemProperty -Path $setupStateKey -Name "SavedConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue).SavedConsentPromptBehaviorAdmin
        if ($null -eq $savedConsent) { $savedConsent = 5 }
        Set-ItemProperty -Path $uacKey -Name "ConsentPromptBehaviorAdmin" -Type DWord -Value ([int]$savedConsent) -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacKey -Name "PromptOnSecureDesktop" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
    } catch {}
    Disable-SetupLogonTrigger
    foreach ($runOnceKey in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce")) {
        Remove-ItemProperty -Path $runOnceKey -Name $setupTaskName, "VelvetSetup" -ErrorAction SilentlyContinue
    }

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
    Write-Host "Setup complete; initiating system reboot." -ForegroundColor Cyan
    Write-Diagnostic "Setup complete; initiating system reboot." Cyan
    & shutdown.exe /r /t 0 /c "Velvet setup complete. Rebooting system..."
} catch {
    Write-Host "[FATAL] Unhandled setup error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Diagnostic "[FATAL] Unhandled setup error: $($_.Exception.Message)" Red
    throw
} finally {
    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    if ($mutex -and $createdNew) {
        try { $mutex.ReleaseMutex() } catch {}
        $mutex.Dispose()
    }
}

exit 0
