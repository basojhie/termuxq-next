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


## Modul yang ditambahkan
- **HTTP / SSL Inspector** mencoba permintaan HEAD dari browser. Jika CORS mengizinkan, ia menunjukkan status, waktu respons, dan header yang terlihat. Browser tidak membuka detail sertifikat lengkap, dan header yang tersembunyi oleh CORS tidak boleh dianggap tidak ada.
- **Project Health Check** menguji Web Crypto, penyimpanan lokal, dukungan/registrasi service worker, handler modul, serta file manifest/icon yang diperlukan.
- **Pembaruan Termux**: unduh script update_termuxq.sh dari repo ini lalu jalankan. Script membuat cadangan sebelum pembaruan repo, menolak perubahan lokal yang belum disimpan, dan menggunakan fast-forward saja.


## System Resource History
Saat Python Agent terhubung, dashboard menyimpan satu sampel CPU/RAM/storage/baterai yang tersedia per menit (maksimal 120 sampel) di penyimpanan lokal browser. Panel Resource History menampilkan hingga 30 sampel terakhir. Riwayat hanya tersedia pada browser/perangkat yang menyimpannya; ini bukan backend terpusat atau log permanen.

## Quality checks
GitHub Actions menjalankan pemeriksaan sintaks, uji API agent baca-saja, dan uji interaksi browser untuk subnet calculator, ticket log, hash checker, HTTP Inspector, serta Project Health Check.


## LAN Device Monitor (fitur terbaru)
Modul **LAN Device Monitor** memakai Python Agent lokal untuk mengirim satu ping ICMP ke masing-masing host IPv4 privat yang dimasukkan secara manual. Masukkan alamat satu per baris, kemudian pilih **Ping semua**. Daftar disimpan di localStorage browser ini, tidak dikirim ke backend pusat.

Perlindungan agent: target dibatasi ke subnet privat RFC1918 (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16), maksimal 24 target per batch dari UI dan 60 panggilan ping per menit pada agent. Validasi berlaku di browser dan agent; proses ping menggunakan argumen terpisah tanpa shell dan timeout pendek. Tidak ada pemindaian port atau eksekusi perintah bebas. Gunakan hanya pada jaringan dan perangkat yang kamu miliki atau diizinkan untuk dikelola.

Jalankan dashboard serta agent lokal dengan instruksi di atas, lalu buka **Network Tools → LAN Device Monitor**. Bila dibuka melalui GitHub Pages, browser harus mengizinkan koneksi lokal ke agent dan agent harus berjalan pada perangkat yang sama dengan browser.


### Diagnosis Agent versi lama
Endpoint /stats mengembalikan agent_version dan features. Dashboard menggunakan metadata ini untuk memeriksa dukungan private_lan_ping. Jika Agent lama masih terhubung, modul LAN memberi petunjuk untuk mengganti termuxq_agent.py lalu menjalankannya ulang, bukan sekadar menampilkan NetworkError.


## Otomatis memperbarui dan menjalankan Agent di Windows
1. Simpan file **UPDATE_AND_START_TERMUXQ_AGENT.bat** ke folder tempat termuxq_agent.py yang biasa digunakan berada.
2. Klik dua kali file .bat. Script mengunduh updater terbaru, mengunduh dan memeriksa Agent resmi, membuat cadangan ke %LOCALAPPDATA%\TermuxQ\agent-backups, lalu mengganti dan menjalankan Agent.
3. Script hanya menghentikan proses yang memakai port 8765 jika nama proses dan baris perintahnya cocok dengan termuxq_agent.py. Jika port digunakan program lain, script berhenti tanpa menghentikan program tersebut.
4. Jika muncul **BERHASIL**, segarkan browser dengan Ctrl+F5, buka LAN Device Monitor, lalu coba lagi.

Script membutuhkan Windows PowerShell dan Python 3 yang dapat dipanggil lewat python atau py. Perbarui hanya dari repository resmi milik proyek. File Agent lama dicadangkan sebelum diganti.


### Perbaikan ZIP updater Windows
Jika versi lama menampilkan "Illegal characters in path" ketika membersihkan file sementara, gunakan ZIP terbaru. Script baru membersihkan tanda kutip di awal/akhir path, mengubah path file agent menjadi folder induknya jika perlu, dan tidak lagi menggunakan Test-Path pada blok pembersihan error sehingga pesan error awal tidak tertimpa. Ketika diminta, masukkan folder yang berisi termuxq_agent.py, bukan nama file .ps1 atau .bat.
