#!/usr/bin/env python3
"""TermuxQ Agent: server BACA-SAJA di 127.0.0.1 untuk dashboard TermuxQ.
Hanya mengirim statistik perangkat (JSON). Tidak menjalankan perintah dari web.
Jalankan:  python termuxq_agent.py   (Ctrl+C untuk berhenti)
Opsional:  pip install psutil  (CPU/RAM/baterai lebih akurat di Windows/Linux)"""
import ipaddress, json, os, platform, re, shutil, socket, subprocess, threading, time
from collections import deque
from urllib.parse import parse_qs, urlsplit
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
try:
    import psutil
except ImportError:
    psutil = None

PORT = int(os.environ.get("TQ_PORT", "8765"))
ORIGINS = {"https://basojhie.github.io", "http://localhost:8000", "http://127.0.0.1:8000"}

# Ping hanya ditujukan ke subnet privat RFC1918. Tidak menerima hostname/IP publik.
_PRIVATE_NETS = tuple(ipaddress.ip_network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"))
_PING_CALLS = deque()
_PING_LOCK = threading.Lock()
_MAX_PINGS_PER_MINUTE = 60

def cpu():
    try:
        if psutil: return psutil.cpu_percent(interval=None)
    except Exception: pass
    try: return round(min(100.0, os.getloadavg()[0] / (os.cpu_count() or 1) * 100), 1)  # perkiraan dari load average
    except Exception: return None

def mem():
    try:
        if psutil:
            m = psutil.virtual_memory(); return {"total": m.total, "used": m.total - m.available, "pct": m.percent}
    except Exception: pass
    try:
        d = {l.split(":")[0]: int(l.split()[1]) * 1024 for l in open("/proc/meminfo") if ":" in l}
        t = d["MemTotal"]; u = t - d.get("MemAvailable", d.get("MemFree", 0))
        return {"total": t, "used": u, "pct": round(u / t * 100, 1)}
    except Exception: return None

def disk():
    try:
        u = shutil.disk_usage(os.path.expanduser("~"))
        return {"total": u.total, "used": u.used, "pct": round(u.used / u.total * 100, 1)}
    except Exception: return None

_bat = (0, None)
def battery():
    global _bat
    if time.time() - _bat[0] < 20: return _bat[1]
    r = None
    try:
        b = psutil.sensors_battery() if psutil else None
        if b: r = {"pct": b.percent, "charging": bool(b.power_plugged)}
    except Exception: pass
    if r is None and shutil.which("termux-battery-status"):
        try:
            j = json.loads(subprocess.run(["termux-battery-status"], capture_output=True, text=True, timeout=5).stdout)
            r = {"pct": j["percentage"], "charging": j.get("status") == "CHARGING"}
        except Exception: pass
    _bat = (time.time(), r); return r

def local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(("10.255.255.255", 1))  # tidak mengirim paket
        a = s.getsockname()[0]; s.close(); return a
    except Exception: return None

def uptime():
    try:
        if psutil: return int(time.time() - psutil.boot_time())
        return int(float(open("/proc/uptime").read().split()[0]))
    except Exception: return None

def ping_host(value):
    """Ping satu alamat IPv4 privat dengan argumen tetap (tanpa shell)."""
    try:
        target = ipaddress.ip_address(value)
    except ValueError:
        return 400, {"error": "Masukkan alamat IPv4 yang valid."}
    if not isinstance(target, ipaddress.IPv4Address) or not any(target in net for net in _PRIVATE_NETS):
        return 400, {"error": "Target dibatasi ke IPv4 privat RFC1918 (10/8, 172.16/12, 192.168/16)."}

    executable = shutil.which("ping")
    if not executable:
        return 501, {"error": "Perintah ping tidak tersedia pada perangkat ini."}

    now = time.monotonic()
    with _PING_LOCK:
        while _PING_CALLS and now - _PING_CALLS[0] >= 60:
            _PING_CALLS.popleft()
        if len(_PING_CALLS) >= _MAX_PINGS_PER_MINUTE:
            return 429, {"error": "Batas 60 pemeriksaan ping per menit tercapai. Coba lagi sebentar."}
        _PING_CALLS.append(now)

    if os.name == "nt":
        command = [executable, "-n", "1", "-w", "800", str(target)]
    elif platform.system() == "Darwin":
        command = [executable, "-c", "1", "-W", "1000", str(target)]
    else:
        command = [executable, "-c", "1", "-W", "1", str(target)]

    started = time.monotonic()
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=2.5, check=False)
        elapsed_ms = round((time.monotonic() - started) * 1000, 1)
        output = (completed.stdout or "") + "\n" + (completed.stderr or "")
    except subprocess.TimeoutExpired:
        elapsed_ms = round((time.monotonic() - started) * 1000, 1)
        return 200, {"host": str(target), "reachable": False, "latency_ms": None,
                     "elapsed_ms": elapsed_ms, "message": "Ping melewati batas waktu."}
    except OSError:
        return 501, {"error": "Ping tidak dapat dijalankan pada perangkat ini."}

    unreachable = re.search(r"destination host unreachable|request timed out|request timeout|100% packet loss", output, re.I)
    reachable = completed.returncode == 0 and not unreachable
    match = re.search(r"time[=<]\s*([\d.,]+)\s*ms", output, re.I)
    latency_ms = float(match.group(1).replace(",", ".")) if match else None
    return 200, {"host": str(target), "reachable": reachable, "latency_ms": latency_ms,
                 "elapsed_ms": elapsed_ms,
                 "message": "Respons ping diterima." if reachable else "Tidak ada balasan ping."}


class H(BaseHTTPRequestHandler):
    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self._cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _cors(self):
        o = self.headers.get("Origin")
        if o in ORIGINS:
            self.send_header("Access-Control-Allow-Origin", o); self.send_header("Vary", "Origin")
            self.send_header("Access-Control-Allow-Private-Network", "true")
    def _ok_host(self):
        return self.headers.get("Host", "").split(":")[0] in ("127.0.0.1", "localhost")
    def do_OPTIONS(self):
        if not self._ok_host(): self.send_response(403); self.end_headers(); return
        self.send_response(204); self._cors()
        self.send_header("Access-Control-Allow-Methods", "GET"); self.send_header("Access-Control-Allow-Headers", "*"); self.end_headers()
    def do_GET(self):
        if not self._ok_host():
            self.send_response(404); self.end_headers(); return
        route = urlsplit(self.path)
        if route.path == "/stats":
            self._json(200, {"host": socket.gethostname(), "os": platform.system() + " " + platform.release(),
                "cores": os.cpu_count(), "cpu_pct": cpu(), "mem": mem(), "disk": disk(), "battery": battery(),
                "ip": local_ip(), "uptime": uptime()})
            return
        if route.path == "/ping":
            target = parse_qs(route.query).get("host", [""])[0].strip()
            status, payload = ping_host(target)
            self._json(status, payload)
            return
        self.send_response(404); self.end_headers()
    def log_message(self, *a): pass

if __name__ == "__main__":
    cpu()
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), H)
    print(f"TermuxQ Agent aktif: http://127.0.0.1:{PORT}/stats  (Ctrl+C untuk berhenti)")
    try: srv.serve_forever()
    except KeyboardInterrupt: print("\nBerhenti.")
