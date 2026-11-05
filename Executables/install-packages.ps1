# =============================================================================
# Velvet - Essential Applications Installer Script (install-packages.ps1)
# Deploys essential packages via WinGet and direct vendor downloads
# KakaoTalk/qView/Bandizip (Beta): Official direct link installers
# WinGet Packages: Microsoft PC Manager (9pm860492szd), Chrome, VLC, etc.
# Microsoft PC Manager & Bandizip pop-up block settings (Registry Priority)
# =============================================================================

param (
    [switch]$DisablePausePrompts
)

$ErrorActionPreference = 'Continue'

$flagDir = "$env:ProgramData\Velvet"
$flagFile = Join-Path $flagDir "packages_installed.flag"

function Test-InternetConnection {
    for ($i = 0; $i -lt 15; $i++) {
        try {
            $req = [System.Net.WebRequest]::Create("http://www.msftconnecttest.com/connecttest.txt")
            $req.Timeout = 3000
            $resp = $req.GetResponse()
            $resp.Close()
            return $true
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    return $false
}

function Resolve-WingetPath {
    $userAlias = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path -LiteralPath $userAlias) {
        try {
            $ver = & $userAlias --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $ver) {
                return $userAlias
            }
        } catch {}
    }

    $systemWinget = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($systemWinget) {
        try {
            $ver = & $systemWinget.FullName --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $ver) {
                return $systemWinget.FullName
            }
        } catch {}
    }

    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
        try {
            $ver = & $cmd.Source --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $ver) {
                return $cmd.Source
            }
        } catch {}
    }

    return $null
}

