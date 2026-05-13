#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
SERVER_ROOT="/home/mcserver/spigot-server"
BACKUP_DIR="/home/mcserver/backups"
SESSION="addmcserver"

timestamp() {
  date +'%F_%H-%M'
}

echo "[INFO] Starting full backup at $(timestamp)…"

# Ensure backup folder exists
mkdir -p "$BACKUP_DIR"

# 1. Pause and flush world saves
screen -S "$SESSION" -p 0 -X stuff "save-off$(printf '\r')"
screen -S "$SESSION" -p 0 -X stuff "save-all$(printf '\r')"
sleep 5

# 2. Create a single archive of the entire server root
BACKUP_FILE="$BACKUP_DIR/fullbackup_$(timestamp).tar.gz"
tar czf "$BACKUP_FILE" \
    --exclude="$BACKUP_DIR" \
    -C "$SERVER_ROOT" .

# 3. Resume auto-saves
screen -S "$SESSION" -p 0 -X stuff "save-on$(printf '\r')"

# 4. Remove backups older than 7 days
find "$BACKUP_DIR" -type f -name 'fullbackup_*.tar.gz' -mtime +7 -delete

echo "[INFO] Full backup completed: $BACKUP_FILE"
