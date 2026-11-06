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
    try {
        $response = Invoke-WebRequest -Uri "https://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 5
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
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
                & $path.FullName --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    return $path.FullName
                }
            } catch {}
        }
    }

    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        try {
            & $command.Source --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                return $command.Source
            }
        } catch {}
    }

    return $null
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
    @{ Name = "Google Quick Share"; Id = "Google.QuickShare"; Source = "winget" },
    @{ Name = "Windhawk"; Id = "RamenSoftware.Windhawk"; Source = "winget" },
    @{ Name = "Google Chrome"; Id = "Google.Chrome"; Source = "winget" },
    @{ Name = "Microsoft PC Manager"; Id = "9pm860492szd"; Source = "msstore" },
    @{ Name = "VLC UWP"; Id = "9NBLGGH4VVNH"; Source = "msstore" },
    @{ Name = "voidtools Everything"; Id = "voidtools.Everything"; Source = "winget" },
    @{ Name = "ONLYOFFICE Desktop Editors"; Id = "ONLYOFFICE.DesktopEditors"; Source = "winget" }
)

$successCount = 0
$failureCount = 0
$results = [System.Collections.Generic.List[string]]::new()

for ($index = 0; $index -lt $packages.Count; $index++) {
    $package = $packages[$index]
    Write-SetupProgress 'install-packages' "Starting package $($index + 1)/$($packages.Count): $($package.Name)."
    Write-Host "[ $($index + 1)/$($packages.Count) ] Installing $($package.Name)..." -ForegroundColor Cyan

    $arguments = @(
        "install", "--id", $package.Id, "--exact",
        "--source", $package.Source,
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--disable-interactivity",
        "--silent"
    )

    & $winget @arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
        Write-Host "[  OK  ] $($package.Name) installed or already present." -ForegroundColor Green
        $successCount++
        $results.Add("[  OK  ] $($package.Name) ($($package.Id))")
    } else {
        Write-Host "[ FAIL ] $($package.Name) failed with exit code $exitCode." -ForegroundColor Yellow
        $failureCount++
        $results.Add("[ FAIL ] $($package.Name) ($($package.Id)) - ExitCode: $exitCode")
    }
}

$windhawk = Get-Command windhawk.exe -ErrorAction SilentlyContinue
if ($windhawk) {
    Write-Host "[ INFO ] Windhawk was installed without the bundled unsigned taskbar DLL." -ForegroundColor Gray
}

New-Item -ItemType Directory -Path $flagDir -Force -ErrorAction SilentlyContinue | Out-Null
Set-Content -LiteralPath $flagFile -Value @(
    "Installed=$successCount/$($packages.Count)"
    "Failed=$failureCount"
    "CompletedAt=$(Get-Date -Format o)"
    $results
) -Encoding UTF8 -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Package installation completed: $successCount succeeded, $failureCount failed." -ForegroundColor Cyan
Write-SetupProgress 'install-packages' "Completed: $successCount succeeded, $failureCount failed."
if ($failureCount -gt 0) {
    exit 1
}
exit 0
