# =============================================================================
# Velvet - First Logon Setup Task Registration (register-setup-task.ps1)
# =============================================================================
$ErrorActionPreference = 'Stop'

$taskName  = 'Velvet-Setup'
$velvetDir = "$env:ProgramData\Velvet"
$setupPath = Join-Path $velvetDir 'setup.ps1'
$psExe     = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$stateKey  = 'HKLM:\SOFTWARE\Velvet\Setup'

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

# 2. Registry state
New-Item -Path $stateKey -Force | Out-Null
Set-ItemProperty -Path $stateKey -Name 'Pending'   -Type DWord  -Value 1
Set-ItemProperty -Path $stateKey -Name 'Completed' -Type DWord  -Value 0
Set-ItemProperty -Path $stateKey -Name 'TaskName'  -Type String -Value $taskName
Set-ItemProperty -Path $stateKey -Name 'Script'    -Type String -Value $setupPath

# 3. Remove legacy RunOnce entries
foreach ($runOnce in @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
)) {
    Remove-ItemProperty -Path $runOnce -Name 'Velvet-Setup', 'VelvetSetup' -ErrorAction SilentlyContinue
}

# 4. Task definition with -NoExit and refined execution properties
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Velvet</Author>
    <Description>Velvet post-installation setup (first logon).</Description>
    <URI>\$taskName</URI>
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
      <Arguments>-NoExit -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File "$setupPath"</Arguments>
      <WorkingDirectory>$velvetDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@
$xml = $xml.TrimStart()

# 5. Register
& schtasks.exe /delete /tn $taskName /f > $null 2>&1
try {
    Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null
} catch {
    $xmlFile = Join-Path $env:TEMP 'Velvet-Setup-Task.xml'
    try {
        [System.IO.File]::WriteAllText($xmlFile, $xml, [System.Text.Encoding]::Unicode)
        & schtasks.exe /create /tn $taskName /xml $xmlFile /f > $null 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "schtasks.exe returned exit code $LASTEXITCODE"
        }
    } finally {
        Remove-Item -LiteralPath $xmlFile -Force -ErrorAction SilentlyContinue
    }
}

# 6. Verify
& schtasks.exe /query /tn $taskName > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[register-setup-task] '$taskName' registered (At logon, Highest privileges)." -ForegroundColor Green
    exit 0
} else {
    Write-Host "[register-setup-task] Failed to register '$taskName'." -ForegroundColor Red
    exit 1
}