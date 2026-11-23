#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORMS="${PLATFORMS:-linux/amd64 linux/arm64}"
PULL_ADDITIONAL_PLATFORMS=0

usage() {
  cat <<'USAGE'
Usage: save-images.sh [OPTIONS]

Save images already present locally for this host's platform.

Options:
  --pull-additional-platforms  Also pull and save the current registry tag for
                               each configured non-host platform.
  --platforms LIST             Platforms to include, comma-separated.
                               Default: linux/amd64,linux/arm64
  -h, --help                   Show this help.

Example:
  ./save-images.sh --pull-additional-platforms
USAGE
}

while (($#)); do
  case "$1" in
    --pull-additional-platforms|--additional-platforms)
      PULL_ADDITIONAL_PLATFORMS=1
      shift
      ;;
    --platforms)
      if (($# < 2)); then
        echo "ERROR: --platforms requires a comma-separated list." >&2
        exit 2
      fi
      PLATFORMS="${2//,/ }"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done
HOST_OS="$(docker info --format '{{.OSType}}')"
HOST_ARCH="$(docker info --format '{{.Architecture}}')"
case "$HOST_ARCH" in
  x86_64|x86-64) HOST_ARCH=amd64 ;;
  aarch64) HOST_ARCH=arm64 ;;
  armv7l) HOST_ARCH=arm/v7 ;;
  armv6l) HOST_ARCH=arm/v6 ;;
  i386|i686) HOST_ARCH=386 ;;
esac
HOST_PLATFORM="$HOST_OS/$HOST_ARCH"
DRIVER_STATUS="$(docker info --format '{{.DriverStatus}}')"
if [[ "$DRIVER_STATUS" == *io.containerd.snapshotter* ]]; then
  MULTIPLATFORM_STORE=1
else
  MULTIPLATFORM_STORE=0
fi

archive_name() {
  local image="$1"
  local id="$2"
  local repo="${image%%:*}"
  local tag="${image##*:}"

  if [[ "$repo" == "<none>" ]]; then
    printf 'untagged_%s' "$id"
  elif [[ "$tag" == "<none>" ]]; then
    printf '%s' "${repo}:backup" | sed 's|/|_|g; s|:|_|g'
  else
    printf '%s' "$image" | sed 's|/|_|g; s|:|_|g'
  fi
}

echo "--- Docker Image Backup Started ---"
echo "Host platform: $HOST_PLATFORM"
echo "Target platforms: $PLATFORMS"
echo "Pull additional platforms: $PULL_ADDITIONAL_PLATFORMS"
mkdir -p "$BACKUP_DIR"

# Clean temporary files left if an older/non-atomic save was interrupted.
find "$BACKUP_DIR" -type f -name '*.tar.partial.*' -delete

images="$(docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | sort -u)"
if [[ -z "$images" ]]; then
  echo "No images found. Exiting."
  exit 1
fi

echo "Found local images:"
echo "$images"
echo

declare -A current_archive_names=()

while read -r image id; do
  [[ -n "${image:-}" ]] || continue

  repo="${image%%:*}"
  tag="${image##*:}"
  if [[ "$repo" == "<none>" ]]; then
    image_ref="$id"
    is_registry_ref=0
  elif [[ "$tag" == "<none>" ]]; then
    image_ref="${repo}:backup"
    is_registry_ref=0
    if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
      echo "Tagging local image $id as $image_ref"
      docker tag "$id" "$image_ref"
    fi
  else
    image_ref="$image"
    is_registry_ref=1
  fi

  safe_name="$(archive_name "$image" "$id")"
  current_archive_names["${safe_name}.tar"]=1

  for platform in $PLATFORMS; do
    platform_dir="$BACKUP_DIR/$platform"
    mkdir -p "$platform_dir"

    # For the native platform, save the exact local image already used by the
    # current workflow. For other platforms, only pull when explicitly enabled.
    if [[ "$platform" == "$HOST_PLATFORM" ]]; then
      source_ref="$image_ref"
      if [[ "$MULTIPLATFORM_STORE" == "1" ]]; then
        source_id="$(docker image inspect --platform="$platform" --format='{{.Id}}' "$image_ref")"
      else
        source_id="$(docker image inspect --format='{{.Id}}' "$image_ref")"
      fi
    elif [[ "$PULL_ADDITIONAL_PLATFORMS" == "1" && "$is_registry_ref" == "1" ]]; then
      echo "Pulling $image_ref for $platform"
      if ! docker pull --platform="$platform" "$image_ref"; then
        echo "WARNING: Could not pull $image_ref for $platform; skipping."
        continue
      fi
      source_ref="$image_ref"
      if [[ "$MULTIPLATFORM_STORE" == "1" ]]; then
        source_id="$(docker image inspect --platform="$platform" --format='{{.Id}}' "$image_ref")"
      else
        source_id="$(docker image inspect --format='{{.Id}}' "$image_ref")"
      fi
    else
      continue
    fi

    tar_file="$platform_dir/${safe_name}.tar"
    digest_file="$platform_dir/${safe_name}.digest"
    current_digest="$source_id"

    if [[ -f "$digest_file" && -s "$tar_file" ]]; then
      saved_digest="$(cat "$digest_file")"
      saved_digest="${saved_digest#sha256:}"
      normalized_current_digest="${current_digest#sha256:}"

      # Older versions stored Docker's 12-character image ID. Accept it as a
      # prefix of the full config digest, then normalize the sidecar file.
      if [[ -n "$saved_digest" && "$normalized_current_digest" == "$saved_digest"* ]]; then
        printf '%s\n' "$current_digest" > "$digest_file"
        echo "Skipping $source_ref [$platform] — unchanged"
        continue
      fi
    fi

    echo "Saving $source_ref [$platform] -> $tar_file"
    tmp_tar="$tar_file.partial.$$"
    tmp_digest="$digest_file.partial.$$"
    if [[ "$MULTIPLATFORM_STORE" == "1" ]]; then
      docker save --platform="$platform" -o "$tmp_tar" "$source_ref"
    else
      docker save -o "$tmp_tar" "$source_ref"
    fi
    mv -f "$tmp_tar" "$tar_file"
    printf '%s\n' "$current_digest" > "$tmp_digest"
    mv -f "$tmp_digest" "$digest_file"
  done
done <<< "$images"

docker images --digests > "$BACKUP_DIR/image-digests.txt"

# On the classic image store, pulling a foreign platform can replace the local
# tag. Reload the native archives so the host's tags are ready for Compose again.
if [[ "$PULL_ADDITIONAL_PLATFORMS" == "1" ]]; then
  native_dir="$BACKUP_DIR/$HOST_PLATFORM"
  if [[ -d "$native_dir" ]]; then
    echo "Restoring host-platform image tags from $native_dir"
    for tar_file in "$native_dir"/*.tar; do
      [[ -e "$tar_file" ]] || continue
      docker load -i "$tar_file"
    done
  fi
fi

echo
echo "--- Image Backup Complete ---"
echo "Archives are grouped under $BACKUP_DIR/<os>/<architecture>/"

echo
echo "--- Image archives not matching current images ---"
found_old=false
for platform in $PLATFORMS; do
  platform_dir="$BACKUP_DIR/$platform"
  [[ -d "$platform_dir" ]] || continue
  for archive in "$platform_dir"/*.tar; do
    [[ -e "$archive" ]] || continue
    filename="$(basename "$archive")"
    if [[ -z "${current_archive_names[$filename]+present}" ]]; then
      echo "Old archive candidate: $platform/$filename"
      found_old=true
    fi
  done
done

if [[ "$found_old" == false ]]; then
  echo "None"
fi

