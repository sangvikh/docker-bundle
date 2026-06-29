#!/bin/bash
set -e

ARCH="$(dpkg --print-architecture)"
PKG_DIR="$(dirname "$0")/packages/$ARCH"

echo "--- Checking Docker installation ---"

if command -v docker &>/dev/null; then
    echo "Docker is already installed: $(docker --version)"
else
    echo "Docker not found. Installing offline packages..."

    if [ ! -d "$PKG_DIR" ]; then
        echo "ERROR: No packages found for architecture: $ARCH"
        echo "Expected directory: $PKG_DIR"
        exit 1
    fi

    echo "Using packages from: $PKG_DIR"

    # Install all .deb files for this architecture
    sudo dpkg -i "$PKG_DIR"/*.deb || sudo apt-get install -f -y

    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker

    echo "--- Docker Installation Complete ---"
    docker --version
    docker compose version
fi
