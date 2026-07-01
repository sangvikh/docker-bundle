#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$(dirname "$0")"

archive_name() {
    local image="$1"
    local id="$2"

    local repo="${image%%:*}"
    local tag="${image##*:}"

    if [[ "$repo" == "<none>" ]]; then
        echo "untagged_${id}"
    elif [[ "$tag" == "<none>" ]]; then
        echo "${repo}:backup" | sed 's|/|_|g' | sed 's|:|_|g'
    else
        echo "$image" | sed 's|/|_|g' | sed 's|:|_|g'
    fi
}

echo "--- Docker Image Backup Started ---"

mkdir -p "$BACKUP_DIR"

# Get all images
images=$(docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | sort)

if [ -z "$images" ]; then
    echo "No images found. Exiting."
    exit 1
fi

echo "Found images:"
echo "$images"
echo

while read -r image id; do

    safe_name=$(archive_name "$image" "$id")

    repo="${image%%:*}"
    tag="${image##*:}"

    if [[ "$repo" == "<none>" ]]; then
        image_ref="$id"

    elif [[ "$tag" == "<none>" ]]; then
        image_ref="${repo}:backup"

        if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
            echo "Tagging $id as $image_ref"
            docker tag "$id" "$image_ref"
        fi

    else
        image_ref="$image"
    fi

    tar_file="$BACKUP_DIR/${safe_name}.tar"
    digest_file="$BACKUP_DIR/${safe_name}.digest"

    current_digest=$(docker inspect --format='{{.Id}}' "$id")

    if [ -f "$digest_file" ]; then
        saved_digest=$(cat "$digest_file")

        if [ "$saved_digest" == "$current_digest" ]; then
            echo "Skipping $image_ref — unchanged"
            continue
        fi

        echo "Image changed: $image_ref"
    else
        echo "New image: $image_ref"
    fi

    echo "Saving $image_ref -> $tar_file"

    docker save -o "$tar_file" "$image_ref"

    echo "$current_digest" > "$digest_file"

done <<< "$images"

docker images --digests > "$BACKUP_DIR/image-digests.txt"

echo "--- Image Backup Complete ---"

echo
echo "--- Image archives not matching current images ---"

current_archives=""

while read -r image id; do
    safe_name=$(archive_name "$image" "$id")
    current_archives+="${safe_name}.tar"$'\n'
done <<< "$images"

found_old=false

for archive in "$BACKUP_DIR"/*.tar; do
    [ -e "$archive" ] || continue

    filename=$(basename "$archive")

    if ! grep -qxF "$filename" <<< "$current_archives"; then
        echo "Old archive candidate: $filename"
        found_old=true
    fi
done

if [ "$found_old" = false ]; then
    echo "None"
fi
