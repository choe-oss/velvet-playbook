# =============================================================================
# Velvet - Disk Cleanup Script (cleaner.ps1)
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'cleaner' 'Starting disk cleanup and cache purge.'

Write-Host "Running disk cleanup and clearing temporary caches..." -ForegroundColor Cyan

$volumeCache = @{
    "Active Setup Temp Folders"      = 2
    "BranchCache"                    = 2
    "Delivery Optimization Files"    = 2
    "Device Driver Packages"         = 2
    "Downloaded Program Files"       = 2
    "Internet Cache Files"           = 2
    "Language Pack"                  = 2
    "Offline Pages Files"            = 2
    "Old ChkDsk Files"               = 2
    "Setup Log Files"                = 2
    "System error memory dump files" = 2
    "System error minidump files"    = 2
    "Temporary Setup Files"          = 2
    "Temporary Sync Files"           = 2
    "Update Cleanup"                 = 2
    "Upgrade Discarded Files"        = 2
    "User file versions"             = 2
    "Windows Defender"               = 2
    "Windows Error Reporting Files"  = 2
    "Windows Reset Log Files"        = 2
    "Windows Upgrade Log Files"      = 2
}

$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
Write-SetupProgress 'cleaner' 'Configuring Disk Cleanup volume flags.'
foreach ($item in $volumeCache.GetEnumerator()) {
    $keyPath = Join-Path $registryPath $item.Key
    if (Test-Path $keyPath) {
        New-ItemProperty -Path $keyPath -Name StateFlags1337 -Value $item.Value -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

Start-Process -FilePath "$env:SystemRoot\system32\cleanmgr.exe" -ArgumentList "/sagerun:1337" -Wait:$false
Write-SetupProgress 'cleaner' 'Started Disk Cleanup asynchronously.'

Set-WindowsReservedStorageState -State Disabled -ErrorAction SilentlyContinue

Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue | Out-Null
Stop-Service -Name "appidsvc" -Force -ErrorAction SilentlyContinue | Out-Null
Stop-Service -Name "dps" -Force -ErrorAction SilentlyContinue | Out-Null
Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue | Out-Null

$foldersToRemove = @(
    "CbsTemp",
    "Logs",
    "SoftwareDistribution\Download",
    "System32\LogFiles",
    "System32\SleepStudy",
    "SystemTemp",
    "Temp"
)

Write-SetupProgress 'cleaner' 'Removing Windows temporary folders.'
foreach ($folderName in $foldersToRemove) {
    $folderPath = Join-Path $env:SystemRoot $folderName
    if (Test-Path $folderPath) {
        Remove-Item -Path "$folderPath\*" -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
    }
}

Get-ChildItem -Path "$env:TEMP" -Exclude "AME" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-SetupProgress 'cleaner' 'Removing current-user temporary files.'

Start-ScheduledTask -TaskPath "\Microsoft\Windows\DiskCleanup\" -TaskName "SilentCleanup" -ErrorAction SilentlyContinue

Start-Service -Name "bits" -ErrorAction SilentlyContinue
Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue

Write-Host "        [ OK ] Disk cleanup completed." -ForegroundColor Green
Write-SetupProgress 'cleaner' 'Completed successfully.'
exit 0
