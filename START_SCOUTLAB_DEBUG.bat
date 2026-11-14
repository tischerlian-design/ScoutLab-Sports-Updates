@echo off
setlocal
cd /d "%~dp0"
title ScoutLab Sports 0.8.1 - Diagnose
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0server.ps1"
