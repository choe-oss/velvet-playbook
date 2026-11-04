@echo off
REM =============================================================================
REM Velvet Finalize and Background Optimization Script (finalize-system.cmd)
REM Note: System reboot is strictly deferred to the post-desktop setup phase!
REM =============================================================================

pushd "%~dp0"

REM ---------------------------------------------------------------------------
REM 1. Remove Forced Upgrade and Diagnostic Helpers
REM ---------------------------------------------------------------------------
msiexec /X{43D501A5-E5E3-46EC-8F33-9E15D2A2CBD5} /qn /norestart >NUL 2>nul
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\UpdateHealthTools" /f >NUL 2>nul
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\rempl" /f >NUL 2>nul
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudManagedUpdate" /f >NUL 2>nul
reg delete "HKLM\SOFTWARE\Microsoft\CloudManagedUpdate" /f >NUL 2>nul
rmdir /s /q "%ProgramW6432%\Microsoft Update Health Tools" >NUL 2>nul

msiexec /X{804A0628-543B-4984-896C-F58BF6A54832} /qn /norestart >NUL 2>nul
rmdir /s /q "%ProgramW6432%\PCHealthCheck" >NUL 2>nul

"%ProgramFiles(x86)%\WindowsInstallationAssistant\Windows10UpgraderApp.exe" /SunValley /ForceUninstall >NUL 2>nul
rmdir /s /q "%ProgramFiles(x86)%\WindowsInstallationAssistant" >NUL 2>nul

REM ---------------------------------------------------------------------------
REM 2. Configure Velvet BCD & OEM Branding
REM ---------------------------------------------------------------------------
bcdedit /set description "Velvet" >NUL 2>nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v "Model" /t REG_SZ /d "Velvet" /f >NUL 2>nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v "Manufacturer" /t REG_SZ /d "Velvet" /f >NUL 2>nul
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" /v "SupportProvider" /t REG_SZ /d "Velvet" /f >NUL 2>nul
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "RegisteredOrganization" /t REG_SZ /d "Velvet" /f >NUL 2>nul

REM ---------------------------------------------------------------------------
REM 3. Configure Scheduled Tasks
REM ---------------------------------------------------------------------------
schtasks /change /tn "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /enable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Windows Error Reporting\QueueReporting" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Application Experience\AitAgent" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" /disable >NUL 2>nul

schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\StartOobeAppsScanAfterUpdate" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\Start Oobe Expedite Work" /disable >NUL 2>nul
schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan" /enable >NUL 2>nul

wevtutil sl Microsoft-Windows-SleepStudy/Diagnostic /q:false >NUL 2>nul
wevtutil sl Microsoft-Windows-Kernel-Processor-Power/Diagnostic /q:false >NUL 2>nul
wevtutil sl Microsoft-Windows-UserModePowerService/Diagnostic /q:false >NUL 2>nul

REM ---------------------------------------------------------------------------
REM 4. Configure BCD Boot Settings & Hypervisor for Core Isolation
REM ---------------------------------------------------------------------------
bcdedit /deletevalue useplatformclock >NUL 2>nul
bcdedit /deletevalue disabledynamictick >NUL 2>nul
bcdedit /set hypervisorlaunchtype auto >NUL 2>nul
bcdedit /set bootmenupolicy Legacy >NUL 2>nul
bcdedit /set lastknowngood yes >NUL 2>nul

REM ---------------------------------------------------------------------------
REM 5. Network & Windows Settings
REM ---------------------------------------------------------------------------
netsh interface Teredo set state type=default >NUL 2>nul
net accounts /maxpwage:unlimited >NUL 2>nul
PowerShell -NonInteractive -NoLogo -NoProfile -Command "Disable-WindowsErrorReporting" >NUL 2>nul

popd
exit /b 0
