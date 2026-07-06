#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Deploying Docker Stack ==="
echo "Source: $SCRIPT_DIR"

# ----------------------------
# 1. Install Docker (if needed)
# ----------------------------
if [ -x "$SCRIPT_DIR/install/dockerinstall.sh" ]; then
    echo
    echo "=== Installing Docker ==="
    (cd "$SCRIPT_DIR/install" && sudo ./dockerinstall.sh)
fi

# ----------------------------
# 2. Load images
# ----------------------------
echo
echo "=== Loading images ==="

if [ -x "$SCRIPT_DIR/images/load-images.sh" ]; then
    bash "$SCRIPT_DIR/images/load-images.sh"
fi

# ----------------------------
# 3. Start stacks
# ----------------------------
echo
echo "=== Starting stacks ==="

if [ -x "$SCRIPT_DIR/compose.sh" ]; then
    bash "$SCRIPT_DIR/compose.sh" up -d
fi

echo
echo "=== Deploy complete ==="
