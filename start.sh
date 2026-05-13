#!/bin/bash
cd "$(dirname "$0")"

# === CONFIG ===
JAR="spigot-1.21.8.jar"
SESSION="addmcserver"
LOGFILE="server.log"

# === CLEANUP ===
echo "[INFO] Cleaning up session locks..."
find . -name session.lock -exec rm -f {} \;

# === CHECK IF SERVER IS ALREADY RUNNING ===
if screen -list | grep -q "$SESSION"; then
  echo "[WARN] Server is already running in screen session '$SESSION'."
  exit 1
fi

# === START SERVER ===
echo "[INFO] Starting Minecraft server..."
screen -dmS "$SESSION" bash -c "java -Xms2G -Xmx6G -jar \"$JAR\" nogui | tee -a \"$LOGFILE\""

