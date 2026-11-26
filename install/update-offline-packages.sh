#!/usr/bin/env bash
set -Eeuo pipefail

# Download Docker Engine packages for this machine's architecture and one or
# more Ubuntu/Debian codenames. Examples:
#   ./update-offline-packages.sh
#   ./update-offline-packages.sh trixie bookworm
#   ./update-offline-packages.sh noble jammy

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="$(dpkg --print-architecture)"

if [[ $# -gt 0 ]]; then
    DISTROS=("$@")
else
    source /etc/os-release
    case "${ID:-}" in
        ubuntu)
            OS=ubuntu
            HOST_DISTRO="${VERSION_CODENAME:-}"
            ;;
        debian)
            OS=debian
            HOST_DISTRO="${VERSION_CODENAME:-}"
            ;;
        *)
            if [[ " ${ID_LIKE:-} " == *" ubuntu "* ]] && [[ -n "${UBUNTU_CODENAME:-}" ]]; then
                OS=ubuntu
                HOST_DISTRO="$UBUNTU_CODENAME"
            elif [[ " ${ID_LIKE:-} " == *" debian "* ]] && [[ -n "${VERSION_CODENAME:-}" ]]; then
                OS=debian
                HOST_DISTRO="$VERSION_CODENAME"
            else
                echo "Unsupported OS: ${ID:-unknown}. Pass one or more distro codenames and set DOCKER_OS=ubuntu or debian." >&2
                exit 1
            fi
            ;;
    esac
    [[ -n "$HOST_DISTRO" ]] || { echo "Could not determine host distro codename." >&2; exit 1; }
    DISTROS=("$HOST_DISTRO")
fi

OS="${DOCKER_OS:-${OS:-}}"
if [[ -z "$OS" ]]; then
    echo "When specifying codenames, set DOCKER_OS=ubuntu or DOCKER_OS=debian." >&2
    exit 1
fi
if [[ "$OS" != ubuntu && "$OS" != debian ]]; then
    echo "Unsupported Docker repository OS: $OS (choose ubuntu or debian)." >&2
    exit 1
fi

PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-compose-plugin
    docker-buildx-plugin
    iptables
    libip4tc2
    libip6tc2
    libnetfilter-conntrack3
    libnfnetlink0
    libmnl0
)
KEYRING="/etc/apt/keyrings/docker.gpg"
REPO_FILE="/etc/apt/sources.list.d/docker-offline-download.list"
TMP_KEY=""

cleanup() {
    sudo rm -f "$REPO_FILE"
    [[ -z "$TMP_KEY" ]] || rm -f "$TMP_KEY"
}
trap cleanup EXIT

echo "--- Updating offline Docker packages ---"
echo "Architecture : $ARCH"
echo "Repository OS: $OS"
echo "Distributions: ${DISTROS[*]}"
echo

# apt itself needs curl and gpg for repository key setup. Install them when
# absent; apt's Debian/Ubuntu archive keys are managed by the OS.
missing=()
command -v curl >/dev/null 2>&1 || missing+=(curl)
command -v gpg >/dev/null 2>&1 || missing+=(gnupg)
if ((${#missing[@]})); then
    echo "Installing required tools: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
fi

sudo install -d -m 0755 /etc/apt/keyrings
TMP_KEY="$(mktemp)"
curl -fsSL "https://download.docker.com/linux/$OS/gpg" | gpg --batch --yes --dearmor -o "$TMP_KEY"
sudo install -m 0644 "$TMP_KEY" "$KEYRING"

for DISTRO in "${DISTROS[@]}"; do
    if [[ ! "$DISTRO" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Invalid distro codename: $DISTRO" >&2
        exit 1
    fi

    PKG_DIR="$DIR/packages/$OS/$ARCH/$DISTRO"
    mkdir -p "$PKG_DIR"
    echo "--- $DISTRO: $PKG_DIR ---"
    find "$PKG_DIR" -maxdepth 1 -type f -name '*.deb' -delete

    echo "deb [arch=$ARCH signed-by=$KEYRING] https://download.docker.com/linux/$OS $DISTRO stable" \
        | sudo tee "$REPO_FILE" >/dev/null
    sudo apt-get update

    (
        cd "$PKG_DIR"
        for pkg in "${PACKAGES[@]}"; do
            echo "Downloading $pkg for $DISTRO..."
            apt-get download "$pkg"
        done
    )

    for pkg in "${PACKAGES[@]}"; do
        if ! compgen -G "$PKG_DIR/${pkg}_*.deb" >/dev/null; then
            echo "ERROR: Failed to download $pkg for $DISTRO" >&2
            exit 1
        fi
    done
    echo "Downloads verified for $DISTRO."
    echo
done

echo "--- Offline packages updated successfully ---"