function Ensure-Winget {
    Write-Host "Checking WinGet package manager..." -ForegroundColor Cyan
    $winget = Resolve-WingetPath
    if ($winget) {
        Write-Host "Found functional WinGet: $winget" -ForegroundColor Green
        return $winget
    }

    Write-Host "Registering local DesktopAppInstaller package..." -ForegroundColor Yellow
    Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\AppxManifest.xml" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 |
        ForEach-Object {
            Add-AppxPackage -DisableDevelopmentMode -Register $_.FullName -ErrorAction SilentlyContinue
        }

    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $winget = Resolve-WingetPath
    if ($winget) {
        Write-Host "WinGet successfully registered: $winget" -ForegroundColor Green
        return $winget
    }

    Write-Host "Bootstrapping WinGet from official Microsoft release..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tempDir = Join-Path $env:TEMP "Velvet_WingetBootstrap"
    New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue | Out-Null
    $bundlePath = Join-Path $tempDir "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"

    try {
        & curl.exe -sL "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -o $bundlePath

        if (Test-Path -LiteralPath $bundlePath) {
            Add-AppxProvisionedPackage -Online -PackagePath $bundlePath -SkipLicense -ErrorAction SilentlyContinue | Out-Null
            Add-AppxPackage -Path $bundlePath -ErrorAction SilentlyContinue

            Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\AppxManifest.xml" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1 |
                ForEach-Object {
                    Add-AppxPackage -DisableDevelopmentMode -Register $_.FullName -ErrorAction SilentlyContinue
                }
        }
    } catch {
        Write-Host "WinGet bootstrap note: $_" -ForegroundColor Yellow
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 2
    return (Resolve-WingetPath)
}

function Update-AppInstaller {
    [CmdletBinding()]
    param ()

    Write-Host "Updating Microsoft.AppInstaller to latest version before app installation..." -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $winget = Ensure-Winget
    $updated = $false

    # 1. Attempt upgrade via existing functional WinGet CLI
    if ($winget) {
        Write-Host "Checking for Microsoft.AppInstaller updates via WinGet CLI..." -ForegroundColor Cyan
        try {
            $p = Start-Process -FilePath $winget -ArgumentList "upgrade --id Microsoft.AppInstaller --exact --accept-source-agreements --accept-package-agreements --disable-interactivity --silent --force" -Wait -PassThru -NoNewWindow
            if ($p.ExitCode -eq 0) {
                Write-Host "[  OK  ] Microsoft.AppInstaller upgraded via WinGet CLI." -ForegroundColor Green
                $updated = $true
            }
        } catch {
            Write-Host "[ NOTE ] WinGet CLI self-upgrade note: $_" -ForegroundColor DarkGray
        }
    }

    # 2. Always fetch and install latest official GitHub release if WinGet upgrade did not succeed
    if (-not $updated) {
        Write-Host "Downloading latest Microsoft.DesktopAppInstaller msixbundle from official repository..." -ForegroundColor Cyan
        $tempDir = Join-Path $env:TEMP "Velvet_AppInstallerUpdate"
        New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue | Out-Null
        $bundlePath = Join-Path $tempDir "Microsoft.DesktopAppInstaller_latest.msixbundle"

        try {
            & curl.exe -sL "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -o $bundlePath --connect-timeout 20 --retry 3
            if ((Test-Path -LiteralPath $bundlePath) -and ((Get-Item $bundlePath).Length -gt 10000000)) {
                Write-Host "Applying latest Microsoft.DesktopAppInstaller bundle to system and provisioned packages..." -ForegroundColor Cyan
                Add-AppxProvisionedPackage -Online -PackagePath $bundlePath -SkipLicense -ErrorAction SilentlyContinue | Out-Null
                Add-AppxPackage -Path $bundlePath -ForceUpdateFromAnyVersion -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
                Write-Host "[  OK  ] Latest Microsoft.DesktopAppInstaller bundle successfully installed." -ForegroundColor Green
                $updated = $true
            }
        } catch {
            Write-Host "[ NOTE ] AppInstaller bundle download/provision note: $_" -ForegroundColor DarkGray
        } finally {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # 3. Refresh registration for current user
    Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\AppxManifest.xml" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 |
        ForEach-Object {
            Add-AppxPackage -DisableDevelopmentMode -Register $_.FullName -ErrorAction SilentlyContinue
        }
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2
    $finalWinget = Resolve-WingetPath
    if ($finalWinget) {
        try {
            $ver = & $finalWinget --version 2>$null
            Write-Host "[  OK  ] Microsoft.AppInstaller ready. WinGet Version: $ver" -ForegroundColor Green
        } catch {}
    }
    return $finalWinget
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                   Velvet - Essential Applications Installer                    " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Deploy clean winget settings.json if available
$wingetSettingsSrc = Join-Path $flagDir "settings.json"
if (-not (Test-Path $wingetSettingsSrc)) { $wingetSettingsSrc = Join-Path $PSScriptRoot "settings.json" }
if (Test-Path $wingetSettingsSrc) {
    $wingetState = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState"
    New-Item -ItemType Directory -Path $wingetState -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item -LiteralPath $wingetSettingsSrc -Destination "$wingetState\settings.json" -Force -ErrorAction SilentlyContinue
}

if (-not (Test-InternetConnection)) {
    Write-Host "[ WARN ] Internet connection not detected. Skipping package installation." -ForegroundColor Yellow
    exit 0
}

# -----------------------------------------------------------------------------
# 1. Bandizip Beta Direct Link Installer (https://kr.bandisoft.com/bandizip/dl.php?beta)
# -----------------------------------------------------------------------------
function Install-BandizipBetaApp {
    $bandiExe = if (Test-Path "$env:ProgramFiles\Bandizip\Bandizip.exe") {
        "$env:ProgramFiles\Bandizip\Bandizip.exe"
    } elseif (Test-Path "${env:ProgramFiles(x86)}\Bandizip\Bandizip.exe") {
        "${env:ProgramFiles(x86)}\Bandizip\Bandizip.exe"
    } else {
        $null
    }
    if ($bandiExe) {
        Write-Host "[  OK  ] Bandizip is already installed." -ForegroundColor Green
        return 0
    }

    Write-Host "Installing Bandizip Beta via Direct Link (https://kr.bandisoft.com/bandizip/dl.php?beta)..." -ForegroundColor Cyan
    try {
        $dest = "$env:TEMP\BANDIZIP-SETUP-BETA.EXE"
        & curl.exe -LSs "https://kr.bandisoft.com/bandizip/dl.php?beta" -o $dest --connect-timeout 20 --retry 3
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 1000000)) {
            $proc = Start-Process -FilePath $dest -ArgumentList "/S" -Wait -PassThru
            Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
            if ($proc.ExitCode -eq 0 -or (Test-Path "$env:ProgramFiles\Bandizip\Bandizip.exe") -or (Test-Path "${env:ProgramFiles(x86)}\Bandizip\Bandizip.exe")) {
                Write-Host "[  OK  ] Bandizip Beta installed successfully via direct link." -ForegroundColor Green
                return 0
            }
        }
    } catch {
        Write-Host "[ WARN ] Bandizip direct install exception: $_" -ForegroundColor Yellow
    }
    return 1
}

# -----------------------------------------------------------------------------
# 2. qView Direct Link Installer (Direct 64-bit release)
# -----------------------------------------------------------------------------
function Install-qViewApp {
    $qViewExe = if (Test-Path "$env:ProgramFiles\qView\qView.exe") {
        "$env:ProgramFiles\qView\qView.exe"
    } elseif (Test-Path "${env:ProgramFiles(x86)}\qView\qView.exe") {
        "${env:ProgramFiles(x86)}\qView\qView.exe"
    } elseif (Test-Path "$env:LOCALAPPDATA\Programs\qView\qView.exe") {
        "$env:LOCALAPPDATA\Programs\qView\qView.exe"
    } else {
        $null
    }
    if ($qViewExe) {
        Write-Host "[  OK  ] qView is already installed." -ForegroundColor Green
        return 0
    }

    Write-Host "Installing qView via Direct Link (GitHub Official 64-bit release)..." -ForegroundColor Cyan
    try {
        $dest = "$env:TEMP\qView-7.1-win64.exe"
        & curl.exe -LSs "https://github.com/jurplel/qView/releases/download/7.1/qView-7.1-win64.exe" -o $dest --connect-timeout 20 --retry 3
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 1000000)) {
            $proc = Start-Process -FilePath $dest -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -Wait -PassThru
            Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
            if ($proc.ExitCode -eq 0 -or (Test-Path "$env:ProgramFiles\qView\qView.exe") -or (Test-Path "${env:ProgramFiles(x86)}\qView\qView.exe") -or (Test-Path "$env:LOCALAPPDATA\Programs\qView\qView.exe")) {
                Write-Host "[  OK  ] qView installed successfully via direct link." -ForegroundColor Green
                return 0
            }
        }
    } catch {
        Write-Host "[ WARN ] qView direct install exception: $_" -ForegroundColor Yellow
    }
    return 1
}

