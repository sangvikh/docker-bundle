#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

ARCH="$(dpkg --print-architecture)"
source /etc/os-release

case "$ID" in
    ubuntu)
        OS="ubuntu"
        DISTRO="$VERSION_CODENAME"
        ;;
    debian)
        OS="debian"
        DISTRO="$VERSION_CODENAME"
        ;;
    *)
        if [[ "$ID_LIKE" == *ubuntu* ]] && [[ -n "$UBUNTU_CODENAME" ]]; then
            OS="ubuntu"
            DISTRO="$UBUNTU_CODENAME"
        elif [[ "$ID_LIKE" == *debian* ]]; then
            OS="debian"
            DISTRO="$VERSION_CODENAME"
        else
            echo "Unsupported OS: $ID"
            exit 1
        fi
        ;;
esac

PKG_DIR="$DIR/packages/$OS/$ARCH/$DISTRO"
mkdir -p "$PKG_DIR"

KEYRING="/usr/share/keyrings/docker.gpg"
REPO_FILE="/etc/apt/sources.list.d/docker.list"

PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-compose-plugin
)

cleanup() {
    sudo rm -f "$REPO_FILE"
}

trap cleanup EXIT

echo "--- Updating offline Docker packages ---"
echo "Architecture : $ARCH"
echo "Distribution : $DISTRO"
echo "Target       : $PKG_DIR"

echo
echo "--- Cleaning old packages ---"

find "$PKG_DIR" -maxdepth 1 -type f -name "*.deb" -delete

echo
echo "--- Adding temporary Docker repository ---"

curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" \
| gpg --batch --yes --dearmor \
| sudo tee "$KEYRING" > /dev/null

echo "deb [arch=$ARCH signed-by=$KEYRING] https://download.docker.com/linux/$OS $DISTRO stable" \
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

