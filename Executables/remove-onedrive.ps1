# =============================================================================
# Velvet - OneDrive Removal Script (remove-onedrive.ps1)
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Disabling OneDrive and bundled artifacts..." -ForegroundColor Cyan

# 1. Stop active OneDrive processes if running
try {
    Get-Process -Name "OneDrive", "OneDriveStandaloneUpdater" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
} catch {}

# 2. Disable OneDrive file sync via GPO
try {
    & reg.exe add "HKLM\Software\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d 1 /f >$null 2>&1
} catch {}

# 3. Locate and execute uninstaller if present
$setupPaths = @(
    "$env:SystemRoot\System32\OneDriveSetup.exe",
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
)

try {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
    $users = Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue
    foreach ($user in $users) {
        try {
            if (Test-Path "HKU:\$($user.PSChildName)\Volatile Environment") {
                $regPath = "HKU:\$($user.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
                $uninstallString = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).UninstallString
                if (!([string]::IsNullOrEmpty($uninstallString))) {
                    $uninstallFilePath = [System.IO.Path]::GetDirectoryName($uninstallString)
                    $setupPaths += (Join-Path $uninstallFilePath "OneDriveSetup.exe")
                }
                Remove-ItemProperty -Path "HKU:\$($user.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path "HKU:\$($user.PSChildName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDriveSetup" -ErrorAction SilentlyContinue
                Remove-Item -Path "HKU:\$($user.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }
} catch {}

foreach ($setup in ($setupPaths | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $setup) {
        try {
            Start-Process -FilePath $setup -ArgumentList "/uninstall" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        } catch {}
    }
}

# 4. Remove system binaries if present
try {
    if (Test-Path "$env:SystemRoot\System32\OneDriveSetup.exe") {
        Remove-Item -Path "$env:SystemRoot\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue | Out-Null
    }
    if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
        Remove-Item -Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue | Out-Null
    }
} catch {}

# 5. Remove AppX Packages if present
try {
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like '*OneDrive*' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    Get-AppxPackage -AllUsers *OneDrive* -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
} catch {}

# 6. Consumer features and pre-installed app blocks
try {
    & reg.exe add "HKLM\Software\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKLM\Software\Policies\Microsoft\Windows\CloudContent" /v "DisableCloudOptimizedContent" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKLM\Software\Microsoft\Windows\CurrentVersion\Communications" /v "ConfigureChatAutoInstall" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKLM\Software\Policies\Microsoft\Windows\Device Metadata" /v "PreventDeviceMetadataFromNetwork" /t REG_DWORD /d 1 /f >$null 2>&1
    & reg.exe add "HKLM\Software\Policies\Microsoft\Edge" /v "HideFirstRunExperience" /t REG_DWORD /d 1 /f >$null 2>&1
} catch {}

# 7. Hide OneDrive from Explorer navigation pane
try {
    $oneDriveClsid = "{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    & reg.exe add "HKCR\CLSID\$oneDriveClsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
    & reg.exe add "HKCU\Software\Classes\CLSID\$oneDriveClsid" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >$null 2>&1
} catch {}

# 8. Clean residual user folders
try {
    Get-ChildItem -Path "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $oneDrivePath = Join-Path $_.FullName "AppData\Local\Microsoft\OneDrive"
        if (Test-Path -LiteralPath $oneDrivePath) {
            Remove-Item -LiteralPath $oneDrivePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} catch {}

Write-Host "OneDrive clean-up finished." -ForegroundColor Green
exit 0
