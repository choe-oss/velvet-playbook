# =============================================================================
# Velvet - Bloatware Removal Script (remove-bloatware.ps1)
# Targets only apps that auto-install or re-provision after first user logon
# (e.g., Edge, OneDrive, Teams, Outlook, Copilot, Store, PC Manager, DevHome),
# while general static bloatware is removed by Tasks\packages\appx.yml.
# Protects WinGet, Windows Photos, standard Paint, Notepad, Calculator, and Media Extensions.
# =============================================================================

param (
    [ValidateSet("Edge", "OneDrive", "Teams", "Bloatware", "All")]
    [string]$Mode = "All",
    [switch]$RemoveWebView
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'remove-bloatware' "Starting removal mode '$Mode'."

$edgeList = @(
    'Microsoft.MicrosoftEdge',
    'Microsoft.MicrosoftEdgeDevToolsClient',
    'Microsoft.Edge.GameAssist',
    'Microsoft.Copilot'
)

$oneDriveList = @(
    'OneDrive',
    'microsoft.microsoftskydrive'
)

$teamsList = @(
    'MicrosoftTeams',
    'MSTeams'
)

# 첫 로그온 후 사용자 프로필에 자동 설치/프로비저닝되거나 부활하는 앱 리스트만 유지
$bloatwareList = @(
    'Microsoft.OutlookForWindows',
    'Microsoft.Windows.DevHome',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.M365Companions',
    'Microsoft.Clipchamp',
    'Clipchamp.Clipchamp',
    'Microsoft.BingSearch',
    'Microsoft.BingNews',
    'Microsoft.BingWeather',
    'Microsoft.Todos',
    'Microsoft.PowerAutomateDesktop',
    'Microsoft.MicrosoftStickyNotes',
    'MicrosoftCorporationII.MicrosoftFamily',
    'MicrosoftCorporationII.QuickAssist',
    'Microsoft.YourPhone',
    'MicrosoftWindows.CrossDevice',
    'MicrosoftWindows.Client.WebExperience',
    'Microsoft.WidgetsPlatformRuntime',
    'Microsoft.StartExperiencesApp',
    'Microsoft.WindowsStore',
    'Microsoft.PCManager',
    'Microsoft.MicrosoftPCManager'
)

$targetPatterns = switch ($Mode) {
    "Edge"      { $edgeList }
    "OneDrive"  { $oneDriveList }
    "Teams"     { $teamsList }
    "Bloatware" { $bloatwareList }
    "All"       { $edgeList + $oneDriveList + $teamsList + $bloatwareList }
}

# Explicitly protect critical Windows infrastructure, frameworks, runtimes, WinGet, Photos, Paint, Notepad, Calculator, and Media Extensions
$protectedRegex = 'Microsoft\.(DesktopAppInstaller|VCLibs|UI\.Xaml|WindowsAppRuntime|NET\.Native|DotNet\.Native|VCRedist|EdgeWebView|Windows\.Photos|Paint|WindowsNotepad|WindowsCalculator|WindowsMediaExtensions|WebMediaExtensions|HEIFImageExtension|HEVCVideoExtension|VP9VideoExtensions|WebpImageExtension|RawImageExtension|MPEG2VideoExtension|AV1VideoExtension)'

# Compile pattern into a single regex for high-performance O(N) evaluation
$patternRegex = ($targetPatterns | ForEach-Object { [regex]::Escape($_) }) -join '|'
$compiledFilter = [regex]::new($patternRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

# 1. Remove installed Appx packages for current user and all users
Write-SetupProgress 'remove-bloatware' 'Scanning installed Appx packages.'
try {
    $installedPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    if ($installedPackages) {
        foreach ($app in $installedPackages) {
            try {
                if ($app.Name -match $protectedRegex) { continue }

                if ($compiledFilter.IsMatch($app.Name) -or $compiledFilter.IsMatch($app.PackageFullName)) {
                    Write-Host "        - Removing Appx: $($app.Name)" -ForegroundColor DarkGray
                    $inboxKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications\$($app.PackageFullName)"
                    if (Test-Path -LiteralPath $inboxKey) {
                        Remove-Item -Path $inboxKey -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    $eolKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife\S-1-5-18\$($app.PackageFullName)"
                    New-Item -Path $eolKey -Force -ErrorAction SilentlyContinue | Out-Null

                    Remove-AppxPackage -Package $app.PackageFullName -ErrorAction SilentlyContinue
                    Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                }
            } catch {
                # Fail-safe: Skip absent or locked package without stopping pipeline
                continue
            }
        }
    }
} catch {
    Write-Host "        [ NOTE ] Appx query pass completed with bypass." -ForegroundColor DarkGray
}

# 2. Remove provisioned Appx packages from online image
Write-SetupProgress 'remove-bloatware' 'Scanning provisioned Appx packages.'
try {
    $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    if ($provisionedPackages) {
        foreach ($prov in $provisionedPackages) {
            try {
                if ($prov.DisplayName -match $protectedRegex -or $prov.PackageName -match $protectedRegex) { continue }

                $name = if ($prov.DisplayName) { $prov.DisplayName } else { $prov.PackageName }
                if ($compiledFilter.IsMatch($name) -or $compiledFilter.IsMatch($prov.PackageName)) {
                    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null

                    if ($prov.DisplayName) {
                        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\$($prov.DisplayName)" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                    if ($prov.PackageName) {
                        $familyName = ($prov.PackageName -split '_')[0]
                        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\$familyName" -Force -ErrorAction SilentlyContinue | Out-Null
                    }
                }
            } catch {
                # Fail-safe: Skip absent or locked provisioned package
                continue
            }
        }
    }
} catch {
    Write-Host "        [ NOTE ] Provisioned query pass completed with bypass." -ForegroundColor DarkGray
}

# 3. Modularly invoke Edge and OneDrive clean removal if in All mode
if ($Mode -eq "All") {
    Write-SetupProgress 'remove-bloatware' 'Starting nested Edge and OneDrive removal.'
    $scriptDir = $PSScriptRoot
    if (-not (Test-Path (Join-Path $scriptDir "remove-edge.ps1"))) {
        $scriptDir = "$env:ProgramData\Velvet"
    }

    $edgeScript = Join-Path $scriptDir "remove-edge.ps1"
    if (Test-Path -LiteralPath $edgeScript) {
        try {
            Write-SetupProgress 'remove-bloatware' 'Invoking remove-edge.ps1.'
            & $edgeScript -Mode "EdgeBrowser"
        } catch {
            Write-Host "        [ NOTE ] Edge removal pass skipped." -ForegroundColor DarkGray
        }
        if ($RemoveWebView) {
            Write-Host "[WARN] WebView2 removal was explicitly requested; this may break Windows and third-party apps." -ForegroundColor Yellow
            try {
                & $edgeScript -Mode "WebView"
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[WARN] WebView2 removal returned exit code $LASTEXITCODE." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[WARN] WebView2 removal failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-SetupProgress 'remove-bloatware' 'Shared Edge WebView2 runtime preserved; use -RemoveWebView only with an explicit compatibility trade-off.'
        }
    }

    $oneDriveScript = Join-Path $scriptDir "remove-onedrive.ps1"
    if (Test-Path -LiteralPath $oneDriveScript) {
        try {
            Write-SetupProgress 'remove-bloatware' 'Invoking remove-onedrive.ps1.'
            & $oneDriveScript
        } catch {
            Write-Host "        [ NOTE ] OneDrive removal pass skipped." -ForegroundColor DarkGray
        }
    }
}

Write-Host "        [ OK ] Bloatware package removal complete." -ForegroundColor Green
Write-SetupProgress 'remove-bloatware' 'Completed successfully.'
exit 0
