# =============================================================================
# Velvet - Application Compatibility cleanup and policy verification
# Keeps Windows compatibility infrastructure intact while removing the targeted
# AppCompat registration/cache data and disabling optional inventory/assistance.
# =============================================================================
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-appcompat' 'Starting safe AppCompat policy and cache cleanup.'

$policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
$policyValues = @{
    DisableEngine = 1
    AITEnable = 0
    DisableUAR = 1
    DisablePCA = 1
    DisableInventory = 1
    SbEnable = 1
}

New-Item -Path $policyPath -Force -ErrorAction SilentlyContinue | Out-Null
foreach ($entry in $policyValues.GetEnumerator()) {
    New-ItemProperty -Path $policyPath -Name $entry.Key -PropertyType DWord -Value $entry.Value -Force -ErrorAction SilentlyContinue | Out-Null
    $actual = (Get-ItemProperty -Path $policyPath -Name $entry.Key -ErrorAction SilentlyContinue).$($entry.Key)
    if ($null -eq $actual -or [int]$actual -ne [int]$entry.Value) {
        Write-Host "[WARN] AppCompat policy verification failed: $($entry.Key) expected $($entry.Value), actual '$actual'." -ForegroundColor Yellow
    } else {
        Write-SetupProgress 'config-appcompat' "Verified AppCompat policy $($entry.Key)=$actual."
    }
}

# These are per-program compatibility stores, not the shared compatibility
# engine. Removing them avoids deleting system DLLs, services, or PCA binaries.
$cacheTargets = @(
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store',
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers',
    'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store',
    'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
)
foreach ($cacheTarget in $cacheTargets) {
    if (Test-Path -LiteralPath $cacheTarget) {
        try {
            $cacheProperties = (Get-Item -LiteralPath $cacheTarget -ErrorAction Stop).Property
            foreach ($cacheProperty in $cacheProperties) {
                Remove-ItemProperty -Path $cacheTarget -Name $cacheProperty -Force -ErrorAction Stop
            }
            Write-SetupProgress 'config-appcompat' "Removed targeted AppCompat cache values from $cacheTarget."
        } catch {
            Write-Host "[WARN] Could not clear AppCompat cache '$cacheTarget': $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-SetupProgress 'config-appcompat' "AppCompat cache not present: $cacheTarget."
    }
}

$programCache = Join-Path $env:ProgramData 'Microsoft\Windows\AppCompat\Programs'
if (Test-Path -LiteralPath $programCache) {
    try {
        Get-ChildItem -LiteralPath $programCache -Force -ErrorAction Stop |
            Remove-Item -Recurse -Force -ErrorAction Stop
        Write-SetupProgress 'config-appcompat' "Removed AppCompat program cache contents: $programCache."
    } catch {
        Write-Host "[WARN] Could not clear AppCompat program cache '$programCache': $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-SetupProgress 'config-appcompat' "AppCompat program cache not present: $programCache."
}

Write-Host '        [ OK ] AppCompat policies and targeted caches processed; shared compatibility infrastructure was preserved.' -ForegroundColor Green
Write-SetupProgress 'config-appcompat' 'Completed successfully.'
exit 0
