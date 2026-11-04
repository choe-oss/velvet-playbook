@echo off
setlocal
title Velvet Playbook Builder
cd /d "%~dp0"

echo ================================================================================
echo                         Velvet Playbook Builder
echo ================================================================================
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
set BUILD_EXIT=%ERRORLEVEL%

echo.
if %BUILD_EXIT% equ 0 (
    echo [DONE] Build finished successfully.
) else (
    echo [FAIL] Build failed with exit code %BUILD_EXIT%.
)
echo.
echo Press any key to exit...
pause >nul
exit /b %BUILD_EXIT%

