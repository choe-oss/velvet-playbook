# =============================================================================
# Velvet - Default File Associations Configuration Script (config-associations.ps1)
# =============================================================================
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'config-associations' 'Starting default file association configuration.'

Write-Host "Configuring default file associations for installed applications..." -ForegroundColor Cyan

# 1. Resolve and import OEM Default Associations XML via DISM
$xmlCandidates = @(
    (Join-Path $PSScriptRoot "oem-default-associations.xml"),
    "$env:ProgramData\Velvet\oem-default-associations.xml",
    (Join-Path $PSScriptRoot "OEMDefaultAssociations.xml")
)
$xmlSource = $xmlCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ($xmlSource) {
    Write-SetupProgress 'config-associations' 'Importing OEM default associations XML.'
    $targetXml = "$env:WINDIR\System32\OEMDefaultAssociations.xml"
    Copy-Item -LiteralPath $xmlSource -Destination $targetXml -Force -ErrorAction SilentlyContinue
    & dism.exe /Online /NoRestart /Import-DefaultAppAssociations:"$targetXml" >$null 2>&1
}

# 윈도우 기본 사진 앱(Microsoft.Windows.Photos)의 정식 AppX ProgID 확인 함수
function Get-PhotosAppxProgId {
    param(
        [string]$Extension,
        [string]$DefaultFallback
    )

    $regPath = "Registry::HKEY_CLASSES_ROOT\$Extension\OpenWithProgids"
    if (Test-Path $regPath) {
        $props = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).PSObject.Properties
        $appxKey = $props | Where-Object { $_.Name -like "AppX*" } | Select-Object -ExpandProperty Name -First 1
        if ($appxKey) { return $appxKey }
    }

    $staticMap = @{
        ".jpg"  = "AppX43hnxt2h37hxnh6j5n0xga109277822"
        ".jpeg" = "AppX43hnxt2h37hxnh6j5n0xga109277822"
        ".jpe"  = "AppX43hnxt2h37hxnh6j5n0xga109277822"
        ".jfif" = "AppX43hnxt2h37hxnh6j5n0xga109277822"
        ".png"  = "AppX638sf6y9qg9vjqgahk4x0smmgzgw95xy"
        ".bmp"  = "AppXk0g4vb8gvt7b93tg50ybcy892pgeg2j0"
        ".dib"  = "AppXk0g4vb8gvt7b93tg50ybcy892pgeg2j0"
        ".gif"  = "AppXqn3gz9bq6044hn74bh7nytp70cb2b945"
        ".tif"  = "AppX3xxsq3vhj55qgah41zq0085fp07ykgh5"
        ".tiff" = "AppX3xxsq3vhj55qgah41zq0085fp07ykgh5"
    }

    if ($staticMap.ContainsKey($Extension)) {
        return $staticMap[$Extension]
    }

    return $DefaultFallback
}

