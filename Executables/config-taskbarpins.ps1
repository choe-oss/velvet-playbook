# =============================================================================
# Velvet - Taskbar Pinning Configuration (config-taskbarpins.ps1)
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

function New-Shortcut {
    param ($Source, $Destination)
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($Destination)
        $Shortcut.TargetPath = $Source
        $Shortcut.Save()
    } catch {}
}

$programFiles = [Environment]::GetFolderPath('ProgramFiles')
$chromePath = "$programFiles\Google\Chrome\Application\chrome.exe"
$explorerPath = "$([Environment]::GetFolderPath('Windows'))\explorer.exe"

$hasChrome = Test-Path -LiteralPath $chromePath

$tmp = New-Item (Join-Path -Path $([System.IO.Path]::GetTempPath()) -ChildPath $([System.Guid]::NewGuid())) -ItemType Directory -Force
New-Shortcut -Source $explorerPath -Destination "$tmp\File Explorer.lnk"
if ($hasChrome) {
    New-Shortcut -Source $chromePath -Destination "$tmp\Google Chrome.lnk"
}

$taskBarLocation = 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'

# Copy shortcuts to current user
$appData = [Environment]::GetFolderPath('ApplicationData')
if ($appData -and (Test-Path $appData)) {
    $userTaskbar = Join-Path -Path $appData -ChildPath $taskBarLocation
    New-Item -ItemType Directory -Path $userTaskbar -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -Path "$tmp\*" -Destination $userTaskbar -Force -ErrorAction SilentlyContinue
}

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "        [ OK ] Taskbar pins configured." -ForegroundColor Green
exit 0


