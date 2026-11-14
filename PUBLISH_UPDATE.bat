@echo off
setlocal
cd /d "%~dp0"
echo ScoutLab Sports - Update-Manifest erstellen
echo.
set /p VERSION=Neue Versionsnummer (z.B. 0.8.1):
if "%VERSION%"=="" exit /b 1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0MAKE_UPDATE_MANIFEST.ps1" -Version "%VERSION%"
if errorlevel 1 pause
