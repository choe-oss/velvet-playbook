# =============================================================================
# Velvet - Windhawk Configuration
# The bundled unsigned taskbar DLL is intentionally not deployed.
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Configuring Windhawk without bundled binary mods..." -ForegroundColor Cyan

$windhawkExe = "$env:ProgramFiles\Windhawk\windhawk.exe"
if (-not (Test-Path -LiteralPath $windhawkExe)) {
    Write-Host "[ INFO ] Windhawk is not installed; skipping Windhawk configuration." -ForegroundColor Gray
    exit 0
}

$runPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)
$windhawkValue = "`"$windhawkExe`" -tray-only"

foreach ($runPath in $runPaths) {
    if (Test-Path -LiteralPath $runPath) {
        Set-ItemProperty -Path $runPath -Name "Windhawk" -Type String -Value $windhawkValue -Force
    }
}

$running = Get-Process -Name "windhawk" -ErrorAction SilentlyContinue
if ($running) {
    Start-Process -FilePath $windhawkExe -ArgumentList "-restart -tray-only" -WindowStyle Hidden
} else {
    Start-Process -FilePath $windhawkExe -ArgumentList "-tray-only" -WindowStyle Hidden
}

Write-Host "        [ OK ] Windhawk configured without an unsigned bundled mod." -ForegroundColor Green
exit 0
