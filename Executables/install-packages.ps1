# =============================================================================
# Velvet - Essential Applications Installer Script (install-packages.ps1)
# =============================================================================

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
[void](Write-SetupProgress 'install-packages' 'Starting package installation.')

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
                [void](Write-SetupProgress 'install-packages' "Network connectivity confirmed through $($endpoint.Host):$($endpoint.Port).")
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
                $versionProcess = Start-Process -FilePath $path.FullName -ArgumentList @('--version') -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
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
            $versionProcess = Start-Process -FilePath $command.Source -ArgumentList @('--version') -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
            $versionProcess.Refresh()
            if ($versionProcess.ExitCode -eq 0) {
                return $command.Source
            }
        } catch {}
    }

    return $null
}

function Write-PackageFlag {
    param([string[]]$Lines)
    New-Item -ItemType Directory -Path $flagDir -Force -ErrorAction SilentlyContinue | Out-Null
    Set-Content -LiteralPath $flagFile -Value $Lines -Encoding UTF8 -Force -ErrorAction SilentlyContinue
}

function Invoke-WingetCommand {
    param([string[]]$Arguments)
    $stdoutPath = Join-Path $env:TEMP ("Velvet-Winget-" + [guid]::NewGuid().ToString('N') + '.out')
    $stderrPath = Join-Path $env:TEMP ("Velvet-Winget-" + [guid]::NewGuid().ToString('N') + '.err')
    try {
        $process = Start-Process -FilePath $winget -ArgumentList $Arguments -Wait -PassThru `
            -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -ErrorAction Stop
        $output = @()
        if (Test-Path -LiteralPath $stdoutPath) { $output += Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $stderrPath) { $output += Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue }
        return [pscustomobject]@{
            ExitCode = [int]$process.ExitCode
            Output = @($output)
        }
    } finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-DiagnosticSummary {
    param([string[]]$Output)
    $lines = @($Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { ([string]$_).Trim() })
    if ($lines.Count -gt 6) {
        $lines = $lines | Select-Object -Last 6
    }
    return ($lines -join ' | ')
}

function Test-PackageInstalled {
    param([hashtable]$Package)
    if ($Package.Executable -and (Test-Path -LiteralPath $Package.Executable)) {
        return $true
    }
    if ($Package.Executable -and (Get-Command $Package.Executable -ErrorAction SilentlyContinue)) {
        return $true
    }
    if ($Package.AppxPatterns) {
        foreach ($pat in $Package.AppxPatterns) {
            if (Get-AppxPackage -Name $pat -AllUsers -ErrorAction SilentlyContinue) {
                return $true
            }
        }
    }
    if ($Package.Id -and $winget) {
        $listResult = Invoke-WingetCommand -Arguments @(
            'list', '--id', $Package.Id, '--exact',
            '--accept-source-agreements', '--disable-interactivity'
        )
        if ($listResult.ExitCode -eq 0 -and ($listResult.Output -match [regex]::Escape($Package.Id))) {
            return $true
        }
    }
    return $false
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
        [void](Write-SetupProgress 'install-packages' "Downloading $($Package.Name) from the vendor link.")
        [void](Invoke-WebRequest -Uri $Package.Url -OutFile $installerPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop)
        if (-not (Test-Path -LiteralPath $installerPath)) {
            throw "Downloaded installer was not created."
        }

        # 카카오톡 관리자 실행 경고창 자동 승인(Enter 키 전송) 백그라운드 워처
        $popupWatcher = $null
        if ($Package.Name -eq "KakaoTalk") {
            $popupWatcher = [powershell]::Create().AddScript({
                for ($i = 0; $i -lt 30; $i++) {
                    Start-Sleep -Milliseconds 500
                    $ws = New-Object -ComObject WScript.Shell
                    if ($ws.AppActivate('카카오톡 설치')) {
                        Start-Sleep -Milliseconds 200
                        $ws.SendKeys('{ENTER}')
                        break
                    }
                }
            })
            [void]$popupWatcher.BeginInvoke()
        }

        [void](Write-SetupProgress 'install-packages' "Running the silent installer for $($Package.Name).")
        $process = Start-Process -FilePath $installerPath `
            -ArgumentList $Package.SilentArguments `
            -Wait `
            -PassThru `
            -WindowStyle Hidden `
            -ErrorAction Stop
        $process.Refresh()

        if ($popupWatcher) {
            $popupWatcher.Dispose()
        }

        return [int]$process.ExitCode
    } finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                   Velvet - Essential Applications Installer                    " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

[void](Write-SetupProgress 'install-packages' 'Resolving WinGet executable.')
$winget = Resolve-WingetPath
if (-not $winget) {
    Write-Host "[ WARN ] WinGet is unavailable. Package installation was skipped." -ForegroundColor Yellow
    Write-PackageFlag @(
        'Installed=0'
        'RequiredFailed=1'
        'OptionalFailed=0'
        'FailureReason=WinGet executable was not found.'
        "CompletedAt=$(Get-Date -Format o)"
    )
    exit 1
}

[void](Write-SetupProgress 'install-packages' 'Checking network connectivity.')
if (-not (Test-InternetConnection)) {
    Write-Host "[ WARN ] Internet connection not detected. Package installation was skipped." -ForegroundColor Yellow
    Write-PackageFlag @(
        'Installed=0'
        'RequiredFailed=1'
        'OptionalFailed=0'
        'FailureReason=Network connectivity check failed.'
        "CompletedAt=$(Get-Date -Format o)"
    )
    exit 1
}

$packages = @(
    @{ Name = "Google Quick Share"; Id = "Google.QuickShare"; Source = "winget"; Required = $true },
    @{ Name = "Windhawk"; Id = "RamenSoftware.Windhawk"; Source = "winget"; Required = $true },
    @{ Name = "Google Chrome"; Id = "Google.Chrome"; Source = "winget"; Required = $true },
    @{ 
        Name = "Microsoft PC Manager"
        Id = "9PM860492SZD"
        Source = "msstore"
        Required = $true
        Force = $true
        Executable = "$env:ProgramFiles\Microsoft PC Manager\MSPCManager.exe"
        AppxPatterns = @("*PCManager*", "*Microsoft.PCManager*")
    },
    @{ Name = "voidtools Everything"; Id = "voidtools.Everything"; Source = "winget"; Required = $true },
    @{ Name = "ONLYOFFICE Desktop Editors"; Id = "ONLYOFFICE.DesktopEditors"; Source = "winget"; Required = $true },
    @{ Name = "KakaoTalk"; Id = "Kakao.KakaoTalk"; Source = "winget"; Required = $true; Url = "https://lk.kakaocdn.net/talkpc/talk/qwin64/KakaoTalk_Setup.exe"; FileName = "KakaoTalk_Setup.exe"; SilentArguments = @("/S") },
    @{ Name = "Bandizip"; Id = "Bandisoft.Bandizip"; Source = "winget"; Required = $true; Url = "https://kr.bandisoft.com/bandizip/dl.php?beta"; FileName = "Bandizip_Setup.exe"; SilentArguments = @("/S") }
)

$successCount = 0
$requiredFailureCount = 0
$optionalFailureCount = 0
$results = [System.Collections.Generic.List[string]]::new()
$downloadDirectory = Join-Path $env:TEMP "Velvet-PackageInstall"
New-Item -ItemType Directory -Path $downloadDirectory -Force -ErrorAction SilentlyContinue | Out-Null
$nonFatalExitCodes = @(0, -1978335189, 2316632065)
$exitReasons = @{
    0 = 'Success'
    -1978335189 = 'Already installed or no applicable upgrade'
    2316632065  = 'Already installed or no applicable upgrade'
}

for ($index = 0; $index -lt $packages.Count; $index++) {
    $package = $packages[$index]
    [void](Write-SetupProgress 'install-packages' "Starting package $($index + 1)/$($packages.Count): $($package.Name).")
    Write-Host "[ $($index + 1)/$($packages.Count) ] Installing $($package.Name)..." -ForegroundColor Cyan

    $packageDiagnostic = ''
    try {
        if ($package.Url) {
            $rawExitCode = Install-DirectPackage -Package $package -DownloadDirectory $downloadDirectory
            $exitCode = [int]$rawExitCode
        } else {
            $arguments = @(
                "install",
                "--id", $package.Id,
                "--exact",
                "--source", $package.Source,
                "--accept-source-agreements",
                "--disable-interactivity",
                "--silent",
                "--accept-package-agreements"
            )
            if ($package.Force) {
                $arguments += "--force"
            }

            $installResult = Invoke-WingetCommand -Arguments $arguments
            $exitCode = [int]$installResult.ExitCode
            $packageDiagnostic = Get-DiagnosticSummary -Output $installResult.Output
        }

        $reason = $exitReasons[$exitCode]
        if (-not $reason) {
            $reason = "Installer returned exit code $exitCode."
        }

        if ($nonFatalExitCodes -notcontains $exitCode) {
            if (Test-PackageInstalled -Package $package) {
                $exitCode = 0
                $reason = "Verified installed via file/command detection."
            }
        }
    } catch {
        $exitCode = 1
        $reason = $_.Exception.Message
        Write-Host "[ ERROR ] $($package.Name): $reason" -ForegroundColor Red
    }

    if ($packageDiagnostic) {
        $reason = "$reason Diagnostic=$packageDiagnostic"
    }

    if ($nonFatalExitCodes -contains $exitCode -or $exitCode -eq 0) {
        Write-Host "[  OK  ] $($package.Name): $reason" -ForegroundColor Green
        $successCount++
        $results.Add("[  OK  ] $($package.Name) ($($package.Id)) - $reason")
    } else {
        Write-Host "[ FAIL ] $($package.Name) - $reason" -ForegroundColor Yellow
        if ($package.Required) {
            $requiredFailureCount++
            $results.Add("[ REQUIRED FAIL ] $($package.Name) ($($package.Id)) - ExitCode: $exitCode - $reason")
        } else {
            $optionalFailureCount++
            $results.Add("[ OPTIONAL FAIL ] $($package.Name) ($($package.Id)) - ExitCode: $exitCode - $reason")
        }
    }
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
[void](Write-SetupProgress 'install-packages' "Completed: $successCount succeeded, $requiredFailureCount required failed.")
if ($requiredFailureCount -gt 0) {
    exit 1
}
exit 0