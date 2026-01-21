#!/bin/sh
#
# install_nvidia_local.sh - Install NVIDIA CUDA Toolkit and Open Driver (Local)
#
# This script installs:
# - cuda-toolkit (latest version from NVIDIA repository)
# - nvidia-driver-open (open-source NVIDIA driver)
# - nvidia-utils (nvidia-smi and other utilities)
#
# Supports: Ubuntu, Debian, RHEL, Fedora
# Reference: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$ID"
    VERSION="$VERSION_ID"
else
    log_error "Cannot detect distribution. /etc/os-release not found."
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
    log_error "Unsupported architecture: $ARCH"
    exit 1
fi

# Set architecture string for NVIDIA repo
case "$ARCH" in
    x86_64) ARCH_CODE="x86_64" ;;
    aarch64) ARCH_CODE="sbsa" ;;
esac

# Map distribution to NVIDIA repo codename
case "$DISTRO" in
    ubuntu)
        VERSION_NO_DOT=$(echo "$VERSION" | tr -d '.')
        DISTRO_CODE="ubuntu${VERSION_NO_DOT}"
        PKG_MANAGER="apt"
        ;;
    debian)
        DISTRO_CODE="debian${VERSION}"
        PKG_MANAGER="apt"
        ;;
    rhel|centos|rocky|almalinux)
        MAJOR_VERSION=$(echo "$VERSION" | cut -d. -f1)
        DISTRO_CODE="rhel${MAJOR_VERSION}"
        PKG_MANAGER="dnf"
        ;;
    fedora)
        DISTRO_CODE="fedora${VERSION}"
        PKG_MANAGER="dnf"
        ;;
    *)
        log_error "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

log_info "Detected: $DISTRO $VERSION ($DISTRO_CODE) on $ARCH"

install_debian_ubuntu() {
    # Remove old GPG key if present
    log_info "Removing old NVIDIA GPG key if present..."
    apt-key del 7fa2af80 2>/dev/null || true

    # Install prerequisites
    log_info "Installing prerequisites..."
    apt-get update -y
    apt-get install -y wget gnupg

    # Download and install cuda-keyring
    KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO_CODE}/${ARCH_CODE}/cuda-keyring_1.1-1_all.deb"
    KEYRING_DEB="/tmp/cuda-keyring_1.1-1_all.deb"

    log_info "Downloading cuda-keyring from: $KEYRING_URL"
    if ! wget -q -O "$KEYRING_DEB" "$KEYRING_URL"; then
        log_error "Failed to download cuda-keyring."
        exit 1
    fi

    log_info "Installing cuda-keyring..."
    dpkg -i "$KEYRING_DEB"
    rm -f "$KEYRING_DEB"

    # Update package lists
    log_info "Updating package lists..."
    apt-get update -y

    # Install CUDA Toolkit
    log_info "Installing cuda-toolkit..."
    apt-get install -y cuda-toolkit

    # Install NVIDIA Open Driver with utilities
    log_info "Installing nvidia-driver-open..."
    apt-get install -y nvidia-driver-open || {
        log_warn "nvidia-driver-open not available, trying cuda-drivers..."
        apt-get install -y cuda-drivers
    }
}

install_rhel_fedora() {
    log_info "Installing prerequisites..."
    dnf install -y wget

    # Add NVIDIA repository
    REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO_CODE}/${ARCH_CODE}/cuda-${DISTRO_CODE}.repo"
    log_info "Adding NVIDIA repository..."
    dnf config-manager --add-repo "$REPO_URL" || wget -O /etc/yum.repos.d/cuda.repo "$REPO_URL"

    # Clean and update
    dnf clean all
    dnf makecache

    # Install CUDA Toolkit and drivers
    log_info "Installing cuda-toolkit..."
    dnf install -y cuda-toolkit

    log_info "Installing nvidia-driver (open kernel modules)..."
    dnf install -y nvidia-driver || dnf install -y cuda-drivers
}

# Run distribution-specific installation
case "$PKG_MANAGER" in
    apt) install_debian_ubuntu ;;
    dnf) install_rhel_fedora ;;
esac

# Set up environment variables
log_info "Setting up environment variables..."
CUDA_ENV_FILE="/etc/profile.d/cuda.sh"
cat > "$CUDA_ENV_FILE" << 'EOF'
# CUDA Toolkit environment variables
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
EOF
chmod 644 "$CUDA_ENV_FILE"

# Also add to user's shell config if zshrc exists
if [ -f "$HOME/.zshrc" ]; then
    log_info "Adding CUDA paths to .zshrc..."
    grep -q '/usr/local/cuda/bin' "$HOME/.zshrc" || \
        echo 'export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}' >> "$HOME/.zshrc"
    grep -q '/usr/local/cuda/lib64' "$HOME/.zshrc" || \
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> "$HOME/.zshrc"
fi

log_info ""
log_info "Installation complete!"
log_info "Please reboot your system to load the NVIDIA driver."
log_info "After reboot, verify with: nvidia-smi && nvcc --version"
log_info "Environment variables added to: $CUDA_ENV_FILE"

