# =============================================================================
# Windows Notepad Configuration Script (config-notepad.ps1)
# Configures Notepad: Open files in new window, Disable spell check.
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

# 1. Disable TabletTip typing and spell checking
$tabletTipHives = @(
    "HKCU:\Software\Microsoft\TabletTip\1.7",
    "Registry::HKEY_USERS\AME_UserHive_Default\Software\Microsoft\TabletTip\1.7",
    "Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\TabletTip\1.7"
)

foreach ($th in $tabletTipHives) {
    if (-not (Test-Path $th)) {
        New-Item -Path $th -Force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -Path $th -Name "EnableSpellchecking" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $th -Name "EnableAutocorrection" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}

# 2. Deploy modern Notepad settings.dat
$templateDat = Join-Path $PSScriptRoot "Notepad\settings.dat"
if (-not (Test-Path -LiteralPath $templateDat)) {
    $altPath = "$env:ProgramData\Velvet\Notepad\settings.dat"
    if (Test-Path -LiteralPath $altPath) {
        $templateDat = $altPath
    }
}

if (Test-Path -LiteralPath $templateDat) {
    $currNotepadSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsNotepad_8wekyb3d8bbwe\Settings"
    New-Item -ItemType Directory -Path $currNotepadSettings -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -LiteralPath $templateDat -Destination "$currNotepadSettings\settings.dat" -Force -ErrorAction SilentlyContinue

    $defaultNotepadSettings = "$env:SystemDrive\Users\Default\AppData\Local\Packages\Microsoft.WindowsNotepad_8wekyb3d8bbwe\Settings"
    New-Item -ItemType Directory -Path $defaultNotepadSettings -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -LiteralPath $templateDat -Destination "$defaultNotepadSettings\settings.dat" -Force -ErrorAction SilentlyContinue
}

Write-Host "        [ OK ] Notepad settings applied." -ForegroundColor Green
exit 0

