# =============================================================================
# Velvet Playbook Builder (build.ps1)
# Packages the playbook into an AME Wizard compatible .apbx archive.
# Specifications: 7z format, password 'malte', LZMA2 compression.
# Only includes: Configuration/, Executables/, playbook.conf, playbook.png.
# =============================================================================
$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Velvet Playbook Builder"

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "                         Velvet Playbook Builder                                " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
Set-Location -LiteralPath $root

# 1. Resolve Playbook Name from playbook.conf
$confPath = Join-Path $root "playbook.conf"
if (-not (Test-Path -LiteralPath $confPath)) {
    Write-Host "[!] Error: 'playbook.conf' not found in $root" -ForegroundColor Red
    exit 1
}

$playbookName = "Velvet"
try {
    [xml]$xml = Get-Content -LiteralPath $confPath -Raw -Encoding UTF8
    if ($xml.Playbook.Name) {
        $playbookName = $xml.Playbook.Name.Trim()
    } elseif ($xml.Playbook.Title) {
        $playbookName = $xml.Playbook.Title.Trim()
    }
} catch {
    Write-Host "[!] Warning: Could not parse XML from playbook.conf, using default name '$playbookName'" -ForegroundColor Yellow
}

$outputApbx = Join-Path $root "$playbookName.apbx"
Write-Host "[*] Target Playbook : $playbookName" -ForegroundColor White
Write-Host "[*] Target Archive  : $outputApbx" -ForegroundColor White
Write-Host ""

# 2. Verify Required Input Directories and Files
$requiredItems = @(
    "Configuration",
    "Executables",
    "playbook.conf",
    "playbook.png"
)

$missing = @()
foreach ($item in $requiredItems) {
    $full = Join-Path $root $item
    if (-not (Test-Path -LiteralPath $full)) {
        $missing += $item
    }
}

if ($missing.Count -gt 0) {
    Write-Host "[!] Error: Missing required playbook components:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    exit 1
}

# 3. Resolve or Acquire 7-Zip Archiver
function Resolve-7Zip {
    # Check well-known local installations
    $candidates = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:TEMP\7zr.exe",
        "$env:TEMP\7za.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path -LiteralPath $cand) { return $cand }
    }

    # Check system PATH
    foreach ($cmdName in @("7z.exe", "7za.exe", "7zr.exe")) {
        $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
            return $cmd.Source
        }
    }

    return $null
}

$archiver = Resolve-7Zip
if (-not $archiver) {
    Write-Host "[!] Error: 7-Zip was not found. Install 7-Zip from https://www.7-zip.org and run the builder again." -ForegroundColor Red
    exit 1
}

Write-Host "[*] Using Archiver  : $archiver" -ForegroundColor DarkGray

# 4. Remove Existing Target Archive if Present
if (Test-Path -LiteralPath $outputApbx) {
    Write-Host "[*] Removing previous build: $outputApbx" -ForegroundColor DarkGray
    Remove-Item -LiteralPath $outputApbx -Force -ErrorAction SilentlyContinue
}

# 5. Build Archive (AME Wizard Standards: 7z, password 'malte', LZMA2)
Write-Host "[*] Compressing and encrypting playbook archive..." -ForegroundColor Cyan

$sevenZipArgs = @(
    "a",
    "-t7z",
    "-pmalte",
    "-mx=7",
    "-bso1",
    "-bse2",
    "`"$outputApbx`"",
    "Configuration",
    "Executables",
    "playbook.conf",
    "playbook.png"
)

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process -FilePath $archiver -ArgumentList $sevenZipArgs -Wait -PassThru -NoNewWindow
$sw.Stop()

if ($proc.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outputApbx)) {
    Write-Host "[!] Build failed with exit code $($proc.ExitCode)." -ForegroundColor Red
    exit 1
}

# 6. Verify Archive Integrity
Write-Host "[*] Testing archive integrity..." -ForegroundColor Cyan
$testProc = Start-Process -FilePath $archiver -ArgumentList @("t", "-pmalte", "`"$outputApbx`"") -Wait -PassThru -NoNewWindow
if ($testProc.ExitCode -ne 0) {
    Write-Host "[!] Archive verification failed!" -ForegroundColor Red
    exit 1
}

# 7. Mirror Copy to Parent Directory for Convenience
$parentDir = Split-Path $root -Parent
$parentCopy = $null
if ($parentDir -and (Test-Path -LiteralPath $parentDir)) {
    $parentCopy = Join-Path $parentDir "$playbookName.apbx"
    Copy-Item -LiteralPath $outputApbx -Destination $parentCopy -Force -ErrorAction SilentlyContinue
}

$fileItem = Get-Item -LiteralPath $outputApbx
$sizeMb = [Math]::Round($fileItem.Length / 1MB, 2)

Write-Host ""
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "                    [ SUCCESS ] Playbook Build Complete!                        " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Green
Write-Host " Package Name : $playbookName.apbx" -ForegroundColor White
Write-Host " Package Path : $($fileItem.FullName)" -ForegroundColor White
if ($parentCopy -and (Test-Path -LiteralPath $parentCopy)) {
    Write-Host " Mirror Copy  : $parentCopy" -ForegroundColor Gray
}
Write-Host " File Size    : $sizeMb MB ($($fileItem.Length) bytes)" -ForegroundColor White
Write-Host " Format       : 7z (AES-256 encrypted, password: malte)" -ForegroundColor White
Write-Host " Build Time   : $([Math]::Round($sw.Elapsed.TotalSeconds, 2)) seconds" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now load '$playbookName.apbx' directly into AME Wizard." -ForegroundColor Cyan
Write-Host ""
exit 0
