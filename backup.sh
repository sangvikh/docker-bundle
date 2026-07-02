#!/usr/bin/env bash
set -euo pipefail
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_SH="$SCRIPT_DIR/compose.sh"

NAS_DIR="/mnt/sangvikh-nas/Backup/sangvikh-server/docker"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$NAS_DIR/docker_$TIMESTAMP.tar.gz"
BACKUP_KEEP=3

LOG_FILE="$SCRIPT_DIR/backup.log"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

findmnt -T "$NAS_DIR" >/dev/null || {
    echo "Backup destination is not mounted!"
    exit 1
}

cleanup() {
    status=$?

    if [ "$status" -ne 0 ]; then
        echo "--- FAILED: Complete Docker Stack Backup, $(date) (exit status $status) ---"

        rm -f "$BACKUP_FILE.partial"
        rm -f "$BACKUP_FILE"
        rm -f "$BACKUP_FILE.sha256"
    else
        echo "--- SUCCESS: Complete Docker Stack Backup, $(date) ---"
    fi

    echo
    echo "=============================="
    echo "Starting containers..."
    echo "=============================="
    "$COMPOSE_SH" up -d || true

    exit $status
}

trap cleanup EXIT INT TERM HUP

mkdir -p "$NAS_DIR"

echo "--- START: Complete Docker Stack Backup, $(date) ---"
echo "Backup will be saved to: $BACKUP_FILE"

# Save currently available images
echo
echo "=============================="
echo "Saving Docker images..."
echo "=============================="
"$SCRIPT_DIR/images/save-images.sh"

# Stop all stacks cleanly
echo
echo "=============================="
echo "Stopping all containers..."
echo "=============================="
"$COMPOSE_SH" down

# Create archive
echo
echo "=============================="
echo "Creating backup..."
echo "=============================="
tar \
    --checkpoint=1000 \
    --checkpoint-action=ttyout=">>> tar progress: %u files archived\r" \
    --totals \
    -czf "$BACKUP_FILE.partial" \
    -C "$(dirname "$SCRIPT_DIR")" \
    "$(basename "$SCRIPT_DIR")"

mv "$BACKUP_FILE.partial" "$BACKUP_FILE"

# Checksum
echo
echo "=============================="
echo "Creating checksum..."
echo "=============================="
sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"
echo "Checksum:"
cat "$BACKUP_FILE.sha256"

echo
echo "=============================="
echo "Pruning old backups (keeping newest $BACKUP_KEEP)..."
echo "=============================="

backups=$(ls -1t "$NAS_DIR"/docker_*.tar.gz 2>/dev/null || true)

echo "$backups" \
    | tail -n +$((BACKUP_KEEP + 1)) \
    | while read -r old_backup; do
        [ -z "$old_backup" ] && continue

        echo "Removing old backup: $old_backup"
        rm -f "$old_backup"
        rm -f "${old_backup}.sha256"
    done

echo "Prune complete"

echo
echo "=============================="
echo "Current backups:"
echo "=============================="
ls -lh "$NAS_DIR"/docker_*.tar.gz 2>/dev/null || echo "None found"
echo
