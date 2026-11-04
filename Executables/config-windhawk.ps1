# =============================================================================
# Velvet - Windhawk Taskbar Styler Configuration (config-windhawk.ps1)
# SimplyTransparent
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Configuring Windhawk Taskbar Styler (SimplyTransparent)..." -ForegroundColor Cyan

# 1. Resolve source mod directory
$sourceDirs = @(
    (Join-Path $PSScriptRoot "Windhawk"),
    "$env:ProgramData\Velvet\Windhawk"
)

$sourceDir = $null
foreach ($dir in $sourceDirs) {
    if (Test-Path (Join-Path $dir "windows-11-taskbar-styler_1.10_940160.dll")) {
        $sourceDir = $dir
        break
    }
}

# 2. Prepare ProgramData destinations
$programData = "$env:ProgramData\Windhawk"
$modsSourceDir = Join-Path $programData "ModsSource"
$modsEngine64Dir = Join-Path $programData "Engine\Mods\64"

New-Item -ItemType Directory -Path $programData -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $modsSourceDir -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Path $modsEngine64Dir -Force -ErrorAction SilentlyContinue | Out-Null

# 3. Stage Mod files if source is available
if ($sourceDir) {
    # Resolve user profile json (kebab-case with fallback)
    $profileCandidates = @(
        (Join-Path $sourceDir "user-profile.json"),
        (Join-Path $sourceDir "userprofile.json")
    )
    $srcProfile = $profileCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    $srcCpp = Join-Path $sourceDir "windows-11-taskbar-styler.wh.cpp"
    $srcDll = Join-Path $sourceDir "windows-11-taskbar-styler_1.10_940160.dll"

    if ($srcProfile) {
        Copy-Item -LiteralPath $srcProfile -Destination (Join-Path $programData "userprofile.json") -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $srcCpp) {
        Copy-Item -LiteralPath $srcCpp -Destination (Join-Path $modsSourceDir "windows-11-taskbar-styler.wh.cpp") -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $srcDll) {
        Copy-Item -LiteralPath $srcDll -Destination (Join-Path $modsEngine64Dir "windows-11-taskbar-styler_1.10_940160.dll") -Force -ErrorAction SilentlyContinue
    }
}

# 4. Configure Registry Settings for Engine & Mod
$engineKey = "HKLM:\SOFTWARE\Windhawk\Engine"
$modKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler"
$settingsKey = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler\Settings"

New-Item -Path $engineKey -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $engineKey -Name "Warning" -Type String -Value "Don't delete this key, even if it's empty" -Force -ErrorAction SilentlyContinue

New-Item -Path $modKey -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $modKey -Name "LibraryFileName" -Type String -Value "windows-11-taskbar-styler_1.10_940160.dll" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $modKey -Name "Disabled" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $modKey -Name "Include" -Type String -Value "explorer.exe" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $modKey -Name "Exclude" -Type String -Value "" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $modKey -Name "Architecture" -Type String -Value "x86-64" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $modKey -Name "Version" -Type String -Value "1.10" -Force -ErrorAction SilentlyContinue

try {
    $nowEpoch = [int][double]::Parse((Get-Date -UFormat %s))
    Set-ItemProperty -Path $modKey -Name "SettingsChangeTime" -Type DWord -Value $nowEpoch -Force -ErrorAction SilentlyContinue
} catch {}

# Configure SimplyTransparent Theme in Settings
New-Item -Path $settingsKey -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $settingsKey -Name "theme" -Type String -Value "SimplyTransparent" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "clickThroughTaskbar" -Type DWord -Value 0 -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "xamlDiagnosticsHandling" -Type String -Value "alert" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "styleConstants[0]" -Type String -Value "" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[0].target" -Type String -Value "" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "controlStyles[0].styles[0]" -Type String -Value "" -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $settingsKey -Name "themeResourceVariables[0]" -Type String -Value "" -Force -ErrorAction SilentlyContinue

# 5. Configure Windows Autostart (Run key)
$runPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$windhawkExe = "$env:ProgramFiles\Windhawk\windhawk.exe"
$windhawkVal = "`"$windhawkExe`" -tray-only"

foreach ($rp in $runPaths) {
    if (Test-Path $rp) {
        Set-ItemProperty -Path $rp -Name "Windhawk" -Type String -Value $windhawkVal -Force -ErrorAction SilentlyContinue
    }
}

# 6. Launch or restart with -tray-only if installed
if (Test-Path -LiteralPath $windhawkExe) {
    $running = Get-Process -Name "windhawk" -ErrorAction SilentlyContinue
    if ($running) {
        Start-Process -FilePath $windhawkExe -ArgumentList "-restart -tray-only" -WindowStyle Hidden -ErrorAction SilentlyContinue
    } else {
        Start-Process -FilePath $windhawkExe -ArgumentList "-tray-only" -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
}

Write-Host "        [ OK ] Windhawk configured successfully." -ForegroundColor Green
exit 0
