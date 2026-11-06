# =============================================================================
# Velvet - User Account Profile Picture Configuration Script (config-profile.ps1)
# Registers high-resolution avatar for user account
# =============================================================================

. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-profile' 'Starting account profile picture configuration.'
Add-Type -AssemblyName System.Drawing

$sourceCandidates = @(
    (Join-Path $PSScriptRoot "user.png"),
    (Join-Path (Get-Location).Path "user.png"),
    "$env:ProgramData\Velvet\user.png"
)

$sourcePath = $sourceCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $sourcePath) {
    Write-Host "[WARN] Velvet profile image was not found in staged asset paths." -ForegroundColor Yellow
    Write-SetupProgress 'config-profile' 'Profile image source was not found.'
    exit 0
}

$destDir = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) "Microsoft\User Account Pictures"
if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force -ErrorAction SilentlyContinue | Out-Null
}
$userAccountPictures = Join-Path $env:APPDATA 'Microsoft\Windows\AccountPictures'
$defaultAccountPictures = 'C:\Users\Default\AppData\Roaming\Microsoft\Windows\AccountPictures'
New-Item -ItemType Directory -Path $userAccountPictures, $defaultAccountPictures -Force -ErrorAction SilentlyContinue | Out-Null

$img = [System.Drawing.Image]::FromFile($sourcePath)
try {
    $pfpSizes = @{
        "user.png"     = 448
        "user.bmp"     = 448
        "guest.png"    = 448
        "guest.bmp"    = 448
        "user-192.png" = 192
        "user-48.png"  = 48
        "user-40.png"  = 40
        "user-32.png"  = 32
    }

    foreach ($file in $pfpSizes.Keys) {
        $size = $pfpSizes[$file]
        $bmp = New-Object System.Drawing.Bitmap($size, $size)
        try {
            $bmp.SetResolution($img.HorizontalResolution, $img.VerticalResolution)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

                $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
                $wrapMode = New-Object System.Drawing.Imaging.ImageAttributes
                try {
                    $wrapMode.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
                    $g.DrawImage($img, $rect, 0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $wrapMode)
                } finally {
                    $wrapMode.Dispose()
                }
            } finally {
                $g.Dispose()
            }

            $destPath = Join-Path $destDir $file
            $format = if ($file.EndsWith(".bmp")) { [System.Drawing.Imaging.ImageFormat]::Bmp } else { [System.Drawing.Imaging.ImageFormat]::Png }
            $bmp.Save($destPath, $format)
            Copy-Item -LiteralPath $destPath -Destination (Join-Path $userAccountPictures $file) -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $destPath -Destination (Join-Path $defaultAccountPictures $file) -Force -ErrorAction SilentlyContinue
        } finally {
            $bmp.Dispose()
        }
    }
} finally {
    $img.Dispose()
}

# Point the current account and loaded account hives at the generated files.
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
$accountPictureRoot = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$sid"
New-Item -Path $accountPictureRoot -Force -ErrorAction SilentlyContinue | Out-Null
$accountPictureFiles = @{
    Image448 = (Join-Path $userAccountPictures 'user.png')
    Image192 = (Join-Path $userAccountPictures 'user-192.png')
    Image48 = (Join-Path $userAccountPictures 'user-48.png')
    Image40 = (Join-Path $userAccountPictures 'user-40.png')
    Image32 = (Join-Path $userAccountPictures 'user-32.png')
}
foreach ($entry in $accountPictureFiles.GetEnumerator()) {
    $generated = $entry.Value
    if (Test-Path -LiteralPath $generated) {
        New-ItemProperty -Path $accountPictureRoot -Name $entry.Key -PropertyType String -Value $generated -Force -ErrorAction SilentlyContinue | Out-Null
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $destDir 'user.png'))) {
    Write-Host "[WARN] Profile image generation did not produce the expected account picture." -ForegroundColor Yellow
}

if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}
$loadedSids = Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' -and $_.PSChildName -notlike '*_Classes' } |
    Select-Object -ExpandProperty PSChildName -Unique
foreach ($loadedSid in $loadedSids) {
    $hivePath = "HKU:\$loadedSid\Software\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$loadedSid"
    New-Item -Path $hivePath -Force -ErrorAction SilentlyContinue | Out-Null
    foreach ($entry in $accountPictureFiles.GetEnumerator()) {
        $generated = $entry.Value
        if (Test-Path -LiteralPath $generated) {
            New-ItemProperty -Path $hivePath -Name $entry.Key -PropertyType String -Value $generated -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

Write-Host "        [ OK ] Velvet user account profile pictures updated." -ForegroundColor Green
Write-SetupProgress 'config-profile' 'Completed successfully.'
exit 0
