@echo off
setlocal
title Proxyum SpotX Old Theme Installer

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ProxyumSpotX.ps1"
set "PROXYUM_EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%PROXYUM_EXIT_CODE%"=="0" (
    echo A instalacao terminou com erro %PROXYUM_EXIT_CODE%.
) else (
    echo Instalacao finalizada.
)

pause
exit /b %PROXYUM_EXIT_CODE%