# -----------------------------------------------------------------------------
# 3. KakaoTalk Direct Link Installer (Standard user context)
# -----------------------------------------------------------------------------
function Install-KakaoTalkApp {
    $ktExe = if (Test-Path "$env:LOCALAPPDATA\Kakao\KakaoTalk\KakaoTalk.exe") {
        "$env:LOCALAPPDATA\Kakao\KakaoTalk\KakaoTalk.exe"
    } elseif (Test-Path "$env:ProgramFiles\Kakao\KakaoTalk\KakaoTalk.exe") {
        "$env:ProgramFiles\Kakao\KakaoTalk\KakaoTalk.exe"
    } elseif (Test-Path "${env:ProgramFiles(x86)}\Kakao\KakaoTalk\KakaoTalk.exe") {
        "${env:ProgramFiles(x86)}\Kakao\KakaoTalk\KakaoTalk.exe"
    } else {
        $null
    }
    if ($ktExe) {
        Write-Host "[  OK  ] KakaoTalk is already installed." -ForegroundColor Green
        return 0
    }

    Write-Host "Downloading 64-bit KakaoTalk installer from official CDN direct link..." -ForegroundColor Cyan
    try {
        $ktFile = "$env:TEMP\KakaoTalk_Setup.exe"
        & curl.exe -LSs "https://lk.kakaocdn.net/talkpc/talk/qwin64/KakaoTalk_Setup.exe" -o $ktFile --connect-timeout 20 --retry 3
        if ((Test-Path $ktFile) -and ((Get-Item $ktFile).Length -gt 1000000)) {
            Write-Host "Running KakaoTalk silent installer as standard user (/S)..." -ForegroundColor Cyan
            
            $oldCompat = $env:__COMPAT_LAYER
            try {
                $env:__COMPAT_LAYER = "RunAsInvoker"
                $installed = $false
                try {
                    $shell = New-Object -ComObject Shell.Application
                    $windows = $shell.Windows()
                    $explorerWindow = $windows | Where-Object { $_.Name -match "Explorer" } | Select-Object -First 1
                    if ($explorerWindow) {
                        $explorerWindow.Document.Application.ShellExecute($ktFile, "/S", "", "open", 1)
                        Start-Sleep -Seconds 5
                        for ($w = 0; $w -lt 60; $w++) {
                            if (-not (Get-Process -Name "KakaoTalk_Setup" -ErrorAction SilentlyContinue)) { break }
                            Start-Sleep -Seconds 2
                        }
                        $installed = $true
                    }
                } catch {}

                if (-not $installed) {
                    $proc = Start-Process -FilePath $ktFile -ArgumentList "/S" -Wait -PassThru
                }
            } finally {
                $env:__COMPAT_LAYER = $oldCompat
            }

            Remove-Item -LiteralPath $ktFile -Force -ErrorAction SilentlyContinue
            
            if ((Test-Path "$env:LOCALAPPDATA\Kakao\KakaoTalk\KakaoTalk.exe") -or 
                (Test-Path "$env:ProgramFiles\Kakao\KakaoTalk\KakaoTalk.exe") -or 
                (Test-Path "${env:ProgramFiles(x86)}\Kakao\KakaoTalk\KakaoTalk.exe")) {
                Write-Host "[  OK  ] KakaoTalk 64-bit installed successfully as standard user." -ForegroundColor Green
                return 0
            }
        }
    } catch {
        Write-Host "[ WARN ] KakaoTalk direct install exception: $_" -ForegroundColor Yellow
    }
    return 1
}

