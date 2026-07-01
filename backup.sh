#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_SH="$SCRIPT_DIR/compose.sh"

NAS_DIR="/mnt/sangvikh-nas/Backup/sangvikh-server/docker"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$NAS_DIR/docker_$TIMESTAMP.tar.gz"
BACKUP_KEEP=3

findmnt -T "$NAS_DIR" >/dev/null || {
    echo "Backup destination is not mounted!"
    exit 1
}

mkdir -p "$NAS_DIR"

echo "--- Complete Docker Stack Backup Started ---"
echo "Backup will be saved to: $BACKUP_FILE"

# Start containers again on exit
trap 'echo "Starting containers..."; "$COMPOSE_SH" up -d || true' EXIT

# Stop all stacks cleanly
echo "Stopping all containers..."
"$COMPOSE_SH" down

# Save currently available images
echo "Saving Docker images..."
"$SCRIPT_DIR/images/save-images.sh"

# Create archive
echo "Creating backup..."
sudo tar czf "$BACKUP_FILE" -C "$(dirname "$SCRIPT_DIR")" "$(basename "$SCRIPT_DIR")"

# Checksum
sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"

echo "Pruning old backups (keeping newest $BACKUP_KEEP)..."

backups=$(ls -1t "$NAS_DIR"/docker_*.tar.gz 2>/dev/null || true)

echo "$backups" \
    | tail -n +$((BACKUP_KEEP + 1)) \
    | while read -r old_backup; do
        [ -z "$old_backup" ] && continue

        echo "Removing old backup: $old_backup"
        rm -f "$old_backup"
        rm -f "${old_backup}.sha256"
    done

echo "--- Backup Complete ---"