# 2. Association definitions
$associations = @(
    # Web Browser & Protocols (Google Chrome)
    @{ Type = "Proto"; Proto = "http";  ProgId = "ChromeHTML" },
    @{ Type = "Proto"; Proto = "https"; ProgId = "ChromeHTML" },
    @{ Type = "Ext";   Ext = ".htm";   ProgId = "ChromeHTML" },
    @{ Type = "Ext";   Ext = ".html";  ProgId = "ChromeHTML" },
    @{ Type = "Ext";   Ext = ".shtml"; ProgId = "ChromeHTML" },
    @{ Type = "Ext";   Ext = ".pdf";   ProgId = "ChromeHTML" },

    # Archive Formats (Bandizip)
    @{ Type = "Ext"; Ext = ".zip"; ProgId = "Bandizip.ZIP" },
    @{ Type = "Ext"; Ext = ".7z";  ProgId = "Bandizip.7Z" },
    @{ Type = "Ext"; Ext = ".rar"; ProgId = "Bandizip.RAR" },
    @{ Type = "Ext"; Ext = ".tar"; ProgId = "Bandizip.TAR" },
    @{ Type = "Ext"; Ext = ".gz";  ProgId = "Bandizip.GZ" },
    @{ Type = "Ext"; Ext = ".tgz"; ProgId = "Bandizip.TGZ" },
    @{ Type = "Ext"; Ext = ".bz2"; ProgId = "Bandizip.BZ2" },
    @{ Type = "Ext"; Ext = ".xz";  ProgId = "Bandizip.XZ" },
    @{ Type = "Ext"; Ext = ".iso"; ProgId = "Bandizip.ISO" },
    @{ Type = "Ext"; Ext = ".cab"; ProgId = "Bandizip.CAB" },
    @{ Type = "Ext"; Ext = ".alz"; ProgId = "Bandizip.ALZ" },
    @{ Type = "Ext"; Ext = ".egg"; ProgId = "Bandizip.EGG" },

    # Image Formats (Windows Photos App / Chrome)
    @{ Type = "Ext"; Ext = ".bmp";  ProgId = (Get-PhotosAppxProgId ".bmp"  "PhotoViewer.FileAssoc.Bitmap") },
    @{ Type = "Ext"; Ext = ".dib";  ProgId = (Get-PhotosAppxProgId ".dib"  "PhotoViewer.FileAssoc.Bitmap") },
    @{ Type = "Ext"; Ext = ".jfif"; ProgId = (Get-PhotosAppxProgId ".jfif" "PhotoViewer.FileAssoc.JFIF") },
    @{ Type = "Ext"; Ext = ".jpe";  ProgId = (Get-PhotosAppxProgId ".jpe"  "PhotoViewer.FileAssoc.Jpeg") },
    @{ Type = "Ext"; Ext = ".jpeg"; ProgId = (Get-PhotosAppxProgId ".jpeg" "PhotoViewer.FileAssoc.Jpeg") },
    @{ Type = "Ext"; Ext = ".jpg";  ProgId = (Get-PhotosAppxProgId ".jpg"  "PhotoViewer.FileAssoc.Jpeg") },
    @{ Type = "Ext"; Ext = ".png";  ProgId = (Get-PhotosAppxProgId ".png"  "PhotoViewer.FileAssoc.Png") },
    @{ Type = "Ext"; Ext = ".gif";  ProgId = (Get-PhotosAppxProgId ".gif"  "PhotoViewer.FileAssoc.Gif") },
    @{ Type = "Ext"; Ext = ".tif";  ProgId = (Get-PhotosAppxProgId ".tif"  "PhotoViewer.FileAssoc.Tiff") },
    @{ Type = "Ext"; Ext = ".tiff"; ProgId = (Get-PhotosAppxProgId ".tiff" "PhotoViewer.FileAssoc.Tiff") },
    @{ Type = "Ext"; Ext = ".webp"; ProgId = "ChromeHTML" },

    # Notepad Text Formats
    @{ Type = "Ext"; Ext = ".txt";  ProgId = "txtfile" },
    @{ Type = "Ext"; Ext = ".log";  ProgId = "txtfile" },
    @{ Type = "Ext"; Ext = ".ini";  ProgId = "inifile" },
    @{ Type = "Ext"; Ext = ".inf";  ProgId = "inffile" },
    @{ Type = "Ext"; Ext = ".cfg";  ProgId = "txtfile" },
    @{ Type = "Ext"; Ext = ".md";   ProgId = "txtfile" },
    @{ Type = "Ext"; Ext = ".json"; ProgId = "txtfile" },
    @{ Type = "Ext"; Ext = ".xml";  ProgId = "xmlfile" },
    @{ Type = "Ext"; Ext = ".yml";  ProgId = "txtfile" },
    @{ Type = "Ext"; Ext = ".yaml"; ProgId = "txtfile" },

    # Documents & Office (ONLYOFFICE)
    @{ Type = "Ext"; Ext = ".docx"; ProgId = "ONLYOFFICE.docx" },
    @{ Type = "Ext"; Ext = ".doc";  ProgId = "ONLYOFFICE.doc" },
    @{ Type = "Ext"; Ext = ".xlsx"; ProgId = "ONLYOFFICE.xlsx" },
    @{ Type = "Ext"; Ext = ".xls";  ProgId = "ONLYOFFICE.xls" },
    @{ Type = "Ext"; Ext = ".pptx"; ProgId = "ONLYOFFICE.pptx" },
    @{ Type = "Ext"; Ext = ".ppt";  ProgId = "ONLYOFFICE.ppt" },
    @{ Type = "Ext"; Ext = ".odt";  ProgId = "ONLYOFFICE.odt" },
    @{ Type = "Ext"; Ext = ".ods";  ProgId = "ONLYOFFICE.ods" },
    @{ Type = "Ext"; Ext = ".csv";  ProgId = "ONLYOFFICE.csv" }
)

# 3. Apply to current user and mounted hives
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
$hives = @("HKCU:")
Get-ChildItem 'HKU:\' -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.PSChildName -like "S-1-5-21-*" -or $_.PSChildName -like "AME_UserHive_*") {
        $hives += "HKU:\$($_.PSChildName)"
    }
}
$hives = $hives | Select-Object -Unique
Write-SetupProgress 'config-associations' "Applying $($hives.Count) user hive(s) and $($associations.Count) association(s)."

foreach ($hive in $hives) {
    if (-not (Test-Path $hive)) { continue }

    foreach ($item in $associations) {
        if ($item.Type -eq "Proto") {
            $proto = $item.Proto
            $progId = $item.ProgId
            $urlKey = "$hive\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$proto"
            New-Item -Path $urlKey -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "$urlKey\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name "${progId}_${proto}" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        } else {
            $ext = $item.Ext
            $progId = $item.ProgId
            $extKey = "$hive\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
            New-Item -Path $extKey -Force -ErrorAction SilentlyContinue | Out-Null
            Remove-Item -Path "$extKey\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$hive\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" -Name "${progId}_${ext}" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            
            $owpKey = "$extKey\OpenWithProgids"
            New-Item -Path $owpKey -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $owpKey -Name $progId -Value ([byte[]]@()) -Type Binary -Force -ErrorAction SilentlyContinue
            
            try {
                [Microsoft.Win32.Registry]::SetValue("HKEY_CLASSES_ROOT\$ext", "", "$progId")
            } catch {}
        }
    }
}

Write-Host "        [ OK ] File associations successfully configured." -ForegroundColor Green
Write-SetupProgress 'config-associations' 'Completed successfully.'
exit 0