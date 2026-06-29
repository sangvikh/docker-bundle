#!/bin/bash
set -e

BACKUP_DIR="$(dirname "$0")"
echo "--- Docker Image Backup Started ---"

# Get all unique repositories
repos=$(docker image ls --format "{{.Repository}}" | sort | uniq)

if [ -z "$repos" ]; then
    echo "No images found. Exiting."
    exit 1
fi

echo "Found repositories to save:"
echo "$repos"

for repo in $repos; do
    # Find the first tag for this repo (optional)
    tag=$(docker image ls "$repo" --format "{{.Tag}}" | head -n1)
    image_to_save="$repo"
    [ "$tag" != "<none>" ] && image_to_save="$repo:$tag"

    # Convert to safe filename: slashes -> underscores, colons -> underscores
    safe_name=$(echo "$image_to_save" | sed 's|/|_|g' | sed 's|:|_|g')
    tar_file="$BACKUP_DIR/${safe_name}.tar"

    # Skip if backup exists
    if [ -f "$tar_file" ]; then
        echo "Skipping $image_to_save — backup already exists: $tar_file"
        continue
    fi

    echo "Saving $image_to_save -> $tar_file"
    docker save -o "$tar_file" "$image_to_save"
done

# Save digests for reference
docker images --digests > "$BACKUP_DIR/image-digests.txt"

echo "--- Image Backup Complete ---"
