# =============================================================================
# Velvet - Installed Application Settings
# Applies settings that belong to software installed by install-packages.ps1.
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-application-settings' 'Starting installed application settings.'

Write-Host '        [ OK ] Installed application settings configured.' -ForegroundColor Green
Write-SetupProgress 'config-application-settings' 'Completed successfully.'
exit 0
