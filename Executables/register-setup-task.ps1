# =============================================================================
# Velvet - First Logon Setup Task Registration (register-setup-task.ps1)
# Registers setup.ps1 as a Task Scheduler task that runs with HighestAvailable
# privileges for BUILTIN\Administrators (S-1-5-32-544) without any UAC prompt.
# =============================================================================
$ErrorActionPreference = 'Stop'

$taskName  = 'Velvet-Setup'
$velvetDir = "$env:ProgramData\Velvet"
$setupPath = Join-Path $velvetDir 'setup.ps1'
$psExe     = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$stateKey  = 'HKLM:\SOFTWARE\Velvet\Setup'
$uacKey    = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

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

# 1. Make sure setup.ps1 is staged
if (-not (Test-Path -LiteralPath $setupPath)) {
    New-Item -ItemType Directory -Path $velvetDir -Force | Out-Null
    $localSetup = Join-Path $PSScriptRoot 'setup.ps1'
    if (Test-Path -LiteralPath $localSetup) {
        Copy-Item -LiteralPath $localSetup -Destination $setupPath -Force
    } else {
        Write-Host "[register-setup-task] setup.ps1 not found. Aborting." -ForegroundColor Red
        exit 1
    }
}

# 2. Registry state and silent admin elevation during pending setup
New-Item -Path $stateKey -Force | Out-Null
Set-ItemProperty -Path $stateKey -Name 'Pending'   -Type DWord  -Value 1 -Force
Set-ItemProperty -Path $stateKey -Name 'Completed' -Type DWord  -Value 0 -Force
Set-ItemProperty -Path $stateKey -Name 'TaskName'  -Type String -Value $taskName -Force
Set-ItemProperty -Path $stateKey -Name 'Script'    -Type String -Value $setupPath -Force

try {
    $currentConsent = (Get-ItemProperty -Path $uacKey -Name 'ConsentPromptBehaviorAdmin' -ErrorAction SilentlyContinue).ConsentPromptBehaviorAdmin
    if ($null -ne $currentConsent -and $currentConsent -ne 0) {
        Set-ItemProperty -Path $stateKey -Name 'SavedConsentPromptBehaviorAdmin' -Type DWord -Value ([int]$currentConsent) -Force
    } else {
        Set-ItemProperty -Path $stateKey -Name 'SavedConsentPromptBehaviorAdmin' -Type DWord -Value 5 -Force
    }
    Set-ItemProperty -Path $uacKey -Name 'ConsentPromptBehaviorAdmin' -Type DWord -Value 0 -Force
    Set-ItemProperty -Path $uacKey -Name 'PromptOnSecureDesktop' -Type DWord -Value 0 -Force
} catch {}

# 3. Register RunOnce trigger to invoke the elevated scheduled task at logon without UAC
$runOnceCmd = "schtasks.exe /run /tn `"$taskName`""
foreach ($runOnce in @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
)) {
    New-Item -Path $runOnce -Force -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path $runOnce -Name 'VelvetSetup' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $runOnce -Name $taskName -Type String -Value $runOnceCmd -Force -ErrorAction SilentlyContinue
}

# 4. Task definition
#    - SecurityDescriptor : Grants BA/SY Full Access (FA) and AU/IU Read+Execute (FRFX)
#                           so non-elevated user sessions can trigger `schtasks /run`
#                           for silent elevation without any UAC prompt.
#    - Principal          : BUILTIN\Administrators (S-1-5-32-544), HighestAvailable
#                           (Note: <LogonType> must be omitted for GroupId in Task XML schema)
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Velvet</Author>
    <Description>Velvet post-installation setup (first logon and silent elevation).</Description>
    <URI>\$taskName</URI>
    <SecurityDescriptor>D:(A;;FA;;;BA)(A;;FA;;;SY)(A;;FRFX;;;AU)(A;;FRFX;;;IU)</SecurityDescriptor>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
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
      <Arguments>-NoExit -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "$setupPath" -Scheduled</Arguments>
      <WorkingDirectory>$velvetDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
$xml = $xml.TrimStart()

# 5. Register task (COM Schedule.Service -> Register-ScheduledTask -> schtasks.exe)
[void](Invoke-SchtasksSafe -Arguments @('/delete', '/tn', $taskName, '/f'))
$registered = $false

try {
    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $rootFolder = $service.GetFolder('\')
    # 6 = TASK_CREATE_OR_UPDATE, 4 = TASK_LOGON_GROUP
    [void]$rootFolder.RegisterTask($taskName, $xml, 6, $null, $null, 4)
    $registered = $true
} catch {
    $registered = $false
}

if (-not $registered) {
    try {
        Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null
        $registered = $true
    } catch {
        $registered = $false
    }
}

if (-not $registered) {
    $xmlFile = Join-Path $env:TEMP 'Velvet-Setup-Task.xml'
    try {
        [System.IO.File]::WriteAllText($xmlFile, $xml, [System.Text.Encoding]::Unicode)
        $createCode = Invoke-SchtasksSafe -Arguments @('/create', '/tn', $taskName, '/xml', $xmlFile, '/f')
        if ($createCode -ne 0) {
            throw "schtasks.exe /create returned exit code $createCode"
        }
        $registered = $true
    } finally {
        Remove-Item -LiteralPath $xmlFile -Force -ErrorAction SilentlyContinue
    }
}

# 6. Verify
$queryCode = Invoke-SchtasksSafe -Arguments @('/query', '/tn', $taskName)
if ($queryCode -eq 0) {
    Write-Host "[register-setup-task] '$taskName' registered (At logon, Highest privileges, no UAC)." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[register-setup-task] Failed to register '$taskName'." -ForegroundColor Red
    exit 1
}
