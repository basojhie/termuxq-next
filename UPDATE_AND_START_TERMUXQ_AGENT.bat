@echo off
setlocal EnableExtensions
chcp 65001 >nul
title TermuxQ Agent Auto Update
set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%update_and_start_termuxq_agent.ps1"

if not exist "%PS1%" (
  echo GAGAL: File update_and_start_termuxq_agent.ps1 tidak ditemukan.
  echo Pastikan kedua file diekstrak dari ZIP ke folder yang sama.
  pause
  exit /b 1
)

set "TARGET_DIR=%SCRIPT_DIR%"
if not exist "%TARGET_DIR%termuxq_agent.py" (
  echo.
  echo Masukkan FOLDER yang berisi termuxq_agent.py.
  echo Contoh: D:\TermuxQ atau C:\Users\Nama\termuxq-next
  set /p "TARGET_DIR=Folder agent: "
  set "TARGET_DIR=%TARGET_DIR:"=%"
  if not defined TARGET_DIR (
    echo Folder tidak diisi.
    pause
    exit /b 1
  )
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -TargetDirectory "%TARGET_DIR%"
set "TQ_RC=%ERRORLEVEL%"
if not "%TQ_RC%"=="0" (
  echo.
  echo Proses gagal. Baca pesan error di atas.
  pause
) else (
  echo.
  echo Pembaruan selesai. Kamu boleh menutup jendela ini.
  pause
)
exit /b %TQ_RC%
