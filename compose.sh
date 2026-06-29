#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$SCRIPT_DIR/stacks"

find "$STACK_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while read -r dir; do
    if [[ -f "$dir/compose.yaml" ]] || \
       [[ -f "$dir/compose.yml" ]] || \
       [[ -f "$dir/docker-compose.yml" ]] || \
       [[ -f "$dir/docker-compose.yaml" ]]; then

        echo "===> $(basename "$dir")"
        (
            cd "$dir"
            docker compose "$@"
        )
    fi
done
