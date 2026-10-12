@echo off
setlocal EnableExtensions
chcp 65001 >nul
title TermuxQ Agent Auto Update

set "SCRIPT_DIR=%~dp0"
rem SCRIPT_DIR ends in a backslash; add only a dot so PowerShell receives a clean folder path.
for %%I in ("%SCRIPT_DIR%.") do set "TARGET_DIR=%%~fI"
set "PS1=%TARGET_DIR%\update_and_start_termuxq_agent.ps1"

if not exist "%PS1%" (
  echo GAGAL: File update_and_start_termuxq_agent.ps1 tidak ditemukan.
  echo Ekstrak semua file ZIP ke satu folder yang sama.
  pause
  exit /b 1
)

if not exist "%TARGET_DIR%\termuxq_agent.py" call :AskAgentFolder
if errorlevel 1 (
  echo.
  echo Proses dibatalkan atau folder agent tidak valid.
  pause
  exit /b 1
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

:AskAgentFolder
echo.
echo File termuxq_agent.py tidak ada di folder updater.
echo Masukkan FOLDER yang berisi termuxq_agent.py, bukan nama file.
echo Contoh: D:\asrul\appilajara\termuxq_auto_update\TermuxQ_Next_Updated
set /p "TARGET_DIR=Folder agent: "
if not defined TARGET_DIR exit /b 1
set "TARGET_DIR=%TARGET_DIR:"=%"
for %%I in ("%TARGET_DIR%\..") do set "TARGET_PARENT=%%~fI"
for %%I in ("%TARGET_DIR%\.") do set "TARGET_DIR=%%~fI"
if not exist "%TARGET_DIR%\termuxq_agent.py" (
  echo GAGAL: File termuxq_agent.py tidak ditemukan di folder yang dimasukkan.
  exit /b 1
)
exit /b 0
