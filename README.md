# TermuxQ Next

Preview antarmuka (UI mockup) untuk toolkit IT Support TermuxQ. Satu halaman statis, tanpa dependensi dan tanpa backend.

> Modul yang bisa berjalan di browser bekerja sungguhan dan diproses lokal. Modul yang butuh Termux (SSH, Git, backup, port, WoL, dll.) menampilkan perintah untuk disalin. Angka di panel Dashboard dan log masih data contoh.

## Modul aktif di browser
Password generator, Hash checker (SHA), Encrypt/Decrypt (AES-GCM), Password Vault (terenkripsi, localStorage), JWT Inspector, Encode/Decode, Notes, To-Do, Network Info, Live Device, DNS Lookup (Cloudflare DoH), HTTP ping, Speed test (Cloudflare), Traffic latency, Matrix effect, Defense/Privacy checklist.

## Akses
https://basojhie.github.io/termuxq-next/

Di HP (Chrome): menu ⋮ > **Install app** / **Add to Home Screen** untuk memakainya seperti aplikasi, termasuk saat offline.

## Struktur
- `index.html` : seluruh UI (HTML + CSS + JS)
- `manifest.json`, `sw.js`, `icons/` : PWA (instal & offline)
- `.nojekyll` : menonaktifkan pemrosesan Jekyll di GitHub Pages

## Deploy
Settings > Pages > Source: *Deploy from a branch* > `main` / `(root)`.

## Catatan keamanan
Jangan commit token, password, atau konfigurasi pribadi ke repo publik.
