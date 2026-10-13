# TermuxQ Next

TermuxQ Next adalah toolkit IT Support berbasis browser. Tool client-side berjalan langsung di browser; pembacaan CPU/RAM/storage/IP penuh memakai Python Agent lokal yang opsional. Menu yang memerlukan kemampuan sistem di luar browser memberikan panduan/perintah untuk disalin, bukan mengeksekusi shell bebas.

> Dashboard tidak menggunakan angka resource contoh. Ketika agent tidak terhubung, antarmuka membedakan metrik browser/jaringan dari statistik sistem yang belum tersedia. Log aktivitas menampilkan peristiwa sesi saat ini.

## Modul aktif di browser
Password generator, Hash checker (SHA), Encrypt/Decrypt (AES-GCM), Password Vault (terenkripsi di localStorage), JWT Inspector, Encode/Decode, Notes, To-Do, IT Support Ticket Log (localStorage + JSON import/export), IT Asset Inventory (localStorage + ping + JSON import/export), IT Operations Overview, IPv4 Subnet Calculator, Network Info, Live Device, DNS Lookup (Cloudflare DoH), HTTP response test, Speed test (Cloudflare), Traffic latency, Matrix effect, Defense/Privacy checklist.

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


Pembaruan path Windows (versi terbaru): launcher menormalisasi folder target tanpa garis miring terbalik penutup sebelum meneruskan argumen ke PowerShell. Updater juga membersihkan tanda kutip di tepi path dan menggunakan nama variabel proses yang tidak bentrok dengan variabel otomatis PowerShell `$PID`.


Pembaruan otomatis Windows versi terbaru memisahkan prompt lokasi Agent ke subroutine batch, sehingga input folder tidak tertimpa oleh ekspansi variabel lama. Launcher juga menormalkan folder target sebelum memanggil PowerShell agar tanda kutip penutup tidak melekat pada path.


Perbaikan lanjutan: jika ZIP diekstrak terpisah dari folder proyek, launcher meminta lokasi folder Agent melalui subroutine tersendiri agar input yang diketik tidak tergantikan oleh nilai variabel lama.


### Pesan `ConnectionAbortedError` di terminal Windows
Agent memakai server HTTP yang mengabaikan disconnect klien yang umum (`WinError 10053/10054`, `BrokenPipeError`, `ConnectionResetError`) saat browser membatalkan/memutus permintaan. Error server yang tidak dikenal tetap dicatat, jadi masalah tak terduga tidak disembunyikan.


## IT Asset Inventory (fitur terbaru)
Menu **IT Asset Inventory** membantu mencatat hingga 500 PC, laptop, printer, server, dan perangkat jaringan, berikut nama, zona/lokasi, IP privat, tipe, catatan, hasil ping terakhir, serta latensi bila tersedia. Fitur mendukung tambah/edit/hapus, pencarian, filter zona, ekspor dan impor JSON.

Data inventaris disimpan pada localStorage browser ini dan tidak otomatis tersinkron ke browser/perangkat lain. IP divalidasi ke jaringan privat RFC1918. Tombol **Ping tampil (maks. 24)** menguji maksimal 24 perangkat pada satu batch menggunakan Agent yang terhubung; filter pencarian/zona dapat digunakan untuk memilih subset perangkat. Gunakan hanya untuk perangkat/jaringan yang dimiliki atau diizinkan.


## IT Operations Overview

Modul **IT Operations Overview** merangkum jumlah aset, hasil ping terakhir (Online, No Reply, Belum dicek, Error), tiket yang belum selesai, tiket prioritas High/Critical, serta tiket Resolved. Modul juga menampilkan beberapa tiket terbaru yang belum selesai dan aset yang perlu diperiksa.

Dashboard hanya membaca `tq_asset_inventory_v1` dan `tq_tickets` dari `localStorage` browser yang sedang digunakan. Status perangkat adalah hasil pemeriksaan terakhir—modul tidak melakukan ping otomatis. Karena itu, ringkasan pada perangkat lain bisa berbeda sampai sinkronisasi database bersama diterapkan pada tahap berikutnya.


## Cloud Sync antar-perangkat (Supabase)

Modul **Cloud Sync (Supabase)** akan menyatukan data IT Asset Inventory dan IT Support Ticket Log di beberapa browser/perangkat melalui Supabase Auth + REST API.

### Setup satu kali

1. Buat project di Supabase.
2. Buka **SQL Editor**, jalankan seluruh isi file [`supabase/schema.sql`](./supabase/schema.sql) untuk membuat tabel dan aturan Row Level Security (RLS).
3. Buka pengaturan API pada project, salin Project URL serta **publishable key** (atau legacy `anon` key). Jangan pernah gunakan `service_role` atau secret key di website publik.
4. Di TermuxQ, buka **Cloud Sync (Supabase)**, masukkan Project URL dan key, lalu simpan konfigurasi. Konfigurasi berlaku untuk browser tersebut.
5. Buat akun melalui modul atau gunakan akun yang sudah dibuat. Jika verifikasi email diaktifkan, konfirmasi dahulu.
6. Login dengan akun yang sama pada komputer 72 dan perangkat lain. Tekan **Sinkronkan sekarang** untuk menggabungkan data; jalankan lagi setelah perubahan aset/tiket.

