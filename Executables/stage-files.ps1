# =============================================================================
# Velvet - System File Staging Script (stage-files.ps1)
# Deploys wallpapers, themes, and scripts
# Staged directly to %ProgramData%\Velvet and system theme directories
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

$velvetDir = "$env:ProgramData\Velvet"

# 1. Create target ProgramData directory
New-Item -ItemType Directory -Path $velvetDir -Force -ErrorAction SilentlyContinue | Out-Null

# 2. Stage System Wallpapers & Themes directly to Windows system locations (Running as SYSTEM/Admin)
$velvetWpDir = "$env:SystemRoot\Web\Wallpaper\Velvet"
$sysThemesDir = "$env:SystemRoot\Resources\Themes"
$defThemesDir = "C:\Users\Default\AppData\Local\Microsoft\Windows\Themes"

New-Item -ItemType Directory -Path $velvetWpDir, $sysThemesDir, $defThemesDir -Force -ErrorAction SilentlyContinue | Out-Null

$wallpapersSource = Join-Path $PSScriptRoot "Wallpapers"
if (Test-Path -LiteralPath $wallpapersSource) {
    Copy-Item -Path "$wallpapersSource\*" -Destination $velvetWpDir -Force -ErrorAction SilentlyContinue
}

$themeSource = Join-Path $PSScriptRoot "Themes\Velvet.theme"
if (Test-Path -LiteralPath $themeSource) {
    Copy-Item -LiteralPath $themeSource -Destination "$sysThemesDir\Velvet.theme" -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath $themeSource -Destination "$defThemesDir\Velvet.theme" -Force -ErrorAction SilentlyContinue
}

# 3. Helper to deploy assets to ProgramData target directory
function Deploy-Assets($targetDir) {
    if (Test-Path -LiteralPath $wallpapersSource) {
        $dest = Join-Path $targetDir "Wallpapers"
        New-Item -ItemType Directory -Path $dest -Force -ErrorAction SilentlyContinue | Out-Null
        Copy-Item -Path "$wallpapersSource\*" -Destination $dest -Force -Recurse -ErrorAction SilentlyContinue
    }

    $themesSource = Join-Path $PSScriptRoot "Themes"
    if (Test-Path -LiteralPath $themesSource) {
        $dest = Join-Path $targetDir "Themes"
        New-Item -ItemType Directory -Path $dest -Force -ErrorAction SilentlyContinue | Out-Null
        Copy-Item -Path "$themesSource\*" -Destination $dest -Force -Recurse -ErrorAction SilentlyContinue
    }

    $windhawkSource = Join-Path $PSScriptRoot "Windhawk"
    if (Test-Path -LiteralPath $windhawkSource) {
        $dest = Join-Path $targetDir "Windhawk"
        New-Item -ItemType Directory -Path $dest -Force -ErrorAction SilentlyContinue | Out-Null
        Copy-Item -Path "$windhawkSource\*" -Destination $dest -Force -Recurse -ErrorAction SilentlyContinue
    }

    $notepadSource = Join-Path $PSScriptRoot "Notepad"
    if (Test-Path -LiteralPath $notepadSource) {
        $dest = Join-Path $targetDir "Notepad"
        New-Item -ItemType Directory -Path $dest -Force -ErrorAction SilentlyContinue | Out-Null
        Copy-Item -Path "$notepadSource\*" -Destination $dest -Force -Recurse -ErrorAction SilentlyContinue
    }

    Get-ChildItem -Path $PSScriptRoot -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Force -ErrorAction SilentlyContinue
    }
}

Deploy-Assets $velvetDir

Write-Host "[stage-files] Staging completed to $velvetDir and system directories"
exit 0
