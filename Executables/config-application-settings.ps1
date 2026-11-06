# =============================================================================
# Velvet - Installed Application Settings
# Applies settings that belong to software installed by install-packages.ps1.
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-application-settings' 'Starting installed application settings.'

$pcManagerPaths = @(
    'HKCU:\Software\Microsoft\PCManager',
    'HKLM:\SOFTWARE\Microsoft\PCManager'
)

foreach ($pcManagerPath in $pcManagerPaths) {
    Write-SetupProgress 'config-application-settings' "Applying PC Manager settings at $pcManagerPath."
    New-Item -Path $pcManagerPath,
        "$pcManagerPath\PopupManagement\Bandizip",
        "$pcManagerPath\PopupManagement\Bandizip.exe",
        "$pcManagerPath\PopupManagement\Apps\Bandizip" -Force | Out-Null

    Set-ItemProperty -Path $pcManagerPath -Name 'EnablePopupBlock' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $pcManagerPath -Name 'PopupManagement' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $pcManagerPath -Name 'BlockPopups' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $pcManagerPath -Name 'EnablePopupManagement' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $pcManagerPath -Name 'AutoBlockPopup' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $pcManagerPath -Name 'InterceptPopup' -Value 1 -Type DWord -Force

    $popupPath = "$pcManagerPath\PopupManagement"
    Set-ItemProperty -Path $popupPath -Name 'Enabled' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $popupPath -Name 'Bandizip' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $popupPath -Name 'Bandizip.exe' -Value 1 -Type DWord -Force

    foreach ($blockedPath in @(
        "$pcManagerPath\PopupManagement\Bandizip",
        "$pcManagerPath\PopupManagement\Bandizip.exe",
        "$pcManagerPath\PopupManagement\Apps\Bandizip"
    )) {
        Set-ItemProperty -Path $blockedPath -Name 'Blocked' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $blockedPath -Name 'Enabled' -Value 1 -Type DWord -Force
    }

    Set-ItemProperty -Path "$pcManagerPath\PopupManagement\Bandizip" -Name 'State' -Value 1 -Type DWord -Force
}

if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}

$userSids = Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue | Where-Object {
    $_.PSChildName -like 'S-1-5-21-*' -and $_.PSChildName -notlike '*_Classes'
} | Select-Object -ExpandProperty PSChildName -Unique

foreach ($sid in $userSids) {
    Write-SetupProgress 'config-application-settings' "Applying settings to loaded user hive $sid."
    $base = "HKU:\$sid\Software\Microsoft\PCManager"
    New-Item -Path $base, "$base\PopupManagement\Bandizip" -Force | Out-Null
    Set-ItemProperty -Path $base -Name 'EnablePopupBlock' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $base -Name 'PopupManagement' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $base -Name 'BlockPopups' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "$base\PopupManagement" -Name 'Enabled' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "$base\PopupManagement" -Name 'Bandizip' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "$base\PopupManagement\Bandizip" -Name 'Blocked' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "$base\PopupManagement\Bandizip" -Name 'Enabled' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path "$base\PopupManagement\Bandizip" -Name 'State' -Value 1 -Type DWord -Force
}

Write-Host '        [ OK ] Installed application settings configured.' -ForegroundColor Green
Write-SetupProgress 'config-application-settings' 'Completed successfully.'
exit 0
