@echo off
setlocal
cd /d "%~dp0"
title TermuxQ Live Dashboard
where python >nul 2>&1
if errorlevel 1 (
  echo Python 3 belum tersedia. Instal Python 3 lalu jalankan lagi.
  pause
  exit /b 1
)
python -c "import psutil" >nul 2>&1
if errorlevel 1 (
  echo Memasang psutil untuk data CPU/RAM yang lebih lengkap...
  python -m pip install --user psutil
  if errorlevel 1 echo PERINGATAN: psutil gagal dipasang; sebagian statistik mungkin tidak tersedia.
)
echo Menjalankan agent lokal...
start "TermuxQ Agent" /D "%~dp0" cmd /k "python termuxq_agent.py"
timeout /t 2 /nobreak >nul
echo Membuka http://localhost:8000
start "" "http://localhost:8000"
echo Server web berjalan pada 127.0.0.1:8000.
echo Tutup jendela ini dan jendela TermuxQ Agent untuk menghentikan semuanya.
python -m http.server 8000 --bind 127.0.0.1
pause
