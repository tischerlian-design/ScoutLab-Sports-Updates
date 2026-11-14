@echo off
setlocal EnableExtensions
chcp 65001 >nul
set "INSTALLER=%~dp0INSTALL_SCOUTLAB.ps1"
if not exist "%INSTALLER%" (
  echo FEHLER: INSTALL_SCOUTLAB.ps1 wurde nicht gefunden.
  echo Bitte die ZIP vollstaendig entpacken und INSTALL_SCOUTLAB.bat erneut starten.
  pause
  exit /b 2
)
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo FEHLER: Windows PowerShell wurde nicht gefunden.
  pause
  exit /b 3
)
rem The PowerShell script locates its own folder via $PSScriptRoot.
rem Do not pass %%~dp0 as an argument: it ends in a backslash and can break quoting.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%INSTALLER%"
exit /b %ERRORLEVEL%
