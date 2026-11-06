# =============================================================================
# Velvet - Windhawk Taskbar Styler Configuration
# =============================================================================
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-windhawk' 'Starting Windhawk configuration.'

Write-Host "Configuring Windhawk Taskbar Styler (SimplyTransparent)..." -ForegroundColor Cyan

$windhawkExe = Join-Path $env:ProgramFiles 'Windhawk\windhawk.exe'
if (-not (Test-Path -LiteralPath $windhawkExe)) {
    Write-Host "[ INFO ] Windhawk is not installed; skipping Windhawk configuration." -ForegroundColor Gray
    exit 0
}

$sourceDirs = @(
    (Join-Path $PSScriptRoot 'Windhawk'),
    (Join-Path $env:ProgramData 'Velvet\Windhawk')
)
$dllName = 'windows-11-taskbar-styler_1.10_940160.dll'
$sourceDir = $sourceDirs | Where-Object {
    Test-Path -LiteralPath (Join-Path $_ $dllName)
} | Select-Object -First 1

if (-not $sourceDir) {
    throw "Windhawk Taskbar Styler module was not found in the staged files."
}

$srcDll = Join-Path $sourceDir $dllName
Write-SetupProgress 'config-windhawk' 'Validating bundled Taskbar Styler DLL hash.'
$expectedHash = 'E755B075AAE140DE0379A2EC6D6C2EA6A025A84E68792C3493FA52282D0B800B'
$actualHash = (Get-FileHash -LiteralPath $srcDll -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
    throw "Windhawk Taskbar Styler module hash mismatch."
}

$windhawkData = Join-Path $env:ProgramData 'Windhawk'
Write-SetupProgress 'config-windhawk' 'Preparing Windhawk data and module directories.'
$modsSourceDir = Join-Path $windhawkData 'ModsSource'
$modsEngine64Dir = Join-Path $windhawkData 'Engine\Mods\64'
New-Item -ItemType Directory -Path $modsSourceDir -Force | Out-Null
New-Item -ItemType Directory -Path $modsEngine64Dir -Force | Out-Null

$srcProfile = @(
    (Join-Path $sourceDir 'user-profile.json'),
    (Join-Path $sourceDir 'userprofile.json')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$srcCpp = Join-Path $sourceDir 'windows-11-taskbar-styler.wh.cpp'

if ($srcProfile) {
    Write-SetupProgress 'config-windhawk' 'Deploying Windhawk profile.'
    Copy-Item -LiteralPath $srcProfile -Destination (Join-Path $windhawkData 'userprofile.json') -Force
}
if (Test-Path -LiteralPath $srcCpp) {
    Copy-Item -LiteralPath $srcCpp -Destination (Join-Path $modsSourceDir 'windows-11-taskbar-styler.wh.cpp') -Force
}
Copy-Item -LiteralPath $srcDll -Destination (Join-Path $modsEngine64Dir $dllName) -Force
Write-SetupProgress 'config-windhawk' 'Deploying Taskbar Styler source and binary.'

$engineKey = 'HKLM:\SOFTWARE\Windhawk\Engine'
Write-SetupProgress 'config-windhawk' 'Applying Windhawk registry configuration.'
$modKey = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler'
$settingsKey = "$modKey\Settings"
New-Item -Path $engineKey -Force | Out-Null
Set-ItemProperty -Path $engineKey -Name 'Warning' -Type String -Value "Don't delete this key, even if it's empty"
New-Item -Path $modKey -Force | Out-Null
Set-ItemProperty -Path $modKey -Name 'LibraryFileName' -Type String -Value $dllName
Set-ItemProperty -Path $modKey -Name 'Disabled' -Type DWord -Value 0
Set-ItemProperty -Path $modKey -Name 'Include' -Type String -Value 'explorer.exe'
Set-ItemProperty -Path $modKey -Name 'Exclude' -Type String -Value ''
Set-ItemProperty -Path $modKey -Name 'Architecture' -Type String -Value 'x86-64'
Set-ItemProperty -Path $modKey -Name 'Version' -Type String -Value '1.10'
Set-ItemProperty -Path $modKey -Name 'SettingsChangeTime' -Type DWord -Value ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())

New-Item -Path $settingsKey -Force | Out-Null
Set-ItemProperty -Path $settingsKey -Name 'theme' -Type String -Value 'SimplyTransparent'
Set-ItemProperty -Path $settingsKey -Name 'clickThroughTaskbar' -Type DWord -Value 0
Set-ItemProperty -Path $settingsKey -Name 'xamlDiagnosticsHandling' -Type String -Value 'alert'
Set-ItemProperty -Path $settingsKey -Name 'styleConstants[0]' -Type String -Value ''
Set-ItemProperty -Path $settingsKey -Name 'controlStyles[0].target' -Type String -Value ''
Set-ItemProperty -Path $settingsKey -Name 'controlStyles[0].styles[0]' -Type String -Value ''
Set-ItemProperty -Path $settingsKey -Name 'themeResourceVariables[0]' -Type String -Value ''

$runPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
)
$windhawkValue = "`"$windhawkExe`" -tray-only"
foreach ($runPath in $runPaths) {
    if (Test-Path -LiteralPath $runPath) {
        Set-ItemProperty -Path $runPath -Name 'Windhawk' -Type String -Value $windhawkValue
    }
}

$running = Get-Process -Name 'windhawk' -ErrorAction SilentlyContinue
Write-SetupProgress 'config-windhawk' 'Starting or restarting Windhawk tray process.'
if ($running) {
    Start-Process -FilePath $windhawkExe -ArgumentList '-restart -tray-only' -WindowStyle Hidden
} else {
    Start-Process -FilePath $windhawkExe -ArgumentList '-tray-only' -WindowStyle Hidden
}

Write-Host "        [ OK ] Windhawk Taskbar Styler configured successfully." -ForegroundColor Green
Write-SetupProgress 'config-windhawk' 'Completed successfully.'
exit 0
