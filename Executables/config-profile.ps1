# =============================================================================
# Velvet - User Account Profile Picture Configuration Script (config-profile.ps1)
# Registers high-resolution avatar for user account
# =============================================================================

Add-Type -AssemblyName System.Drawing

$sourceCandidates = @(
    (Join-Path $PSScriptRoot "user.png"),
    (Join-Path (Get-Location).Path "user.png"),
    "$env:ProgramData\Velvet\user.png"
)

$sourcePath = $sourceCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $sourcePath) {
    exit 0
}

$destDir = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) "Microsoft\User Account Pictures"
if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force -ErrorAction SilentlyContinue | Out-Null
}

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
        } finally {
            $bmp.Dispose()
        }
    }
} finally {
    $img.Dispose()
}

Write-Host "        [ OK ] Velvet user account profile pictures updated." -ForegroundColor Green
exit 0
