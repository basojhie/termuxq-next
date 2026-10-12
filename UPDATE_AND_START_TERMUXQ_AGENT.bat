@echo off
setlocal
title TermuxQ Agent Auto Update
set "TQ_PS1=%TEMP%\termuxq_agent_update_%RANDOM%.ps1"
set "TQ_PS1_URL=https://raw.githubusercontent.com/basojhie/termuxq-next/main/update_and_start_termuxq_agent.ps1"

echo.
echo === TermuxQ Agent Auto Update ===
echo Folder target: %~dp0
echo Mengambil updater terbaru...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '%TQ_PS1_URL%' -OutFile '%TQ_PS1%'; if (-not (Test-Path -LiteralPath '%TQ_PS1%')) { exit 1 }"
if errorlevel 1 (
  echo GAGAL: Tidak dapat mengunduh updater. Periksa koneksi internet.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TQ_PS1%" -TargetDirectory "%~dp0"
set "TQ_RC=%ERRORLEVEL%"
del "%TQ_PS1%" >nul 2>&1
if not "%TQ_RC%"=="0" (
  echo.
  echo Proses tidak selesai. Baca pesan error di atas.
  pause
)
exit /b %TQ_RC%
