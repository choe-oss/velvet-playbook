# =============================================================================
# Velvet - Theme and Wallpapers Configuration Script (config-theme.ps1)
# Dark mode, wallpapers, system accent
# Ensures theme is registered and visible in Settings > Personalization > Themes
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-theme' 'Starting theme and wallpaper configuration.'

Write-Host "Configuring Velvet Theme and Wallpapers..." -ForegroundColor Cyan

$velvetWpDir    = "$env:SystemRoot\Web\Wallpaper\Velvet"
$sysThemesDir   = "$env:SystemRoot\Resources\Themes"
$userThemesDir  = "$env:LOCALAPPDATA\Microsoft\Windows\Themes"
$defThemesDir   = "C:\Users\Default\AppData\Local\Microsoft\Windows\Themes"

# 1. Create all theme and wallpaper directories
Write-SetupProgress 'config-theme' 'Creating theme and wallpaper directories.'
New-Item -ItemType Directory -Path $velvetWpDir, $sysThemesDir, $userThemesDir, $defThemesDir -Force -ErrorAction SilentlyContinue | Out-Null

# 2. Resolve wallpapers and theme file
Write-SetupProgress 'config-theme' 'Resolving staged wallpaper and theme assets.'
$wpCandidates = @(
    (Join-Path $PSScriptRoot "Wallpapers\desktop.jpg"),
    "$env:ProgramData\Velvet\Wallpapers\desktop.jpg"
)
$wpSource = $wpCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$lsCandidates = @(
    (Join-Path $PSScriptRoot "Wallpapers\lockscreen.jpg"),
    "$env:ProgramData\Velvet\Wallpapers\lockscreen.jpg"
)
$lsSource = $lsCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$themeCandidates = @(
    (Join-Path $PSScriptRoot "Themes\Velvet.theme"),
    "$env:ProgramData\Velvet\Themes\Velvet.theme"
)
$themeSource = $themeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $themeSource) {
    Write-Host "[WARN] Velvet.theme was not found in staged asset paths." -ForegroundColor Yellow
    exit 1
}

# Deploy wallpapers to %SystemRoot%\Web\Wallpaper\Velvet
Write-SetupProgress 'config-theme' 'Deploying wallpaper assets.'
$desktopWpPath = "$velvetWpDir\desktop.jpg"
$lockscreenWpPath = "$velvetWpDir\lockscreen.jpg"
if ($wpSource) {
    Copy-Item -LiteralPath $wpSource -Destination $desktopWpPath -Force -ErrorAction SilentlyContinue
}
if ($lsSource) {
    Copy-Item -LiteralPath $lsSource -Destination $lockscreenWpPath -Force -ErrorAction SilentlyContinue
}

# Deploy .theme files to System Themes, Current User Themes, and Default User Themes
Write-SetupProgress 'config-theme' 'Deploying theme files.'
$sysThemeFile = "$sysThemesDir\Velvet.theme"
$userThemeFile = "$userThemesDir\Velvet.theme"
$defThemeFile = "$defThemesDir\Velvet.theme"

if ($themeSource) {
    Copy-Item -LiteralPath $themeSource -Destination $sysThemeFile -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath $themeSource -Destination $userThemeFile -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath $themeSource -Destination $defThemeFile -Force -ErrorAction SilentlyContinue
}
foreach ($requiredTheme in @($sysThemeFile, $userThemeFile, $defThemeFile)) {
    if (-not (Test-Path -LiteralPath $requiredTheme)) {
        Write-Host "[WARN] Theme deployment could not be verified: $requiredTheme" -ForegroundColor Yellow
        exit 1
    }
}

