# TermuxQ Next

Preview antarmuka (UI mockup) untuk toolkit IT Support TermuxQ. Satu halaman statis, tanpa dependensi dan tanpa backend.

> Semua angka, log, dan tombol adalah **simulasi**. Halaman ini tidak menjalankan perintah Termux, scan jaringan, atau backup sungguhan.

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
