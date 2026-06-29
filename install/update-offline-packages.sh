#!/bin/bash
set -e

ARCH="$(dpkg --print-architecture)"
DISTRO="$(lsb_release -cs)"

PKG_DIR="$(dirname "$0")/packages/$ARCH"
mkdir -p "$PKG_DIR"

echo "--- Updating offline Docker packages ---"
echo "Architecture: $ARCH"
echo "Distro: $DISTRO"
echo "Target folder: $PKG_DIR"

# Temporary repo setup
echo "Adding Docker repo..."

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /tmp/docker.gpg
sudo mv /tmp/docker.gpg /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $DISTRO stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update

# Go directly into target directory
cd "$PKG_DIR"

# Docker packages to download
packages=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-compose-plugin
)

# Download .deb files
for pkg in "${packages[@]}"; do
    echo "Downloading $pkg..."
    apt-get download "$pkg"
done

# Cleanup repo
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg

echo "--- Offline packages updated for $ARCH ---"