# 3. Apply Desktop Wallpaper via SystemParametersInfo API
Write-SetupProgress 'config-theme' 'Applying desktop wallpaper and registry values.'
if (Test-Path -LiteralPath $desktopWpPath) {
    try {
        $setDesktopWallpaperCode = @'
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
        Add-Type -TypeDefinition $setDesktopWallpaperCode -ErrorAction SilentlyContinue
        [Wallpaper]::SystemParametersInfo(0x0014, 0, $desktopWpPath, 0x01 -bor 0x02) | Out-Null
    } catch {}

    # Update Desktop registry values
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $desktopWpPath -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0" -Type String -Force -ErrorAction SilentlyContinue
}

# 4. Clean up any restrictive policies that prevent changing lock screen
Write-SetupProgress 'config-theme' 'Removing restrictive lock-screen policies.'
try {
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP") {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImagePath" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageUrl" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP" -Name "LockScreenImageStatus" -ErrorAction SilentlyContinue
    }
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoChangingLockScreen" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Personalization" -Name "NoChangingLockScreen" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "LockScreenImage" -ErrorAction SilentlyContinue
} catch {}

# 5. Apply LockScreen Wallpaper via WinRT API
Write-SetupProgress 'config-theme' 'Applying lock-screen wallpaper.'
if (Test-Path -LiteralPath $lockscreenWpPath) {
    $screenDir = "$env:SystemRoot\Web\Screen"
    if (Test-Path -LiteralPath $screenDir) {
        try {
            Copy-Item -LiteralPath $lockscreenWpPath -Destination "$screenDir\img100.jpg" -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $lockscreenWpPath -Destination "$screenDir\img105.jpg" -Force -ErrorAction SilentlyContinue
        } catch {}
    }
    try {
        [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null
        $asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
        $storageFile = [Windows.Storage.StorageFile]::GetFileFromPathAsync($lockscreenWpPath).GetAwaiter().GetResult()
        $asyncAction = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($storageFile)
        $asTaskGeneric.Invoke($null, @($asyncAction)).GetAwaiter().GetResult()
    } catch {}
}

# 6. Register Theme in Registry so it appears under 'Themes'
Write-SetupProgress 'config-theme' 'Registering Velvet theme in the user registry.'
$themeReg = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes"
New-Item -Path $themeReg -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $themeReg -Name "CurrentTheme" -Value $sysThemeFile -Type String -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themeReg -Name "InstallVisualStyleColor" -Value "NormalColor" -Type String -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themeReg -Name "InstallVisualStyleSize" -Value "NormalSize" -Type String -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themeReg -Name "ThemeChangesDesktopIcons" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themeReg -Name "ThemeChangesMousePointers" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themeReg -Name "WallpaperSetFromTheme" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $themeReg -Name "ColorSetFromTheme" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# Ensure InstalledThemes list contains Velvet.theme
$installedThemes = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\InstalledThemes\MTSM"
New-Item -Path $installedThemes -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $installedThemes -Name "$sysThemeFile" -Value "" -Type String -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $installedThemes -Name "$userThemeFile" -Value "" -Type String -Force -ErrorAction SilentlyContinue
if (-not (Get-ItemProperty -Path $installedThemes -Name "$sysThemeFile" -ErrorAction SilentlyContinue)) {
    Write-Host "[WARN] Velvet.theme was not registered in InstalledThemes." -ForegroundColor Yellow
    exit 1
}

# 7. Enforce Dark Mode & Accent in Registry
$personalize = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
New-Item -Path $personalize -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $personalize -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $personalize -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $personalize -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

$dwm = "HKCU:\SOFTWARE\Microsoft\Windows\DWM"
New-Item -Path $dwm -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path $dwm -Name "AccentColor" -Value 0X00D8C400 -Type DWord -Force -ErrorAction SilentlyContinue

# 8. Theme files and registry values are sufficient for the next Explorer/session refresh.
Write-SetupProgress 'config-theme' 'Theme files and registry values are ready for the next session refresh.'

Write-Host "        [ OK ] Velvet theme and wallpapers configured and registered." -ForegroundColor Green
Write-SetupProgress 'config-theme' 'Completed successfully.'
exit 0
