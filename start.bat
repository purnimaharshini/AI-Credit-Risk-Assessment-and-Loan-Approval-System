@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start.ps1" %*
  exit /b %ERRORLEVEL%
)

where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
  echo Error: Neither pwsh nor powershell was found in PATH.
  exit /b 1
)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start.ps1" %*
exit /b %ERRORLEVEL%
