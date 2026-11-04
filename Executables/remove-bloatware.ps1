# =============================================================================
# Velvet - Bloatware Removal Script (remove-bloatware.ps1)
# Removes unnecessary default apps and bloatware while protecting WinGet
# Fail-safe error suppression for non-installed apps
# =============================================================================

param (
    [ValidateSet("Edge", "OneDrive", "Teams", "Bloatware", "All")]
    [string]$Mode = "All"
)

$ErrorActionPreference = 'SilentlyContinue'

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
    'MSTeams',
    'Flipgrid'
)

$bloatwareList = @(
    # 3D & Mixed Reality
    'Microsoft.3DBuilder',
    'Microsoft.Microsoft3DViewer',
    'Microsoft.Print3D',
    'Microsoft.MixedReality.Portal',
    'MixedReality.Portal',

    # OEM Bloatware
    'AcerIncorporated.AcerCareCenterS',
    'AcerIncorporated.AcerRegistration',
    'B9ECED6F.Glidex',
    'B9ECED6F.ScreenPadMaster',
    'B9ECED6F.ASUSPCAssistant',
    'DellInc.DellDigitalDelivery',
    'DellInc.DellMobileConnect',
    'DellInc.DellSupportAssistforPCs',
    'AD2F1837.myHP',
    'AD2F1837.HPAIExperienceCenter',
    'AD2F1837.HPConnectedMusic',
    'AD2F1837.HPConnectedPhotopoweredbySnapfish',
    'AD2F1837.HPDesktopSupportUtilities',
    'AD2F1837.HPEasyClean',
    'AD2F1837.HPFileViewer',
    'AD2F1837.HPJumpStarts',
    'AD2F1837.OMENCommandCenter',
    'AD2F1837.HPPCHardwareDiagnosticsWindows',
    'AD2F1837.HPPrivacySettings',
    'AD2F1837.HPPowerManager',
    'AD2F1837.HPQuickDrop',
    'AD2F1837.HPQuickTouch',
    'AD2F1837.HPRegistration',
    'AD2F1837.HPPrinterControl',
    'AD2F1837.HPSupportAssistant',
    'AD2F1837.HPSureShieldAI',
    'AD2F1837.HPSystemInformation',
    'AD2F1837.HPWelcome',
    'AD2F1837.HPWorkWell',
    'E0469640.SmartAppearance',
    'E046963F.LenovoCompanion',
    'LenovoCompanyLimited.LenovoVantageService',
    'LGElectronics.LGMonitorApp',
    '9426MICRO-STARINTERNATION.MSICenter',
    '9426MICRO-STARINTERNATION.BusinessCenter',
    'SAMSUNGELECTRONICSCO.LTD.PENUP',
    'SAMSUNGELECTRONICSCoLtd.SamsungQuickShare',
    'SAMSUNGELECTRONICSCO.LTD.PCGallery',
    'SAMSUNGELECTRONICSCO.LTD.SamsungWelcome',
    'Sidia.LiveWallpaper',
    'SAMSUNGELECTRONICSCoLtd.MultiControl',
    'SAMSUNGELECTRONICSCO.LTD.Bixby',
    'SAMSUNGELECTRONICSCoLtd.SecondScreen',
    'SAMSUNGELECTRONICSCO.LTD.SmartThingsWindows',
    'SAMSUNGELECTRONICSCO.LTD.SamsungStudio',
    'SAMSUNGELECTRONICSCO.LTD.SamsungScreenRecording',
    'SAMSUNGELECTRONICSCoLtd.SamsungNotes',
    'SAMSUNGELECTRONICSCoLtd.SamsungFlux',

    # Third-Party & Games
    'ActiproSoftwareLLC',
    'AdobeSystemsIncorporated.AdobePhotoshopExpress',
    'Amazon.com.Amazon',
    'AmazonVideo.PrimeVideo',
    '4DF9E0F8.Netflix',
    'HULULLC.HULUPLUS',
    'SlingTV',
    'SpotifyAB.SpotifyMusic',
    'BytedancePte.Ltd.TikTok',
    'Facebook.Instagram',
    'FACEBOOK.FACEBOOK',
    'LinkedInforWindows',
    'AutodeskSketchBook',
    'CaesarsSlotsFreeCasino',
    'king.com.CandyCrushSaga',
    'king.com.CandyCrushSodaSaga',
    'king.com.BubbleWitch3Saga',
    'COOKINGFEVER',
    'CyberLinkMediaSuiteEssentials',
    'Disney.37853FC22B2CE',
    'DisneyMagicKingdoms',
    'DrawboardPDF',
    'Duolingo-LearnLanguagesforFree',
    'FarmVille2CountryEscape',
    'Flipboard',
    'HiddenCity',
    'iHeartRadio',
    'MarchofEmpires',
    'NYTCrossword',
    'OneCalendar',
    'PandoraMediaInc',
    'PhototasticCollage',
    'PicsArt-PhotoStudio',
    'PolarrPhotoEditorAcademicEdition',
    'flaregamesGmbH.RoyalRevolt',
    'TuneInRadio',
    'WinZipUniversal',
    'Asphalt8Airborne',

    # Microsoft Cloud, Office Hub & AI
    'Microsoft.Windows.AIHub',
    'Microsoft.549981C3F5F10',
    'MicrosoftCorporationII.MicrosoftFamily',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.M365Companions',
    'Microsoft.Todos',
    'Microsoft.Whiteboard',
    'Microsoft.Office.OneNote',
    'Microsoft.OutlookForWindows',
    'Microsoft.PowerAutomateDesktop',
    'Microsoft.MicrosoftPowerBIForWindows',
    'Microsoft.Office.Sway',
    'MicrosoftCorporationII.Windows365',
    'Microsoft.Clipchamp',
    'Clipchamp.Clipchamp',
    'Microsoft.PCManager',
    'Microsoft.MicrosoftPCManager',
    'Microsoft.MicrosoftJournal',

    # Microsoft Bing & News
    'Microsoft.BingSearch',
    'Microsoft.BingTranslator',
    'Microsoft.BingHealthAndFitness',
    'Microsoft.BingSports',
    'Microsoft.BingTravel',
    'Microsoft.BingFoodAndDrink',
    'Microsoft.BingFinance',
    'Microsoft.BingWeather',
    'Microsoft.BingNews',

    # Microsoft System Tools
    'Microsoft.NetworkSpeedTest',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.OneConnect',
    'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo',
    'MicrosoftCorporationII.QuickAssist',
    'Microsoft.MicrosoftStickyNotes',
    'Microsoft.WindowsAlarms',
    'Microsoft.WindowsMaps',
    'Microsoft.WindowsCamera',
    'Microsoft.Messaging',
    'Microsoft.People',
    'Microsoft.RemoteDesktop',
    'Microsoft.SkypeApp',
    'Microsoft.MicrosoftSolitaireCollection',
    'microsoft.windowscommunicationsapps',

    # Widgets, Store & Companion Hosts
    'Microsoft.WindowsStore',
    'Microsoft.Windows.DevHome',
    'MicrosoftWindows.Client.WebExperience',
    'Microsoft.WidgetsPlatformRuntime',
    'Microsoft.StartExperiencesApp',
    'Microsoft.SurfaceHub',
    'MicrosoftWindows.CrossDevice',
    'Microsoft.YourPhone',
    'XP9CXNGPPJ97XX',
    'XPFFTQ037JWMHS',
    'Microsoft.Windows.SecureAssessmentBrowser',
    'Microsoft.Windows.PeopleExperienceHost',

    # Xbox Components
    'Microsoft.GamingApp',
    'Microsoft.XboxApp',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxSpeechToTextOverlay',

    # Image Packages to Remove (Runtimes, Terminal & Edge WebView2)
    'Microsoft.WindowsTerminal',
    'Microsoft.VCLibs.14',
    'Microsoft.VCLibs.Desktop.14',
    'Microsoft.WindowsAppRuntime.2',
    'Microsoft.WindowsAppRuntime.1.8',
    'Microsoft.WindowsAppRuntime',
    'Microsoft.UI.Xaml.2.8',
    'Microsoft.UI.Xaml',
    'Microsoft.DotNet.Native.Runtime',
    'Microsoft.NET.Native.Runtime',
    'Microsoft.EdgeWebView2Runtime',
    'Microsoft.VCRedist.2015+.x64'
)

