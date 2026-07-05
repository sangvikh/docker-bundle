#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

ARCH="$(dpkg --print-architecture)"
DISTRO="$(lsb_release -cs)"

PKG_DIR="$DIR/packages/$ARCH"
mkdir -p "$PKG_DIR"

KEYRING="/usr/share/keyrings/docker-archive-keyring.gpg"
REPO_FILE="/etc/apt/sources.list.d/docker.list"

PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-compose-plugin
)

cleanup() {
    sudo rm -f "$REPO_FILE"
    sudo rm -f "$KEYRING"
}

trap cleanup EXIT

echo "--- Updating offline Docker packages ---"
echo "Architecture : $ARCH"
echo "Distribution : $DISTRO"
echo "Target       : $PKG_DIR"

echo
echo "--- Cleaning old packages ---"

rm -f \
    "$PKG_DIR"/docker-ce_*.deb \
    "$PKG_DIR"/docker-ce-cli_*.deb \
    "$PKG_DIR"/containerd.io_*.deb \
    "$PKG_DIR"/docker-compose-plugin_*.deb

echo
echo "--- Adding temporary Docker repository ---"

curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" \
    | gpg --dearmor -o /tmp/docker.gpg

sudo mv /tmp/docker.gpg "$KEYRING"

echo "deb [arch=$ARCH signed-by=$KEYRING] https://download.docker.com/linux/ubuntu $DISTRO stable" \
    | sudo tee "$REPO_FILE" >/dev/null

sudo apt update

echo
echo "--- Downloading packages ---"

(
    cd "$PKG_DIR"

    for pkg in "${PACKAGES[@]}"; do
        echo "Downloading $pkg..."
        apt-get download "$pkg"
    done
)

echo
echo "--- Verifying downloads ---"

for pkg in "${PACKAGES[@]}"; do
    if ! ls "$PKG_DIR"/"$pkg"_*.deb >/dev/null 2>&1; then
        echo "ERROR: Failed to download $pkg"
        exit 1
    fi
done

echo
echo "--- Offline packages updated successfully ---"