# -----------------------------------------------------------------------------
# 4. Microsoft PC Manager & Bandizip Pop-up Blocker Configuration (Registry Priority)
# -----------------------------------------------------------------------------
function Configure-PopupBlockers {
    Write-Host "Configuring Microsoft PC Manager Pop-up Management and Bandizip block button..." -ForegroundColor Cyan

    # 1. Microsoft PC Manager Pop-up Management Registry
    $pcmPaths = @(
        "HKCU:\Software\Microsoft\PCManager",
        "HKCU:\Software\Microsoft\PCManager\PopupManagement",
        "HKCU:\Software\Microsoft\PCManager\PopupManagement\Bandizip",
        "HKCU:\Software\Microsoft\PCManager\PopupManagement\Bandizip.exe",
        "HKCU:\Software\Microsoft\PCManager\PopupManagement\Apps\Bandizip",
        "HKLM:\SOFTWARE\Microsoft\PCManager",
        "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement",
        "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Bandizip",
        "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Bandizip.exe",
        "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Apps\Bandizip"
    )
    foreach ($path in $pcmPaths) {
        New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
    }

    # Enable Pop-up Block in PC Manager
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager" -Name "EnablePopupBlock" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager" -Name "PopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager" -Name "BlockPopups" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager" -Name "AutoBlockPopup" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager" -Name "InterceptPopup" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager" -Name "EnablePopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement" -Name "Bandizip" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement" -Name "Bandizip.exe" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement\Bandizip" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement\Bandizip" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement\Bandizip" -Name "State" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement\Bandizip.exe" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement\Bandizip.exe" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement\Apps\Bandizip" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\PCManager\PopupManagement\Apps\Bandizip" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager" -Name "EnablePopupBlock" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager" -Name "PopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager" -Name "BlockPopups" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager" -Name "EnablePopupManagement" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement" -Name "Bandizip" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement" -Name "Bandizip.exe" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Bandizip" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Bandizip" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Bandizip" -Name "State" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Bandizip.exe" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Bandizip.exe" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Apps\Bandizip" -Name "Blocked" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PCManager\PopupManagement\Apps\Bandizip" -Name "Enabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Apply to all User SIDs in HKU
    Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like 'S-1-5-21-*' -and $_.PSChildName -notlike '*_Classes' } | ForEach-Object {
        $sid = $_.PSChildName
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "EnablePopupBlock" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "PopupManagement" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager" /v "BlockPopups" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Enabled" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Bandizip" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement" /v "Bandizip.exe" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "Blocked" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "Enabled" /t REG_DWORD /d 1 /f >$null 2>&1
        reg.exe add "HKU\$sid\Software\Microsoft\PCManager\PopupManagement\Bandizip" /v "State" /t REG_DWORD /d 1 /f >$null 2>&1
    }

    Write-Host "        [ OK ] Microsoft PC Manager pop-up block settings configured for Bandizip." -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# WinGet Standard Packages (including Microsoft PC Manager: 9pm860492szd)
