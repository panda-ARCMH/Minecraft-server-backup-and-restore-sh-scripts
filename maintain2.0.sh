#!/usr/bin/env bash
set -euo pipefail

# === CONFIG ===
SERVER_ROOT="/home/mcserver/paper-server"
BACKUP_DIR="/mnt/HC_Volume_103349558/backups2.0"

INCR_DIR="$BACKUP_DIR/incrementals"


mkdir -p "$BACKUP_DIR" "$INCR_DIR"
SESSION="addmcserver"
JAR="paper1.21.10.jar" # adjust to your jar name
HEAP_MIN="4G"
HEAP_MAX="8G"

timestamp() { date +'%F_%H-%M'; }
DATE=$(timestamp)
DAY_OF_WEEK=$(date +%u)  # 7 = Sunday






# === INITIALIZE BACKUPS2.0 IF NEEDED ===
if ! ls "$BACKUP_DIR"/full_* &>/dev/null; then
  echo "[INFO] No full backup directory found. Extracting latest .tar.gz to create one..."

  # Find latest .tar.gz archive from old backups
  LATEST_ARCHIVE=$(ls -t /home/mcserver/backups/fullbackup_*.tar.gz | head -1)
  if [ -z "$LATEST_ARCHIVE" ]; then
    echo "[ERROR] No .tar.gz backups found. Cannot initialize incremental system."
    exit 1
  fi

  # Extract it into backups2.0 as full_$DATE
  INIT_DATE=$(date +'%F_%H-%M')
  mkdir "$BACKUP_DIR/full_$INIT_DATE"
  tar xzf "$LATEST_ARCHIVE" -C "$BACKUP_DIR/full_$INIT_DATE"
  echo "[INFO] Extracted $LATEST_ARCHIVE into full_$INIT_DATE"
fi





# === BACKUP LOGIC ===
do_backup() {
  mkdir -p "$BACKUP_DIR"

  if [ "$DAY_OF_WEEK" -eq 7 ]; then
    echo "[INFO] $DATE: Performing full backup..."
    FULL_TAR="$BACKUP_DIR/fullbackup_$DATE.tar.gz"
    tar czf "$FULL_TAR" \
      --exclude="$BACKUP_DIR" \
      --checkpoint=.100 --checkpoint-action=echo="Processed %u files..." \
      -C "$SERVER_ROOT" .

    # Remove old extracted full backups to avoid clutter
    rm -rf "$BACKUP_DIR"/full_*

    # Extract the new full backup tarball to a fresh folder for incremental base
    mkdir "$BACKUP_DIR/full_$DATE"
    tar xzf "$FULL_TAR" -C "$BACKUP_DIR/full_$DATE"

  else
    echo "[INFO] $DATE: Performing incremental backup..."
    mkdir -p "$INCR_DIR"
    LATEST=$(find "$BACKUP_DIR" -maxdepth 1 -name 'full_*' | sort | tail -1)
    if [ -z "$LATEST" ]; then
      echo "[WARN] No full backup found. Falling back to full backup."
      tar czf "$BACKUP_DIR/fullbackup_$DATE.tar.gz" \
        --exclude="$BACKUP_DIR" \
        -C "$SERVER_ROOT" .
    else
      rsync -a --delete \
        --link-dest="$LATEST" \
        "$SERVER_ROOT/" "$INCR_DIR/incr_$DATE/"
    fi
  fi
}


# === SERVER STATE HANDLING ===
if screen -list | grep -q "$SESSION"; then
  echo "[INFO] $DATE: Notifying players of shutdown..."
  screen -S "$SESSION" -p 0 -X stuff "say Server will restart in 30 seconds$(printf '\r')"
  sleep 30

  echo "[INFO] $DATE: Pausing autosave & flushing worlds..."
  screen -S "$SESSION" -p 0 -X stuff "save-off$(printf '\r')"
  screen -S "$SESSION" -p 0 -X stuff "save-all$(printf '\r')"
  sleep 5

  do_backup

  echo "[INFO] $DATE: Stopping server..."
  screen -S "$SESSION" -p 0 -X stuff "stop$(printf '\r')"
  while screen -list | grep -q "$SESSION"; do sleep 2; done

  echo "[INFO] $DATE: Restarting server..."
  cd "$SERVER_ROOT"
  screen -dmS "$SESSION" java -Xms"$HEAP_MIN" -Xmx"$HEAP_MAX" -jar "$JAR" nogui
  sleep 10
  screen -S "$SESSION" -p 0 -X stuff "save-on$(printf '\r')"
  screen -S "$SESSION" -p 0 -X stuff "say Server autosave re-enabled$(printf '\r')"

elif pgrep -u mcserver -f "$JAR" >/dev/null; then
  echo "[WARN] $DATE: Server running outside screen. Backup only."
  do_backup

else
  echo "[INFO] $DATE: Server not running. Backup and start."
  do_backup

  echo "[INFO] $DATE: Starting server..."
  cd "$SERVER_ROOT"
  screen -dmS "$SESSION" java -Xms"$HEAP_MIN" -Xmx"$HEAP_MAX" -jar "$JAR" nogui
fi

# === CLEANUP ===
echo "[INFO] $DATE: Cleaning up old backups..."
find "$BACKUP_DIR" -type f -mtime +7 -name 'fullbackup_*.tar.gz' -delete
find "$INCR_DIR" -type d -mtime +7 -name 'incr_*' -exec rm -rf {} +

echo "[INFO] $DATE: Maintenance complete."
