# =============================================================================
# Velvet - Optional Features and Capabilities Configuration (config-features.ps1)
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "Configuring Windows Optional Features and Capabilities..." -ForegroundColor Cyan

# 1. Target Capability Patterns to Remove (Includes IE Mode, WMP Legacy, System Notepad, Extended Wallpapers/Themes)
$targetCapabilityPatterns = @(
    "Browser.InternetExplorer*",
    "Media.WindowsMediaPlayer*",
    "Microsoft.Windows.Notepad.System*",
    "Microsoft.Wallpapers.Extended*",
    "App.StepsRecorder*",
    "MathRecognizer*",
    "Microsoft.Windows.WordPad*",
    "OpenSSH.Client*",
    "Print.Management.Console*",
    "App.Support.QuickAssist*",
    "Microsoft.Windows.PowerShell.ISE*",
    "Print.Fax.Scan*",
    "OneCoreUAP.OneSync*",
    "Hello.Face*",
    "Language.Handwriting~~~ko-KR*",
    "Language.OCR~~~ko-KR*",
    "Language.Speech~~~ko-KR*",
    "Language.TextToSpeech~~~ko-KR*"
)

# Explicit exact capability IDs for direct DISM calls
$explicitCapabilities = @(
    "Browser.InternetExplorer~~~~0.0.11.0",
    "Browser.InternetExplorer~~~ko-KR~0.0.11.0",
    "Media.WindowsMediaPlayer~~~~0.0.12.0",
    "Media.WindowsMediaPlayer~~~ko-KR~0.0.12.0",
    "Microsoft.Windows.Notepad.System~~~~0.0.1.0",
    "Microsoft.Windows.Notepad.System~~~ko-KR~0.0.1.0",
    "Microsoft.Wallpapers.Extended~~~~0.0.1.0",
    "App.StepsRecorder~~~~0.0.1.0",
    "MathRecognizer~~~~0.0.1.0",
    "Microsoft.Windows.WordPad~~~~0.0.1.0",
    "OpenSSH.Client~~~~0.0.1.0",
    "Print.Management.Console~~~~0.0.1.0",
    "App.Support.QuickAssist~~~~0.0.1.0",
    "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0",
    "Print.Fax.Scan~~~~0.0.1.0",
    "OneCoreUAP.OneSync~~~~0.0.1.0",
    "Hello.Face.18967~~~~0.0.1.0",
    "Hello.Face.20134~~~~0.0.1.0",
    "Hello.Face.Migration.18967~~~~0.0.1.0"
)

# A. Dynamically query installed capabilities matching patterns
try {
    $installedCaps = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Installed' }
    if ($installedCaps) {
        foreach ($cap in $installedCaps) {
            foreach ($pattern in $targetCapabilityPatterns) {
                if ($cap.Name -like $pattern) {
                    Write-Host "        - Removing capability: $($cap.Name)" -ForegroundColor DarkGray
                    Remove-WindowsCapability -Online -Name $cap.Name -ErrorAction SilentlyContinue | Out-Null
                    & dism.exe /Online /NoRestart /Remove-Capability /CapabilityName:$($cap.Name) >$null 2>&1
                    break
                }
            }
        }
    }
} catch {}

# B. Explicit fallback removals via dism.exe
foreach ($capName in $explicitCapabilities) {
    & dism.exe /Online /NoRestart /Remove-Capability /CapabilityName:$capName >$null 2>&1
    Remove-WindowsCapability -Online -Name $capName -ErrorAction SilentlyContinue | Out-Null
}

# 2. Features to disable individually (Removed non-existent MicrosoftWindowsPowerShellV2)
$featuresToDisable = @(
    "MicrosoftWindowsPowerShellV2Root",
    "Internet-Explorer-Optional-amd64",
    "WindowsMediaPlayer",
    "MSRDC-Infrastructure",
    "Printing-Foundation-Features",
    "Printing-Foundation-InternetPrinting-Client",
    "WorkFolders-Client",
    "SmbDirect",
    "TFTP",
    "TelnetClient",
    "TIFFIFilter"
)

foreach ($feat in $featuresToDisable) {
    & dism.exe /Online /NoRestart /Disable-Feature /FeatureName:$feat >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Disable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Host "Optional features cleanup completed." -ForegroundColor Green
exit 0
