@echo off
setlocal
title Proxyum SpotX Old Theme Installer

echo Abrindo o instalador Proxyum SpotX...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://github.com/Sanderapps/proxyum-spotx-old-theme/releases/latest/download/i.ps1' | iex"
set "PROXYUM_EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%PROXYUM_EXIT_CODE%"=="0" (
    echo O instalador terminou com erro %PROXYUM_EXIT_CODE%.
) else (
    echo Instalador finalizado.
)

echo.
pause
exit /b %PROXYUM_EXIT_CODE%
