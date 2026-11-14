@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%server.ps1" (
  echo ScoutLab konnte server.ps1 nicht finden.
  echo Bitte INSTALL_SCOUTLAB.bat aus dem vollstaendig entpackten Ordner ausfuehren.
  pause
  exit /b 2
)
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo Windows PowerShell wurde nicht gefunden.
  pause
  exit /b 3
)
start "" powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ROOT%server.ps1"
exit /b 0
