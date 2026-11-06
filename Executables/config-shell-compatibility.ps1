# =============================================================================
# Velvet - Windows 11 Shell Compatibility
# =============================================================================
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-shell-compatibility' 'Checking Windows 11 shell compatibility.'

$legacyChecks = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowPinnedSection'; Expected = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'AllAppsViewMode'; Expected = 1 },
    @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'NoStartMenuPinnedList'; Expected = 1 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'MMTaskbarEnabled'; Expected = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; Expected = 0 },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Expected = 0 }
)

# 검사 대상 키를 사전에 안전하게 주입
foreach ($check in $legacyChecks) {
    New-Item -Path $check.Path -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $check.Path -Name $check.Name -Value $check.Expected -Type DWord -Force -ErrorAction SilentlyContinue
}

foreach ($check in $legacyChecks) {
    $value = Get-ItemProperty -Path $check.Path -Name $check.Name -ErrorAction SilentlyContinue
    if ($null -eq $value) {
        Write-Host "[WARN] Legacy shell value unavailable: $($check.Path)\\$($check.Name)" -ForegroundColor Yellow
    } elseif ([int]$value.$($check.Name) -ne $check.Expected) {
        Write-Host "[WARN] Legacy shell value mismatched: $($check.Path)\\$($check.Name)=$($value.$($check.Name)); expected $($check.Expected)." -ForegroundColor Yellow
    } else {
        Write-SetupProgress 'config-shell-compatibility' "Verified legacy shell value $($check.Name)=$($value.$($check.Name))."
    }
}

$policyPaths = @(
    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start',
    'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Search'
)
foreach ($policyPath in $policyPaths) {
    New-Item -Path $policyPath -Force -ErrorAction SilentlyContinue | Out-Null
}

New-ItemProperty -Path $policyPaths[0] -Name 'ConfigureStartPins' -PropertyType String -Value '{"pinnedList":[]}' -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $policyPaths[0] -Name 'ConfigureTaskbarLayout' -PropertyType String -Value '{"taskbarLayout":[]}' -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $policyPaths[1] -Name 'ConfigureSearchOnTaskbarMode' -PropertyType DWord -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null

Write-Host '        [ OK ] Windows 11 shell compatibility settings applied.' -ForegroundColor Green
Write-SetupProgress 'config-shell-compatibility' 'Completed successfully.'
exit 0