# =============================================================================
# Velvet - Start Menu Layout Configuration Script (config-startmenu.ps1)
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

Get-Process -Name "StartMenuExperienceHost" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$defaultLocalApp = "$env:SystemDrive\Users\Default\AppData\Local"
$defaultShell = "$defaultLocalApp\Microsoft\Windows\Shell"
New-Item -ItemType Directory -Path $defaultShell -Force -ErrorAction SilentlyContinue | Out-Null

# Resolve kebab-case source files with fallback
$xmlCandidates = @(
    (Join-Path $PSScriptRoot "layout-modification.xml"),
    "$env:ProgramData\Velvet\layout-modification.xml",
    (Join-Path $PSScriptRoot "LayoutModification.xml")
)
$layoutXml = $xmlCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$jsonCandidates = @(
    (Join-Path $PSScriptRoot "layout-modification.json"),
    "$env:ProgramData\Velvet\layout-modification.json",
    (Join-Path $PSScriptRoot "LayoutModification.json")
)
$layoutJson = $jsonCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

# Deploy to Default user shell (Windows target naming: LayoutModification.xml/json)
if ($layoutXml) {
    Copy-Item -LiteralPath $layoutXml -Destination "$defaultShell\LayoutModification.xml" -Force -ErrorAction SilentlyContinue
}
if ($layoutJson) {
    Copy-Item -LiteralPath $layoutJson -Destination "$defaultShell\LayoutModification.json" -Force -ErrorAction SilentlyContinue
}

# Deploy to Current user shell
$curLocalApp = [Environment]::GetFolderPath('LocalApplicationData')
if ($curLocalApp -and (Test-Path -LiteralPath $curLocalApp)) {
    $curShell = "$curLocalApp\Microsoft\Windows\Shell"
    New-Item -ItemType Directory -Path $curShell -Force -ErrorAction SilentlyContinue | Out-Null
    if ($layoutXml) {
        Copy-Item -LiteralPath $layoutXml -Destination "$curShell\LayoutModification.xml" -Force -ErrorAction SilentlyContinue
    }
    if ($layoutJson) {
        Copy-Item -LiteralPath $layoutJson -Destination "$curShell\LayoutModification.json" -Force -ErrorAction SilentlyContinue
    }

    # Clear cached start tiles binaries
    $curPackages = Get-ChildItem -Path "$curLocalApp\Packages" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Microsoft.Windows.StartMenuExperienceHost" }
    foreach ($pkg in $curPackages) {
        $bins = Get-ChildItem -Path "$($pkg.FullName)\LocalState" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "start*.bin" }
        foreach ($bin in $bins.FullName) {
            Remove-Item -Path $bin -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "        [ OK ] Start menu layout configured." -ForegroundColor Green
exit 0
