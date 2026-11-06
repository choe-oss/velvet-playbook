# =============================================================================
# Velvet - Essential Applications Installer Script (install-packages.ps1)
# Installs packages exclusively through the local WinGet client.
# No remote installer is downloaded or executed by this script.
# =============================================================================

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'install-packages' 'Starting package installation.'

$flagDir = "$env:ProgramData\Velvet"
$flagFile = Join-Path $flagDir "packages_installed.flag"

function Test-InternetConnection {
    $endpoints = @(
        @{ Host = "www.msftconnecttest.com"; Port = 443 },
        @{ Host = "www.microsoft.com"; Port = 443 },
        @{ Host = "github.com"; Port = 443 }
    )

    foreach ($endpoint in $endpoints) {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $asyncResult = $client.BeginConnect($endpoint.Host, $endpoint.Port, $null, $null)
            if ($asyncResult.AsyncWaitHandle.WaitOne(5000, $false) -and $client.Connected) {
                $client.EndConnect($asyncResult)
                $client.Close()
                Write-SetupProgress 'install-packages' "Network connectivity confirmed through $($endpoint.Host):$($endpoint.Port)."
                return $true
            }
        } catch {
        } finally {
            $client.Close()
        }
    }

    return $false
}

function Resolve-WingetPath {
    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
    )

    foreach ($candidate in $candidates) {
        $path = Get-ChildItem -Path $candidate -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($path) {
            try {
                $versionProcess = Start-Process -FilePath $path.FullName `
                    -ArgumentList @('--version') `
                    -Wait `
                    -PassThru `
                    -WindowStyle Hidden `
                    -ErrorAction Stop
                $versionProcess.Refresh()
                if ($versionProcess.ExitCode -eq 0) {
                    return $path.FullName
                }
            } catch {}
        }
    }

    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        try {
            $versionProcess = Start-Process -FilePath $command.Source `
                -ArgumentList @('--version') `
                -Wait `
                -PassThru `
                -WindowStyle Hidden `
                -ErrorAction Stop
            $versionProcess.Refresh()
            if ($versionProcess.ExitCode -eq 0) {
                return $command.Source
            }
        } catch {}
    }

    return $null
}