### Keamanan dan batasan

- RLS membatasi row ke akun login yang sama melalui `auth.uid() = user_id`.
- Sinkronisasi dilakukan manual sehingga data tidak dikirim ke cloud di latar belakang tanpa tindakan pengguna.
- Konflik pada record yang sama memilih versi lokal di perangkat yang sedang sinkron; lakukan sync bergantian.
- Penghapusan memakai penanda agar tersebar pada sinkronisasi berikutnya.
- Sesi dan konfigurasi tersimpan di browser masing-masing. Jangan menonaktifkan RLS dan jangan memasukkan `service_role` atau secret key ke kode publik.


## Audit Trail / Activity Log

Menu **Audit Trail / Activity Log** mencatat aktivitas penting di browser saat ini, termasuk membuat/mengubah/menghapus tiket, mengubah status tiket, menambah/mengedit/menghapus aset, pemeriksaan ping, impor/ekspor JSON, dan sinkronisasi cloud. Riwayat menyimpan waktu, jenis objek, tindakan, serta ringkasan—bukan password, publishable key, atau isi rahasia.

Riwayat dibatasi hingga 500 aktivitas terakhir, dapat dicari/filter dan diekspor sebagai JSON. Log bersifat lokal per-browser pada `tq_audit_log_v1`; fitur ini belum menyalin audit log ke database Supabase. Gunakan ekspor berkala bila catatan perlu disimpan lebih lama.


## SLA & Ticket Priority Monitoring

Menu **SLA & Ticket Priority Monitoring** menghitung target respons pertama dan penyelesaian berdasarkan prioritas tiket (**Critical**, **High**, **Normal**, **Low**) serta jam/hari kerja yang dapat diatur. Contoh target awal: Critical 15 menit/2 jam kerja; High 30 menit/4 jam kerja; Normal 4 jam/1 hari kerja; Low 1 hari kerja/3 hari kerja. Angka ini adalah contoh dan harus disesuaikan dengan kebijakan perusahaan sebelum digunakan sebagai SLA resmi.

- Atur mulai/akhir kerja dan hari kerja. Jam di luar rentang serta hari nonkerja tidak dihitung; kalender hari libur/cuti belum didukung.
- Pada **IT Support Ticket Log**, tekan **Catat respons** saat petugas memberikan tanggapan pertama. Ini menyimpan `firstResponseAt`.
- Saat status tiket berubah menjadi **Resolved**, `resolvedAt` dicatat otomatis. Jika tiket dibuka kembali, waktu selesai dihapus sampai tiket diselesaikan lagi.
- Dasbor menunjukkan respons/penyelesaian yang melewati target, tenggat dalam 60 menit kerja, dan tiket yang selesai sesuai SLA.
- Target tersimpan di `tq_sla_config_v1` dan tiket tetap menggunakan penyimpanan lokal. Pengaturan SLA dan hasil tidak otomatis dibagikan ke browser lain hingga alur sinkronisasi digunakan.


## Ticket workflow, SLA analytics, dan notifikasi

### Workflow tiket
IT Support Ticket Log mencatat penanggung jawab/teknisi, kategori, catatan troubleshooting, alasan status Waiting, riwayat perpindahan status, waktu pembaruan, dan jumlah tiket yang dibuka kembali. Tiket lama dibaca dengan nilai default; ekspor baru menggunakan skema versi 3 dan membawa catatan serta riwayat status.

### SLA Reporting & Analytics
Modul laporan merangkum jumlah tiket aktif, kepatuhan respons/penyelesaian, rata-rata durasi pada jam kerja, tiket yang pernah dibuka kembali, tren harian tujuh hari, dan kategori. Ekspor menghasilkan CSV yang dapat dibuka di Excel. Nilai kepatuhan berdasarkan timestamp dan target SLA yang tersimpan; kalender hari libur/cuti belum didukung.

### Ticket Notification Center dan Telegram
Pusat notifikasi menampilkan tiket Critical/High, deadline respons/penyelesaian yang dekat atau terlewat, serta tiket Waiting lebih dari 24 jam. Desktop notifications memerlukan izin pengguna dan hanya bekerja saat halaman dibuka. Pengiriman Telegram dipicu dengan tombol, memakai sesi Supabase yang valid serta Edge Function server-side.

Untuk mengaktifkan Telegram, deploy fungsi supabase/functions/ticket-notify/index.ts dan simpan TELEGRAM_BOT_TOKEN serta TELEGRAM_CHAT_ID sebagai Supabase Edge Function secrets. Jangan pernah memasukkan token bot pada HTML, localStorage, atau commit. Endpoint memvalidasi sesi pengguna sebelum mengirim. Pengiriman otomatis saat halaman tertutup belum diaktifkan.

### Perluasan Cloud Sync
Cloud Sync juga menyertakan Audit Trail (tipe audit) dan konfigurasi SLA (tipe setting dengan ID tetap sla-config). Pada project yang sudah dipakai, jalankan supabase/migrations/20261013_ticket_workflow.sql sekali di SQL Editor. Pada project baru, jalankan supabase/schema.sql yang telah diperbarui. RLS membatasi record kepada akun yang login; versi ini menyinkronkan antar-perangkat dengan akun yang sama, bukan role organisasi lintas akun.
