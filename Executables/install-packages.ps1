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

function Write-PackageFlag {
    param(
        [string[]]$Lines
    )
    New-Item -ItemType Directory -Path $flagDir -Force -ErrorAction SilentlyContinue | Out-Null
    Set-Content -LiteralPath $flagFile -Value $Lines -Encoding UTF8 -Force -ErrorAction SilentlyContinue
}

function Invoke-WingetCommand {
    param(
        [string[]]$Arguments
    )
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

function Test-AppxPackageInstalled {
    param(
        [string[]]$Patterns
    )
    foreach ($pattern in $Patterns) {
        $matches = @(
            Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue
            Get-AppxPackage -Name $pattern -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $pattern -or $_.PackageName -like $pattern }
        )
        if ($matches.Count -gt 0) {
            return $true
        }
    }
    return $false
}

function Test-PackageInstalled {
    param([hashtable]$Package)
    if ($Package.AppxPatterns -and (Test-AppxPackageInstalled -Patterns $Package.AppxPatterns)) {
        return $true
    }
    if ($Package.Id -and $winget) {
        $listResult = Invoke-WingetCommand -Arguments @(
            'list', '--id', $Package.Id, '--exact', '--source', $Package.Source,
            '--accept-source-agreements', '--disable-interactivity'
        )
        if ($listResult.ExitCode -eq 0 -and ($listResult.Output -match [regex]::Escape($Package.Id))) {
            return $true
        }
    }
    if ($Package.Executable -and (Get-Command $Package.Executable -ErrorAction SilentlyContinue)) {
        return $true
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
    Write-PackageFlag @(
        'Installed=0'
        'RequiredFailed=1'
        'OptionalFailed=0'
        'FailureReason=WinGet executable was not found or could not run --version.'
        "CompletedAt=$(Get-Date -Format o)"
    )
    exit 1
}

Write-SetupProgress 'install-packages' 'Checking network connectivity.'
if (-not (Test-InternetConnection)) {
    Write-Host "[ WARN ] Internet connection not detected. Package installation was skipped." -ForegroundColor Yellow
    Write-PackageFlag @(
        'Installed=0'
        'RequiredFailed=1'
        'OptionalFailed=0'
        'FailureReason=TCP connectivity checks to Microsoft/GitHub endpoints failed.'
        "CompletedAt=$(Get-Date -Format o)"
    )
    exit 1
}

Write-SetupProgress 'install-packages' 'Inspecting WinGet sources before installation.'
$sourceResult = Invoke-WingetCommand -Arguments @('source', 'list', '--disable-interactivity')
$sourceList = $sourceResult.Output
$sourceExitCode = $sourceResult.ExitCode
if ($sourceExitCode -ne 0) {
    Write-Host "[ WARN ] WinGet source list failed with exit code $sourceExitCode." -ForegroundColor Yellow
    Write-PackageFlag @(
        'Installed=0'
        'RequiredFailed=1'
        'OptionalFailed=0'
        "FailureReason=WinGet source list failed with exit code $sourceExitCode."
        ($sourceList | ForEach-Object { "SourceDiagnostic=$_" })
        "CompletedAt=$(Get-Date -Format o)"
    )
    exit 1
}
Write-SetupProgress 'install-packages' ("WinGet source diagnostics: " + (Get-DiagnosticSummary -Output $sourceList))

$packages = @(
    @{ Name = "Google Quick Share"; Id = "Google.QuickShare"; Source = "winget"; Required = $true },
    @{ Name = "Windhawk"; Id = "RamenSoftware.Windhawk"; Source = "winget"; Required = $true },
    @{ Name = "Google Chrome"; Id = "Google.Chrome"; Source = "winget"; Required = $true },
    @{ Name = "Microsoft PC Manager"; Id = "9pm860492szd"; Source = "msstore"; Required = $true; AppxPatterns = @("*PCManager*", "Microsoft.PCManager*") },
    @{ Name = "VLC UWP"; Id = "9NBLGGH4VVNH"; Source = "msstore"; Required = $true; AppxPatterns = @("*VLC*", "VideoLAN.VLC*") },
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

    $packageDiagnostic = ''
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
            if ($package.Source -eq 'msstore') {
                $arguments = $arguments | Where-Object { $_ -ne '--silent' }
            }
            $installResult = Invoke-WingetCommand -Arguments $arguments
            $exitCode = $installResult.ExitCode
            $packageDiagnostic = Get-DiagnosticSummary -Output $installResult.Output
        }
        $reason = $exitReasons[[int]$exitCode]
        if (-not $reason) {
            $reason = "Installer returned exit code $exitCode."
        }
        if ($nonFatalExitCodes -contains $exitCode -and $package.AppxPatterns -and -not (Test-PackageInstalled -Package $package)) {
            $exitCode = 1
            $reason = "WinGet returned '$reason', but installation verification found no installed/provisioned package for Store ID '$($package.Id)' (patterns: $($package.AppxPatterns -join ', '))."
        }
    } catch {
        $exitCode = 1
        $reason = $_.Exception.Message
        Write-Host "[ ERROR ] $($package.Name): $reason" -ForegroundColor Red
    }
    if ($packageDiagnostic) {
        $reason = "$reason Diagnostic=$packageDiagnostic"
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
    "RequiredPackages=$(@($packages | Where-Object { $_.Required }).Count)"
    "RequiredFailurePolicy=Any required failure exits setup with code 1"
    "SourceDiagnostics=$(Get-DiagnosticSummary -Output $sourceList)"
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
