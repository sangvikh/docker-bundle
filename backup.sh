#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_SH="$SCRIPT_DIR/compose.sh"

NAS_DIR="/mnt/sangvikh-nas/Backup/sangvikh-server/docker"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$NAS_DIR/docker_$TIMESTAMP.tar.gz"

mkdir -p "$NAS_DIR"

echo "--- Complete Docker Stack Backup Started ---"
echo "Backup will be saved to: $BACKUP_FILE"

# Stop all stacks cleanly
echo "Stopping all containers..."
"$COMPOSE_SH" down
trap '"$COMPOSE_SH" up -d' EXIT

# Create archive
echo "Creating backup..."
sudo tar czf "$BACKUP_FILE" -C "$(dirname "$SCRIPT_DIR")" "$(basename "$SCRIPT_DIR")"

# Start everything again
echo "Starting all containers..."
"$COMPOSE_SH" up -d

# Checksum
sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"

echo "--- Backup Complete ---"
