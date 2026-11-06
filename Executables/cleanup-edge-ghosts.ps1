# =============================================================================
# Velvet - Remove stale Edge recommendations and registrations
# Only removes registrations that point at Edge package/shortcut names. It does
# not remove the shared WebView2 runtime or arbitrary user files.
# =============================================================================
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'cleanup-edge-ghosts' 'Starting stale Edge registration cleanup.'

function Remove-RegistryValueIfPresent {
    param([string]$Path, [string]$Name)
    if (Test-Path -LiteralPath $Path) {
        $property = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $property) {
            Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction SilentlyContinue
            Write-SetupProgress 'cleanup-edge-ghosts' "Removed stale value $Path\$Name."
        }
    }
}

$packageRoots = @(
    'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Applications'
)
foreach ($root in $packageRoots) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match 'Microsoft\.MicrosoftEdge|MicrosoftEdge' } |
            ForEach-Object {
                Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-SetupProgress 'cleanup-edge-ghosts' "Removed stale Edge package registration $($_.PSChildName)."
            }
    }
}

$uninstallRoots = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($root in $uninstallRoots) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
            $item = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            if ($item.DisplayName -match '^(Microsoft )?Edge$' -or $item.DisplayName -match 'Microsoft Edge WebView') {
                $install = [string]$item.InstallLocation
                if (-not $install -or -not (Test-Path -LiteralPath $install)) {
                    Remove-Item -LiteralPath $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                    Write-SetupProgress 'cleanup-edge-ghosts' "Removed stale Edge uninstall registration $($_.PSChildName)."
                }
            }
        }
    }
}

$openWithRoots = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts',
    'HKCU:\Software\Classes'
)
foreach ($root in $openWithRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -in @('OpenWithList', 'OpenWithProgids') } |
        ForEach-Object {
            foreach ($valueName in @('msedge.exe', 'Microsoft Edge', 'MSEdgeHTM', 'MSEdgeMHT')) {
                Remove-RegistryValueIfPresent -Path $_.PSPath -Name $valueName
            }
        }
}

$shortcutRoots = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar",
    "$env:PUBLIC\Desktop",
    "$env:USERPROFILE\Desktop"
)
foreach ($root in $shortcutRoots) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Filter '*Edge*.lnk' -File -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

Write-Host '        [ OK ] Stale Edge recommendations and registrations processed.' -ForegroundColor Green
Write-SetupProgress 'cleanup-edge-ghosts' 'Completed successfully.'
exit 0
