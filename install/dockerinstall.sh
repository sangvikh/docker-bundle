#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

ARCH="$(dpkg --print-architecture)"
PKG_DIR="$DIR/packages/$ARCH"

echo "--- Docker Offline Installer ---"
echo "Architecture: $ARCH"

if [ ! -d "$PKG_DIR" ]; then
    echo "ERROR: No package directory found:"
    echo "  $PKG_DIR"
    exit 1
fi

shopt -s nullglob
DEBS=("$PKG_DIR"/*.deb)
shopt -u nullglob

if [ ${#DEBS[@]} -eq 0 ]; then
    echo "ERROR: No .deb packages found in:"
    echo "  $PKG_DIR"
    exit 1
fi

install_docker() {
    echo "Installing Docker packages..."

    sudo dpkg -i "${DEBS[@]}" || sudo apt-get install -f -y

    sudo systemctl enable docker
    sudo systemctl start docker

    echo
    echo "--- Docker version ---"
    docker --version
    docker compose version
}

if command -v docker >/dev/null 2>&1; then
    INSTALLED_VERSION="$(docker version --format '{{.Server.Version}}' 2>/dev/null || docker --version | awk '{print $3}' | tr -d ',')"

    PACKAGE="$(basename "$PKG_DIR"/docker-ce_*.deb)"
    OFFLINE_VERSION="${PACKAGE#docker-ce_}"
    OFFLINE_VERSION="${OFFLINE_VERSION%%-*}"
    OFFLINE_VERSION="${OFFLINE_VERSION#5%3a}"

    echo "Installed : $INSTALLED_VERSION"
    echo "Offline   : $OFFLINE_VERSION"

    if dpkg --compare-versions "$OFFLINE_VERSION" gt "$INSTALLED_VERSION"; then
        echo "Offline bundle is newer. Upgrading..."
        install_docker
    else
        echo "Docker is already up to date."
    fi
else
    echo "Docker not found."
    install_docker
fi

