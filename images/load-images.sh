#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_ROOT="$SCRIPT_DIR"
OS="$(docker info --format '{{.OSType}}')"
ARCH="$(docker info --format '{{.Architecture}}')"

case "$ARCH" in
  x86_64|x86-64) ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  armv7l) ARCH=arm/v7 ;;
  armv6l) ARCH=arm/v6 ;;
  i386|i686) ARCH=386 ;;
esac

PLATFORM_DIR="$IMAGE_ROOT/$OS/$ARCH"
echo "=== Loading image archives for $OS/$ARCH ==="
echo "Directory: $PLATFORM_DIR"

if [[ ! -d "$PLATFORM_DIR" ]]; then
  echo "ERROR: No image archive directory for $OS/$ARCH: $PLATFORM_DIR" >&2
  exit 1
fi

found=false
for archive in "$PLATFORM_DIR"/*.tar; do
  [[ -e "$archive" ]] || continue
  found=true
  echo "Loading $(basename "$archive")"
  docker load -i "$archive"
done

if [[ "$found" == false ]]; then
  echo "ERROR: No .tar archives found for $OS/$ARCH in $PLATFORM_DIR" >&2
  exit 1
fi

echo "All image archives loaded for $OS/$ARCH."

