#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- Loading Docker Images ---"

shopt -s nullglob

for file in "$SCRIPT_DIR"/*.tar; do
    echo "Loading $(basename "$file")..."
    docker load -i "$file"
done

echo "--- All Images Loaded ---"
