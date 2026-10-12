#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v python >/dev/null 2>&1; then
  echo "Python 3 tidak ditemukan. Pasang Python terlebih dahulu."
  exit 1
fi

if ! python -c "import psutil" >/dev/null 2>&1; then
  echo "Memasang psutil agar statistik CPU/RAM lebih lengkap..."
  python -m pip install --user psutil || echo "Peringatan: psutil gagal dipasang; sebagian metrik mungkin tidak tersedia."
fi

AGENT_LOG="${TMPDIR:-/tmp}/termuxq-agent.log"
python termuxq_agent.py >"$AGENT_LOG" 2>&1 &
AGENT_PID=$!
cleanup() {
  kill "$AGENT_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 1
URL="http://127.0.0.1:8000"
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "$URL" || true
elif command -v open >/dev/null 2>&1; then
  open "$URL" || true
fi

echo "TermuxQ live dashboard: $URL"
echo "Agent stats: http://127.0.0.1:8765/stats"
echo "Log agent: $AGENT_LOG"
echo "Tekan Ctrl+C untuk menghentikan server dan agent."
python -m http.server 8000 --bind 127.0.0.1
