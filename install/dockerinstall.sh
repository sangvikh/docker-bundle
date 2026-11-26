#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source /etc/os-release

case "${ID:-}" in
    ubuntu|debian) OS="$ID" ;;
    *) echo "Unsupported OS: ${ID:-unknown}" >&2; exit 1 ;;
esac

DISTRO="${VERSION_CODENAME:-}"
[[ -n "$DISTRO" ]] || { echo "Could not determine distro codename." >&2; exit 1; }
ARCH="$(dpkg --print-architecture)"
PKG_DIR="$DIR/packages/$OS/$ARCH/$DISTRO"

echo "--- Docker Offline Installer ---"
echo "Architecture: $ARCH"
echo "Distribution: $OS $DISTRO"

if [[ ! -d "$PKG_DIR" ]]; then
    echo "ERROR: No package directory found: $PKG_DIR" >&2
    exit 1
fi

shopt -s nullglob
DEBS=("$PKG_DIR"/*.deb)
shopt -u nullglob
if ((${#DEBS[@]} == 0)); then
    echo "ERROR: No .deb packages found in: $PKG_DIR" >&2
    exit 1
fi

docker_deb=""
for deb in "${DEBS[@]}"; do
    if [[ "$(dpkg-deb -f "$deb" Package)" == docker-ce ]]; then
        docker_deb="$deb"
        break
    fi
done
if [[ -z "$docker_deb" ]]; then
    echo "ERROR: Bundle is missing the docker-ce package." >&2
    exit 1
fi

OFFLINE_VERSION="$(dpkg-deb -f "$docker_deb" Version)"
INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' docker-ce 2>/dev/null || true)"
PACKAGE_STATUS="$(dpkg-query -W -f='${db:Status-Abbrev}' docker-ce 2>/dev/null || true)"

echo "Installed docker-ce: ${INSTALLED_VERSION:-none} (${PACKAGE_STATUS:-not installed})"
echo "Bundle docker-ce  : $OFFLINE_VERSION"

NEEDS_INSTALL=0
if [[ "$PACKAGE_STATUS" != "ii " || -z "$INSTALLED_VERSION" ]]; then
    NEEDS_INSTALL=1
elif dpkg --compare-versions "$OFFLINE_VERSION" gt "$INSTALLED_VERSION"; then
    NEEDS_INSTALL=1
fi

if ((NEEDS_INSTALL)); then
    echo "Installing Docker packages from offline bundle..."
    if ! sudo dpkg -i "${DEBS[@]}"; then
        echo "ERROR: Package installation failed. The bundle may be missing dependencies." >&2
        echo "Add the missing target-distribution packages to the offline bundle and retry." >&2
        exit 1
    fi
else
    echo "docker-ce is installed at the bundle version."
fi

# A configured package and a running daemon are separate checks. Always enable
# and start the service, including when the client exists but the daemon does not.
sudo systemctl enable docker
sudo systemctl start docker

if ! sudo systemctl is-active --quiet docker; then
    echo "ERROR: Docker service did not become active." >&2
    sudo systemctl status docker --no-pager || true
    exit 1
fi

echo
echo "--- Docker version ---"
docker --version
docker compose version
echo "Docker daemon is active."

