#!/usr/bin/env bash
set -euo pipefail

NAS_DIR="${NAS_DIR:-/mnt/sangvikh-nas/Backup/sangvikh-server/docker}"
WORKDIR="${WORKDIR:-$HOME/docker-restored}"

# ----------------------------
# Find backup argument or enter interactive mode
# ----------------------------
BACKUP="${1:-}"

if [ -z "$BACKUP" ]; then
    echo "=== Available backups ==="
    echo

    mapfile -t BACKUPS < <(ls -1t "$NAS_DIR"/docker_*.tar.zst 2>/dev/null || true)

    if [ "${#BACKUPS[@]}" -eq 0 ]; then
        echo "No backups found in $NAS_DIR"
        exit 1
    fi

    PS3="Select backup to restore: "
    select opt in "${BACKUPS[@]}"; do
        if [ -n "${opt:-}" ]; then
            BACKUP="$(basename "$opt")"
            break
        else
            echo "Invalid selection"
        fi
    done
fi

BACKUP_PATH="$NAS_DIR/$BACKUP"

echo
echo "=== Recovering backup ==="
echo "NAS_DIR: $NAS_DIR"
echo "WORKDIR: $WORKDIR"
echo "Backup:  $BACKUP_PATH"

# ----------------------------
# Verify checksum
# ----------------------------
echo
echo "=== Verifying backup ==="

if [ ! -f "$BACKUP_PATH.sha256" ]; then
    echo "ERROR: Missing checksum file"
    exit 1
fi

(
    cd "$NAS_DIR"
    if ! sha256sum -c "$(basename "$BACKUP_PATH.sha256")"; then
        echo "ERROR: Checksum verification FAILED"
        exit 1
    fi
)

# ----------------------------
# Extract target
# ----------------------------
DEST="$WORKDIR/${BACKUP%.tar.zst}"

echo
echo "=== Extract target ==="
echo "Destination: $DEST"

echo
echo "⚠️  This will:"
echo "   - delete $DEST if it exists"
echo "   - extract backup contents into it"
echo

read -rp "Type YES to proceed with restore: " confirm
[[ "$confirm" == "YES" ]] || {
    echo "Aborted."
    exit 1
}

# ----------------------------
# Safe cleanup + extract
# ----------------------------
rm -rf "$DEST"
mkdir -p "$DEST"

echo
echo "=== Extracting backup ==="

tar --zstd -xf "$BACKUP_PATH" -C "$DEST"

echo
echo "Recovered to: $DEST"
echo "Next step: cd \"$DEST\" && ./deploy.sh"
