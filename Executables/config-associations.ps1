# =============================================================================
# Velvet - Default File Associations Configuration Script (config-associations.ps1)
# Chrome, Bandizip, qView, VLC, ONLYOFFICE, Notepad
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

# Check if qView is installed to choose preferred image viewer ProgID
$hasQView = (Test-Path "$env:ProgramFiles\qView\qView.exe") -or 
            (Test-Path "${env:ProgramFiles(x86)}\qView\qView.exe") -or 
            (Test-Path "$env:LOCALAPPDATA\Programs\qView\qView.exe")

$imgProgId = if ($hasQView) { "qView" } else { "PhotoViewer.FileAssoc.Jpeg" }
$pngProgId = if ($hasQView) { "qView" } else { "PhotoViewer.FileAssoc.Png" }

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

    # Image Formats (qView / PhotoViewer)
    @{ Type = "Ext"; Ext = ".bmp";  ProgId = (if ($hasQView) { "qView" } else { "PhotoViewer.FileAssoc.Bitmap" }) },
    @{ Type = "Ext"; Ext = ".dib";  ProgId = (if ($hasQView) { "qView" } else { "PhotoViewer.FileAssoc.Bitmap" }) },
    @{ Type = "Ext"; Ext = ".jfif"; ProgId = (if ($hasQView) { "qView" } else { "PhotoViewer.FileAssoc.JFIF" }) },
    @{ Type = "Ext"; Ext = ".jpe";  ProgId = $imgProgId },
    @{ Type = "Ext"; Ext = ".jpeg"; ProgId = $imgProgId },
    @{ Type = "Ext"; Ext = ".jpg";  ProgId = $imgProgId },
    @{ Type = "Ext"; Ext = ".png";  ProgId = $pngProgId },
    @{ Type = "Ext"; Ext = ".gif";  ProgId = (if ($hasQView) { "qView" } else { "PhotoViewer.FileAssoc.Tiff" }) },
    @{ Type = "Ext"; Ext = ".webp"; ProgId = (if ($hasQView) { "qView" } else { "ChromeHTML" }) },
    @{ Type = "Ext"; Ext = ".tif";  ProgId = "PhotoViewer.FileAssoc.Tiff" },
    @{ Type = "Ext"; Ext = ".tiff"; ProgId = "PhotoViewer.FileAssoc.Tiff" },

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
    Write-SetupProgress 'config-associations' "Applying associations to $hive."

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
            
            # Register in OpenWithProgids
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
