#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/basojhie/termuxq-next.git"
TARGET_DIR="${TERMUXQ_DIR:-$HOME/termuxq-next}"
BACKUP_ROOT="$HOME/.termuxq-backups"
STAMP="$(date +%Y%m%d_%H%M%S)"
SAVED_DIR=""

if [[ -z "${HOME:-}" || "$TARGET_DIR" == "/" || "$TARGET_DIR" == "$HOME" || -z "$TARGET_DIR" ]]; then
  echo "[ERROR] TERMUXQ_DIR mengarah ke lokasi yang tidak aman: $TARGET_DIR" >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  if command -v pkg >/dev/null 2>&1; then
    echo "[INFO] Memasang Git di Termux..."
    pkg install -y git
  else
    echo "[ERROR] Git belum terpasang. Instal Git terlebih dahulu lalu jalankan lagi." >&2
    exit 2
  fi
fi

mkdir -p "$(dirname "$TARGET_DIR")" "$BACKUP_ROOT"

make_backup() {
  local source_dir="$1"
  local archive="$BACKUP_ROOT/termuxq_$(basename "$TARGET_DIR")_${STAMP}.tar.gz"
  echo "[INFO] Membuat cadangan file lokal..." >&2
  tar -czf "$archive" --exclude=.git -C "$source_dir" .
  echo "$archive"
}

if [[ -d "$TARGET_DIR/.git" ]]; then
  ORIGIN="$(git -C "$TARGET_DIR" remote get-url origin 2>/dev/null || true)"
  case "$ORIGIN" in
    "https://github.com/basojhie/termuxq-next.git"|"https://github.com/basojhie/termuxq-next"|"git@github.com:basojhie/termuxq-next.git") ;;
    *)
      echo "[ERROR] Remote origin bukan repo resmi TermuxQ Next: $ORIGIN" >&2
      echo "Tidak ada perubahan pada folder lokal." >&2
      exit 3
      ;;
  esac
  if [[ "$(git -C "$TARGET_DIR" branch --show-current)" != "main" ]]; then
    echo "[ERROR] Repo lokal tidak berada di branch main. Tidak mengubah branch otomatis." >&2
    exit 3
  fi
  if [[ -n "$(git -C "$TARGET_DIR" status --porcelain)" ]]; then
    BACKUP="$(make_backup "$TARGET_DIR")"
    echo "[STOP] Ada perubahan lokal yang belum disimpan. Tidak ada file yang ditimpa."
    echo "Cadangan source: $BACKUP"
    echo "Simpan atau commit perubahan, lalu jalankan updater kembali."
    exit 4
  fi
  BACKUP="$(make_backup "$TARGET_DIR")"
  echo "[INFO] Mengambil commit terbaru..."
  git -C "$TARGET_DIR" fetch --prune origin main
  if ! git -C "$TARGET_DIR" merge-base --is-ancestor HEAD FETCH_HEAD; then
    echo "[STOP] Repo lokal memiliki riwayat berbeda; fast-forward tidak aman."
    echo "Cadangan source: $BACKUP"
    echo "Tidak ada merge paksa yang dilakukan."
    exit 5
  fi
  git -C "$TARGET_DIR" merge --ff-only FETCH_HEAD
else
  if [[ -e "$TARGET_DIR" ]]; then
    if [[ ! -d "$TARGET_DIR" ]]; then
      echo "[ERROR] Target ada tetapi bukan direktori: $TARGET_DIR" >&2
      exit 3
    fi
    BACKUP="$(make_backup "$TARGET_DIR")"
    SAVED_DIR="${TARGET_DIR}.backup.${STAMP}"
    mv "$TARGET_DIR" "$SAVED_DIR"
    echo "[INFO] Folder lama disimpan sebagai: $SAVED_DIR"
    echo "[INFO] Arsip cadangan: $BACKUP"
  fi
  echo "[INFO] Mengunduh repo resmi ke $TARGET_DIR ..."
  if ! git clone --branch main --single-branch "$REPO_URL" "$TARGET_DIR"; then
    echo "[ERROR] Clone gagal. Folder lama tetap tersedia pada lokasi backup." >&2
    if [[ -n "$SAVED_DIR" && -d "$SAVED_DIR" && ! -e "$TARGET_DIR" ]]; then mv "$SAVED_DIR" "$TARGET_DIR"; fi
    exit 6
  fi
fi

for required in index.html manifest.json sw.js termuxq_agent.py start_termuxq_live.sh; do
  if [[ ! -f "$TARGET_DIR/$required" ]]; then
    echo "[ERROR] File penting tidak ditemukan setelah pembaruan: $required" >&2
    exit 7
  fi
done

echo
echo "[OK] TermuxQ Next diperbarui."
git -C "$TARGET_DIR" log -1 --oneline
echo "Folder proyek : $TARGET_DIR"
echo "Jalankan live : bash \"$TARGET_DIR/start_termuxq_live.sh\""
echo "Dashboard     : http://127.0.0.1:8000"
