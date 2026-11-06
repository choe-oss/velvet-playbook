# =============================================================================
# Velvet - Microsoft Edge Removal Script (remove-edge.ps1)
# =============================================================================

param (
    [ValidateSet("EdgeBrowser", "WebView", "EdgeUpdate")]
    [string]$Mode = "EdgeBrowser"
)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'write-setup-progress.ps1')
Write-SetupProgress 'remove-edge' "Starting Edge removal mode '$Mode'."
$script:RemovalFailures = 0

function Invoke-ExternalProcess {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string]$Arguments = ''
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process) {
        throw "Process could not be started: $FilePath"
    }
    $process.WaitForExit()
    return $process.ExitCode
}

function Enable-EdgeRegionUninstallPolicy {
    Write-SetupProgress 'remove-edge' 'Enabling the Edge uninstall policy region.'
    $policyPath = "$env:SystemRoot\System32\IntegratedServicesRegionPolicySet.json"
    if (Test-Path -LiteralPath $policyPath) {
        try {
            $jsonObj = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($policy in $jsonObj.policies) {
                if ($policy.guid -eq '{1bca278a-5d11-4acf-ad2f-f9ab6d7f93a6}') {
                    $policy.defaultState = 'enabled'
                }
            }
            $jsonObj | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $policyPath -Encoding UTF8 -Force
        } catch {}
    }
}

function Uninstall-Process {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $baseKey = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate'
    $registryPath = "$baseKey\ClientState\$Key"

    if (Test-Path -Path $registryPath) {
        Remove-ItemProperty -Path $registryPath -Name "experiment_control_labels" -ErrorAction SilentlyContinue | Out-Null
    }

    $uninstallString = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).UninstallString
    $uninstallArguments = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).UninstallArguments

    if ([string]::IsNullOrEmpty($uninstallString) -or !(Test-Path -Path $uninstallString)) {
        $potentialSetup = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application" -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($potentialSetup) {
            $uninstallString = $potentialSetup.FullName
            $uninstallArguments = "--uninstall --msedge --system-level --force-uninstall --delete-profile"
        }
    }

    if (![string]::IsNullOrEmpty($uninstallString) -and (Test-Path -Path $uninstallString)) {
        if ([string]::IsNullOrEmpty($uninstallArguments)) {
            $uninstallArguments = "--uninstall --msedge --system-level --force-uninstall --delete-profile"
        } elseif ($uninstallArguments -notlike "*--force-uninstall*") {
            $uninstallArguments += " --force-uninstall --delete-profile"
        }

        Write-Host "[$Mode] Executing uninstaller: $uninstallString" -ForegroundColor Cyan
        Write-SetupProgress 'remove-edge' "Executing Edge uninstaller for key $Key."
        $savedWindir = $env:windir
        try {
            $env:windir = ""
            $exitCode = Invoke-ExternalProcess -FilePath $uninstallString -Arguments $uninstallArguments
            if ($exitCode -ne 0) {
                $script:RemovalFailures++
                Write-SetupProgress 'remove-edge' "Edge uninstaller returned exit code $exitCode."
            }
        } catch {
            $script:RemovalFailures++
            Write-SetupProgress 'remove-edge' "Edge uninstaller could not be started or completed."
        } finally {
            $env:windir = $savedWindir
        }
    }
}

function Uninstall-Edge {
    Write-SetupProgress 'remove-edge' 'Removing the Edge browser package and services.'
    Enable-EdgeRegionUninstallPolicy

    # Unlock InboxApplications
    Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*MicrosoftEdge*" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    New-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev" -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev" -Name "AllowUninstall" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" -Name "NoRemove" -ErrorAction SilentlyContinue | Out-Null

    # Stop active Edge processes and services
    @("MicrosoftEdgeElevationService", "edgeupdate", "edgeupdatem") | ForEach-Object {
        Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue
        Set-Service -Name $_ -StartupType Disabled -ErrorAction SilentlyContinue
    }
    @("msedge", "MicrosoftEdgeUpdate", "chredge") | ForEach-Object {
        Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue
    }

    Uninstall-Process -Key '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'

    # Remove MSIX registration
    Get-AppxPackage -AllUsers -Name "*Microsoft.MicrosoftEdge*" -ErrorAction SilentlyContinue | ForEach-Object {
        $eolPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife\S-1-5-18\$($_.PackageFullName)"
        New-Item -Path $eolPath -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
    }

    # Clean directories
    Write-SetupProgress 'remove-edge' 'Removing Edge files, registrations, tasks, and shortcuts.'
    $edgeDirs = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge",
        "${env:ProgramFiles(x86)}\Microsoft\EdgeCore",
        "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate",
        "${env:ProgramFiles(x86)}\Microsoft\Temp"
    )
    foreach ($dir in $edgeDirs) {
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Remove-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update" -Recurse -Force -ErrorAction SilentlyContinue
    Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

    @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:PUBLIC\Desktop",
        "$env:USERPROFILE\Desktop",
        "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
    ) | ForEach-Object {
        $shortcutPath = Join-Path -Path $_ -ChildPath "Microsoft Edge.lnk"
        if (Test-Path -LiteralPath $shortcutPath) {
            Remove-Item -LiteralPath $shortcutPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Uninstall-WebView {
    Write-SetupProgress 'remove-edge' 'Removing Edge WebView.'
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView" -Name "NoRemove" -ErrorAction SilentlyContinue | Out-Null
    Uninstall-Process -Key '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
}

function Uninstall-EdgeUpdate {
    Write-SetupProgress 'remove-edge' 'Removing Edge Update.'
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update" -Name "NoRemove" -ErrorAction SilentlyContinue | Out-Null
    $registryPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate'
    $uninstallCmdLine = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).UninstallCmdLine
    if (![string]::IsNullOrEmpty($uninstallCmdLine)) {
        try {
            $exitCode = Invoke-ExternalProcess -FilePath $env:ComSpec -Arguments "/c $uninstallCmdLine"
            if ($exitCode -ne 0) {
                $script:RemovalFailures++
                Write-SetupProgress 'remove-edge' "Edge Update uninstaller returned exit code $exitCode."
            }
        } catch {
            $script:RemovalFailures++
            Write-SetupProgress 'remove-edge' 'Edge Update uninstaller could not be started or completed.'
        }
    }
}

switch ($Mode) {
    "EdgeBrowser" { Uninstall-Edge }
    "WebView"     { Uninstall-WebView }
    "EdgeUpdate"  { Uninstall-EdgeUpdate }
}
Write-SetupProgress 'remove-edge' 'Completed successfully.'
if ($script:RemovalFailures -gt 0) {
    exit 1
}
exit 0