# -----------------------------------------------------------------------------
$packages = @(
    @{ Name = "Google Quick Share"; Id = "Google.QuickShare"; Source = "winget"; Extra = @() },
    @{ Name = "Windhawk"; Id = "RamenSoftware.Windhawk"; Source = "winget"; Extra = @() },
    @{ Name = "Google Chrome"; Id = "Google.Chrome"; Source = "winget"; Extra = @() },
    @{ Name = "Microsoft PC Manager"; Id = "9pm860492szd"; Source = "msstore"; Extra = @() },
    @{ Name = "VLC UWP"; Id = "9NBLGGH4VVNH"; Source = "msstore"; Extra = @() },
    @{ Name = "voidtools Everything"; Id = "voidtools.Everything"; Source = "winget"; Extra = @() },
    @{ Name = "ONLYOFFICE Desktop Editors"; Id = "ONLYOFFICE.DesktopEditors"; Source = "winget"; Extra = @() }
)

$wingetExe = Update-AppInstaller
$commands_run = 0
$success_count = 0
$failure_count = 0
$results = ""

foreach ($pkg in $packages) {
    Write-Host "[ $($commands_run + 1)/$($packages.Count + 3) ] Installing $($pkg.Name)..." -ForegroundColor Cyan
    $exitCode = 1

    if ($wingetExe) {
        $wingetArgs = @(
            "install",
            "--id", $pkg.Id,
            "--exact",
            "--source", $pkg.Source,
            "--accept-source-agreements",
            "--disable-interactivity",
            "--silent",
            "--accept-package-agreements",
            "--force"
        )
        if ($pkg.Extra) { $wingetArgs += $pkg.Extra }

        & $wingetExe @wingetArgs
        $exitCode = $LASTEXITCODE

        # Google Chrome MSI fallback
        if ($exitCode -ne 0 -and $exitCode -ne -1978335189 -and $pkg.Id -eq "Google.Chrome") {
            Write-Host "Direct MSI installer fallback for Google Chrome..." -ForegroundColor Yellow
            try {
                $msiFile = "$env:TEMP\googlechrome64.msi"
                & curl.exe -LSs "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" -o $msiFile --connect-timeout 15 --retry 3
                if (Test-Path $msiFile) {
                    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiFile`" /qn /norestart" -Wait -PassThru
                    if ($proc.ExitCode -eq 0 -or (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") -or (Test-Path "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe")) { $exitCode = 0 }
                    Remove-Item -LiteralPath $msiFile -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }

        # ONLYOFFICE direct installer fallback
        if ($exitCode -ne 0 -and $exitCode -ne -1978335189 -and $pkg.Id -eq "ONLYOFFICE.DesktopEditors") {
            Write-Host "Direct installer fallback for ONLYOFFICE..." -ForegroundColor Yellow
            try {
                $ooFile = "$env:TEMP\DesktopEditors_x64.exe"
                & curl.exe -LSs "https://download.onlyoffice.com/install/desktop/editors/windows/onlyoffice/DesktopEditors_x64.exe" -o $ooFile --connect-timeout 20 --retry 3
                if (Test-Path $ooFile) {
                    $proc = Start-Process -FilePath $ooFile -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru
                    if ($proc.ExitCode -eq 0 -or (Test-Path "$env:ProgramFiles\ONLYOFFICE\DesktopEditors\DesktopEditors.exe")) { $exitCode = 0 }
                    Remove-Item -LiteralPath $ooFile -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    }

    if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
        Write-Host "[  OK  ] $($pkg.Name) installed successfully." -ForegroundColor Green
        $success_count++
        $results += "[  OK  ] $($pkg.Name) ($($pkg.Id))`n"
    } else {
        Write-Host "[ FAIL ] $($pkg.Name) failed with exit code $exitCode." -ForegroundColor Red
        $failure_count++
        $results += "[ FAIL ] $($pkg.Name) ($($pkg.Id)) - ExitCode: $exitCode`n"
    }
    $commands_run++
}

# -----------------------------------------------------------------------------
# Direct link installations: Bandizip Beta, qView, and KakaoTalk
# -----------------------------------------------------------------------------
Write-Host "[ $($commands_run + 1)/$($packages.Count + 3) ] Installing Bandizip Beta via direct link..." -ForegroundColor Cyan
$bandiRes = Install-BandizipBetaApp
if ($bandiRes -eq 0) {
    $success_count++
    $results += "[  OK  ] Bandizip Beta (Direct Link)`n"
} else {
    $failure_count++
    $results += "[ FAIL ] Bandizip Beta (Direct Link)`n"
}
$commands_run++

Write-Host "[ $($commands_run + 1)/$($packages.Count + 3) ] Installing qView via direct link..." -ForegroundColor Cyan
$qvRes = Install-qViewApp
if ($qvRes -eq 0) {
    $success_count++
    $results += "[  OK  ] qView (Direct Link)`n"
} else {
    $failure_count++
    $results += "[ FAIL ] qView (Direct Link)`n"
}
$commands_run++

Write-Host "[ $($commands_run + 1)/$($packages.Count + 3) ] Installing KakaoTalk via direct link (standard user)..." -ForegroundColor Cyan
$ktRes = Install-KakaoTalkApp
if ($ktRes -eq 0) {
    $success_count++
    $results += "[  OK  ] KakaoTalk (Direct Link / User Mode)`n"
} else {
    $failure_count++
    $results += "[ FAIL ] KakaoTalk (Direct Link / User Mode)`n"
}
$commands_run++

# -----------------------------------------------------------------------------
# Configure Microsoft PC Manager Pop-up Management for Bandizip
# -----------------------------------------------------------------------------
Configure-PopupBlockers

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                       PACKAGE INSTALLATION SUMMARY                            " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Total: $commands_run | Successful: $success_count | Failed: $failure_count" -ForegroundColor White
Write-Host $results
Write-Host "================================================================================" -ForegroundColor Cyan

if ($failure_count -eq 0) {
    New-Item -ItemType Directory -Path $flagDir -Force -ErrorAction SilentlyContinue | Out-Null
    Set-Content -Path $flagFile -Value "Installed=$success_count/$commands_run at $(Get-Date -Format o)" -Encoding UTF8 -Force -ErrorAction SilentlyContinue
}

exit 0
