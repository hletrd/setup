#!/bin/sh
#
# install_nvidia_remote.sh - Install NVIDIA CUDA Toolkit and Open Driver (Remote)
#
# This script connects to a remote server via SSH and installs:
# - cuda-toolkit (latest version from NVIDIA repository)
# - nvidia-driver-open (open-source NVIDIA driver)
# - nvidia-utils (nvidia-smi and other utilities)

set -e

script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/config.json"

# JSON parsing helper
json_get() {
  key="$1"
  file="$2"
  if [ -f "$file" ]; then
    grep "\"$key\"" "$file" | sed 's/.*: *"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/' | head -1
  fi
}

# Load configuration
cfg_ssh_port="22"
cfg_server_address="localhost"
if [ -f "$config_file" ]; then
    val="$(json_get "ssh_port" "$config_file")"
    [ -n "$val" ] && cfg_ssh_port="$val"
    val="$(json_get "server_address" "$config_file")"
    [ -n "$val" ] && cfg_server_address="$val"
fi

prompt_read() {
  prompt="$1"
  if [ -t 0 ]; then
    printf "%s" "$prompt"
    IFS= read -r input
  else
    printf "%s" "$prompt" > /dev/tty
    IFS= read -r input < /dev/tty
  fi
  printf "%s" "$input"
}

prompt_or_default() {
  prompt="$1"
  default="$2"
  result="$(prompt_read "$prompt")"
  [ -z "$result" ] && result="$default"
  printf "%s" "$result"
}

default_user="$(id -un)"

server_addr="$(prompt_or_default "Server address (default: ${cfg_server_address}): " "$cfg_server_address")"
server_port="$(prompt_or_default "SSH port (default: ${cfg_ssh_port}): " "$cfg_ssh_port")"
ssh_user="$(prompt_or_default "SSH username (default: ${default_user}): " "$default_user")"

remote_script_path="/tmp/nvidia-install.$$"

# Send and execute the installation script
ssh -p "$server_port" "$ssh_user@$server_addr" "cat > \"$remote_script_path\" && chmod 700 \"$remote_script_path\"" <<'NVIDIA_SCRIPT'
#!/bin/sh
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

printf "Caching sudo credentials...\n"
sudo -v

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$ID"
    VERSION="$VERSION_ID"
else
    log_error "Cannot detect distribution."
    exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_CODE="x86_64" ;;
    aarch64) ARCH_CODE="sbsa" ;;
    *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

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

if [ "$PKG_MANAGER" = "apt" ]; then
    sudo -n apt-key del 7fa2af80 2>/dev/null || true
    sudo -n apt-get update -y
    sudo -n apt-get install -y wget gnupg

    KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO_CODE}/${ARCH_CODE}/cuda-keyring_1.1-1_all.deb"
    log_info "Downloading cuda-keyring..."
    wget -q -O /tmp/cuda-keyring.deb "$KEYRING_URL"
    sudo -n dpkg -i /tmp/cuda-keyring.deb
    rm -f /tmp/cuda-keyring.deb

    sudo -n apt-get update -y
    log_info "Installing cuda-toolkit..."
    sudo -n apt-get install -y cuda-toolkit
    log_info "Installing nvidia-driver-open..."
    sudo -n apt-get install -y nvidia-driver-open || sudo -n apt-get install -y cuda-drivers
else
    sudo -n dnf install -y wget
    REPO_URL="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO_CODE}/${ARCH_CODE}/cuda-${DISTRO_CODE}.repo"
    sudo -n dnf config-manager --add-repo "$REPO_URL" || sudo -n wget -O /etc/yum.repos.d/cuda.repo "$REPO_URL"
    sudo -n dnf clean all
    sudo -n dnf makecache
    log_info "Installing cuda-toolkit..."
    sudo -n dnf install -y cuda-toolkit
    log_info "Installing nvidia-driver..."
    sudo -n dnf install -y nvidia-driver || sudo -n dnf install -y cuda-drivers
fi

log_info "Setting up environment variables..."
sudo -n sh -c 'cat > /etc/profile.d/cuda.sh << EOF
export PATH=/usr/local/cuda/bin\${PATH:+:\${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}
EOF'
sudo -n chmod 644 /etc/profile.d/cuda.sh

if [ -f "$HOME/.zshrc" ]; then
    grep -q '/usr/local/cuda/bin' "$HOME/.zshrc" || \
        echo 'export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}' >> "$HOME/.zshrc"
    grep -q '/usr/local/cuda/lib64' "$HOME/.zshrc" || \
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> "$HOME/.zshrc"
fi

log_info "Installation complete! Please reboot to load the NVIDIA driver."
log_info "After reboot, verify with: nvidia-smi && nvcc --version"
NVIDIA_SCRIPT

# Execute the remote script
if [ -t 0 ]; then
  ssh -tt -p "$server_port" "$ssh_user@$server_addr" "sh \"$remote_script_path\"; rc=\$?; rm -f \"$remote_script_path\"; exit \$rc" < /dev/tty
else
  ssh -p "$server_port" "$ssh_user@$server_addr" "sh \"$remote_script_path\"; rc=\$?; rm -f \"$remote_script_path\"; exit \$rc"
fi