$targetPatterns = switch ($Mode) {
    "Edge"      { $edgeList }
    "OneDrive"  { $oneDriveList }
    "Teams"     { $teamsList }
    "Bloatware" { $bloatwareList }
    "All"       { $edgeList + $oneDriveList + $teamsList + $bloatwareList }
}

$protectedRegex = 'Microsoft\.DesktopAppInstaller'

# Compile pattern into a single regex for high-performance O(N) evaluation
$patternRegex = ($targetPatterns | ForEach-Object { [regex]::Escape($_) }) -join '|'
$compiledFilter = [regex]::new($patternRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

# 1. Remove installed Appx packages for current user and all users
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
    $scriptDir = $PSScriptRoot
    if (-not (Test-Path (Join-Path $scriptDir "remove-edge.ps1"))) {
        $scriptDir = "$env:ProgramData\Velvet"
    }

    $edgeScript = Join-Path $scriptDir "remove-edge.ps1"
    if (Test-Path -LiteralPath $edgeScript) {
        try {
            & $edgeScript -Mode "EdgeBrowser"
        } catch {
            Write-Host "        [ NOTE ] Edge removal pass skipped." -ForegroundColor DarkGray
        }
    }

    $oneDriveScript = Join-Path $scriptDir "remove-onedrive.ps1"
    if (Test-Path -LiteralPath $oneDriveScript) {
        try {
            & $oneDriveScript
        } catch {
            Write-Host "        [ NOTE ] OneDrive removal pass skipped." -ForegroundColor DarkGray
        }
    }
}

# 4. Uninstall WinGet/Win32 image target packages if winget is available
$imageWingetTargets = @(
    "Microsoft.VCRedist.2015+.x64",
    "Microsoft.VCLibs.14",
    "Microsoft.WindowsAppRuntime.2",
    "Microsoft.WindowsAppRuntime.1.8",
    "Microsoft.UI.Xaml.2.8",
    "Microsoft.DotNet.Native.Runtime",
    "Microsoft.EdgeWebView2Runtime",
    "Microsoft.VCLibs.Desktop.14",
    "Microsoft.WindowsTerminal"
)

$wingetExe = $null
$wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($wingetCmd -and $wingetCmd.Source -and (Test-Path -LiteralPath $wingetCmd.Source)) {
    $wingetExe = $wingetCmd.Source
}
if (-not $wingetExe) {
    $found = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($found) { $wingetExe = $found.FullName }
}

if ($wingetExe) {
    foreach ($target in $imageWingetTargets) {
        try {
            & $wingetExe uninstall --id $target --exact --silent --force --disable-interactivity 2>$null
        } catch {}
    }
}

Write-Host "        [ OK ] Bloatware package removal complete." -ForegroundColor Green
exit 0
