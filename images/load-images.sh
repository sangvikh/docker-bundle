#!/bin/bash
set -e

echo "--- Loading Docker Images ---"

for file in *.tar; do
    if [ -f "$file" ]; then
        # Check if already loaded
        image_name=$(docker image load --quiet -i "$file" | head -n1 | cut -d ':' -f1-2)
        if docker image inspect "$image_name" >/dev/null 2>&1; then
            echo "Skipping $image_name — already loaded"
        else
            echo "Loading $file..."
            docker load -i "$file"
        fi
    fi
done

echo "--- All Images Loaded ---"
