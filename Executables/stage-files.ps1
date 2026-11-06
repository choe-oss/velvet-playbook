# =============================================================================
# Velvet - System File Staging Script (stage-files.ps1)
# Deploys wallpapers, themes, and scripts
# Staged directly to %ProgramData%\Velvet and system theme directories
# =============================================================================
$ErrorActionPreference = 'Stop'

$velvetDir = "$env:ProgramData\Velvet"

function Copy-DirectoryContents {
    param (
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Force -Recurse
}

# 1. Create target ProgramData directory
New-Item -ItemType Directory -Path $velvetDir -Force | Out-Null

# 2. Stage System Wallpapers & Themes directly to Windows system locations (Running as SYSTEM/Admin)
$velvetWpDir = "$env:SystemRoot\Web\Wallpaper\Velvet"
$sysThemesDir = "$env:SystemRoot\Resources\Themes"
$defThemesDir = "C:\Users\Default\AppData\Local\Microsoft\Windows\Themes"

New-Item -ItemType Directory -Path $velvetWpDir, $sysThemesDir, $defThemesDir -Force | Out-Null

$wallpapersSource = Join-Path $PSScriptRoot "Wallpapers"
if (Test-Path -LiteralPath $wallpapersSource) {
    Copy-DirectoryContents -Source $wallpapersSource -Destination $velvetWpDir
}

$themeSource = Join-Path $PSScriptRoot "Themes\Velvet.theme"
if (Test-Path -LiteralPath $themeSource) {
    Copy-Item -LiteralPath $themeSource -Destination "$sysThemesDir\Velvet.theme" -Force
    Copy-Item -LiteralPath $themeSource -Destination "$defThemesDir\Velvet.theme" -Force
}

# 3. Helper to deploy assets to ProgramData target directory
function Deploy-Assets {
    param ([string]$TargetDir)

    if (Test-Path -LiteralPath $wallpapersSource) {
        Copy-DirectoryContents -Source $wallpapersSource -Destination (Join-Path $TargetDir "Wallpapers")
    }

    $themesSource = Join-Path $PSScriptRoot "Themes"
    if (Test-Path -LiteralPath $themesSource) {
        Copy-DirectoryContents -Source $themesSource -Destination (Join-Path $TargetDir "Themes")
    }

    $windhawkSource = Join-Path $PSScriptRoot "Windhawk"
    if (Test-Path -LiteralPath $windhawkSource) {
        Copy-DirectoryContents -Source $windhawkSource -Destination (Join-Path $TargetDir "Windhawk")
    }

    $notepadSource = Join-Path $PSScriptRoot "Notepad"
    if (Test-Path -LiteralPath $notepadSource) {
        Copy-DirectoryContents -Source $notepadSource -Destination (Join-Path $TargetDir "Notepad")
    }

    Get-ChildItem -Path $PSScriptRoot -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $TargetDir -Force
    }
}

Deploy-Assets -TargetDir $velvetDir

if (-not (Test-Path -LiteralPath (Join-Path $velvetDir 'setup.ps1'))) {
    throw "Required setup script was not staged to $velvetDir"
}

Write-Host "[stage-files] Staging completed to $velvetDir and system directories"
exit 0