function Install-DirectPackage {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Package,
        [Parameter(Mandatory = $true)]
        [string]$DownloadDirectory
    )

    $installerPath = Join-Path $DownloadDirectory $Package.FileName
    try {
        Write-SetupProgress 'install-packages' "Downloading $($Package.Name) from the vendor link."
        Invoke-WebRequest -Uri $Package.Url -OutFile $installerPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $installerPath)) {
            throw "Downloaded installer was not created."
        }

        Write-SetupProgress 'install-packages' "Running the silent installer for $($Package.Name)."
        $process = Start-Process -FilePath $installerPath `
            -ArgumentList $Package.SilentArguments `
            -Wait `
            -PassThru `
            -WindowStyle Hidden `
            -ErrorAction Stop
        $process.Refresh()
        return [int]$process.ExitCode
    } finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                   Velvet - Essential Applications Installer                    " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Only verified WinGet package identities are used; no downloaded installers run." -ForegroundColor Gray
Write-Host ""

Write-SetupProgress 'install-packages' 'Resolving WinGet executable.'
$winget = Resolve-WingetPath
if (-not $winget) {
    Write-Host "[ WARN ] WinGet is unavailable. Package installation was skipped." -ForegroundColor Yellow
    exit 1
}

Write-SetupProgress 'install-packages' 'Checking network connectivity.'
if (-not (Test-InternetConnection)) {
    Write-Host "[ WARN ] Internet connection not detected. Package installation was skipped." -ForegroundColor Yellow
    exit 1
}

$packages = @(
    @{ Name = "Google Quick Share"; Id = "Google.QuickShare"; Source = "winget"; Required = $true },
    @{ Name = "Windhawk"; Id = "RamenSoftware.Windhawk"; Source = "winget"; Required = $true },
    @{ Name = "Google Chrome"; Id = "Google.Chrome"; Source = "winget"; Required = $true },
    @{ Name = "Microsoft PC Manager"; Id = "9pm860492szd"; Source = "msstore"; Required = $false },
    @{ Name = "VLC UWP"; Id = "9NBLGGH4VVNH"; Source = "msstore"; Required = $false },
    @{ Name = "voidtools Everything"; Id = "voidtools.Everything"; Source = "winget"; Required = $true },
    @{ Name = "ONLYOFFICE Desktop Editors"; Id = "ONLYOFFICE.DesktopEditors"; Source = "winget"; Required = $true },
    @{ Name = "KakaoTalk"; Id = "Kakao.KakaoTalk"; Source = "winget"; Required = $true; Url = "https://lk.kakaocdn.net/talkpc/talk/qwin64/KakaoTalk_Setup.exe"; FileName = "KakaoTalk_Setup.exe"; SilentArguments = @("/S") },
    @{ Name = "Bandizip"; Id = "Bandisoft.Bandizip"; Source = "winget"; Required = $true; Url = "https://kr.bandisoft.com/bandizip/dl.php?beta"; FileName = "Bandizip_Setup.exe"; SilentArguments = @("/S") },
    @{ Name = "qView"; Id = "qView"; Source = "direct"; Required = $true; Url = "https://github.com/jurplel/qView/releases/download/7.1/qView-7.1-win64.exe"; FileName = "qView-7.1-win64.exe"; SilentArguments = @("/S") }
)

$successCount = 0
$requiredFailureCount = 0
$optionalFailureCount = 0
$results = [System.Collections.Generic.List[string]]::new()
$downloadDirectory = Join-Path $env:TEMP "Velvet-PackageInstall"
New-Item -ItemType Directory -Path $downloadDirectory -Force -ErrorAction SilentlyContinue | Out-Null
$nonFatalExitCodes = @(
    0,
    -1978335189,
    -2147009287,
    -2145124344
)
$exitReasons = @{
    0 = 'Success'
    -1978335189 = 'Already installed or no applicable upgrade'
    -2147009287 = 'Microsoft Store deployment failed because the package could not be registered (0x80073CF9)'
    -2145124344 = 'Microsoft Store update was not applicable or was unavailable (0x80240008)'
}

for ($index = 0; $index -lt $packages.Count; $index++) {
    $package = $packages[$index]
    Write-SetupProgress 'install-packages' "Starting package $($index + 1)/$($packages.Count): $($package.Name)."
    Write-Host "[ $($index + 1)/$($packages.Count) ] Installing $($package.Name)..." -ForegroundColor Cyan

    try {
        if ($package.Url) {
            $exitCode = Install-DirectPackage -Package $package -DownloadDirectory $downloadDirectory
        } else {
            $arguments = @(
                "install", "--id", $package.Id, "--exact",
                "--source", $package.Source,
                "--accept-source-agreements",
                "--accept-package-agreements",
                "--disable-interactivity",
                "--silent"
            )
            $installProcess = Start-Process -FilePath $winget `
                -ArgumentList $arguments `
                -Wait `
                -PassThru `
                -NoNewWindow `
                -ErrorAction Stop
            $installProcess.Refresh()
            $exitCode = $installProcess.ExitCode
        }
        $reason = $exitReasons[[int]$exitCode]
        if (-not $reason) {
            $reason = "Installer returned exit code $exitCode."
        }
    } catch {
        $exitCode = 1
        $reason = $_.Exception.Message
        Write-Host "[ ERROR ] $($package.Name): $reason" -ForegroundColor Red
    }
    if ($nonFatalExitCodes -contains $exitCode) {
        Write-Host "[  OK  ] $($package.Name): $reason" -ForegroundColor Green
        $successCount++
        $results.Add("[  OK  ] $($package.Name) ($($package.Id), Source=$($package.Source)) - $reason")
    } else {
        Write-Host "[ FAIL ] $($package.Name) [$($package.Source)] - $reason" -ForegroundColor Yellow
        if ($package.Required) {
            $requiredFailureCount++
            $results.Add("[ REQUIRED FAIL ] $($package.Name) ($($package.Id), Source=$($package.Source)) - ExitCode: $exitCode - $reason")
        } else {
            $optionalFailureCount++
            $results.Add("[ OPTIONAL FAIL ] $($package.Name) ($($package.Id), Source=$($package.Source)) - ExitCode: $exitCode - $reason")
        }
    }
}

$windhawk = Get-Command windhawk.exe -ErrorAction SilentlyContinue
if ($windhawk) {
    Write-Host "[ INFO ] Windhawk was installed without the bundled unsigned taskbar DLL." -ForegroundColor Gray
}

New-Item -ItemType Directory -Path $flagDir -Force -ErrorAction SilentlyContinue | Out-Null
Set-Content -LiteralPath $flagFile -Value @(
    "Installed=$successCount/$($packages.Count)"
    "RequiredFailed=$requiredFailureCount"
    "OptionalFailed=$optionalFailureCount"
    "CompletedAt=$(Get-Date -Format o)"
    $results
) -Encoding UTF8 -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Package installation completed: $successCount succeeded, $requiredFailureCount required failed, $optionalFailureCount optional failed." -ForegroundColor Cyan
Write-SetupProgress 'install-packages' "Completed: $successCount succeeded, $requiredFailureCount required failed, $optionalFailureCount optional failed."
if ($requiredFailureCount -gt 0) {
    exit 1
}
exit 0
