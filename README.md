# TermuxQ Next

TermuxQ Next adalah toolkit IT Support berbasis browser. Tool client-side berjalan langsung di browser; pembacaan CPU/RAM/storage/IP penuh memakai Python Agent lokal yang opsional. Menu yang memerlukan kemampuan sistem di luar browser memberikan panduan/perintah untuk disalin, bukan mengeksekusi shell bebas.

> Dashboard tidak menggunakan angka resource contoh. Ketika agent tidak terhubung, antarmuka membedakan metrik browser/jaringan dari statistik sistem yang belum tersedia. Log aktivitas menampilkan peristiwa sesi saat ini.

## Modul aktif di browser
Password generator, Hash checker (SHA), Encrypt/Decrypt (AES-GCM), Password Vault (terenkripsi di localStorage), JWT Inspector, Encode/Decode, Notes, To-Do, IT Support Ticket Log (localStorage + JSON import/export), IPv4 Subnet Calculator, Network Info, Live Device, DNS Lookup (Cloudflare DoH), HTTP response test, Speed test (Cloudflare), Traffic latency, Matrix effect, Defense/Privacy checklist.

## Akses
https://basojhie.github.io/termuxq-next/

Di HP (Chrome): menu ⋮ > **Install app** / **Add to Home Screen** untuk memakainya seperti aplikasi, termasuk saat offline.

## Struktur
- `index.html` : seluruh UI (HTML + CSS + JS)
- `manifest.json`, `sw.js`, dan ikon PNG di root : PWA (instal & offline)
- `.nojekyll` : menonaktifkan pemrosesan Jekyll di GitHub Pages

## Deploy
Settings > Pages > Source: *Deploy from a branch* > `main` / `(root)`.

## Catatan keamanan
Jangan commit token, password, atau konfigurasi pribadi ke repo publik.

## Sinkron dengan perangkat (opsional)
Dashboard memperbarui metrik browser setiap 3 detik. Untuk CPU, RAM, storage, uptime, baterai (jika didukung), dan IP lokal yang aktual, jalankan agent: `python termuxq_agent.py`. Saat dashboard dibuka melalui `http://localhost:8000` atau `http://127.0.0.1:8000`, dashboard mencoba menghubungkan agent lokal secara otomatis. Di GitHub Pages, buka modul **Device Sync (Agent)** lalu hubungkan secara manual bila browser mengizinkan akses jaringan lokal. Agent hanya mendengarkan `127.0.0.1`, hanya membaca statistik, dan tidak menjalankan perintah shell.


## Menjalankan dashboard dan agent lokal

### Windows
Klik dua kali `START_TERMUXQ_LIVE.bat`. Script menyiapkan dependensi statistik bila diperlukan, menjalankan agent dan server web lokal, lalu membuka browser pada `http://localhost:8000`.

### Termux / Linux / macOS
Jalankan `bash start_termuxq_live.sh`. Di Termux, script mencoba membuka browser otomatis; jika tidak, kunjungi `http://127.0.0.1:8000`.

### Batasan browser
Tool yang dibuat dengan JavaScript/Web Crypto berjalan langsung di browser. Statistik CPU/RAM/storage/IP memerlukan agent lokal. Menu console dan modul yang diberi label preview/simulasi tidak menjalankan perintah sistem; browser tidak diberi akses shell bebas.


## Modul browser tambahan
- **IPv4 Subnet Calculator** menghitung Network ID, Broadcast, subnet mask, wildcard, jumlah alamat, dan rentang host CIDR secara lokal.
- **IT Support Ticket Log** menyimpan tiket troubleshooting lokal, mengubah status, mencari/menyaring tiket, serta mengimpor/mengekspor JSON untuk cadangan manual.
- Dashboard dimulai dengan placeholder, bukan angka CPU/RAM/latensi statis. Nilai aktual dilabeli sesuai sumber data.
