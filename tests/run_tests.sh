#!/bin/sh
# Automated test script for install_local.sh and install_remote.sh
# Tests on macOS (local), Ubuntu 24.04, Fedora, Arch Linux, and Alpine Linux (Docker)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/results"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULTS_FILE="$RESULTS_DIR/test_results_$TIMESTAMP.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

# Docker images for each platform
UBUNTU_IMAGE="ubuntu:24.04"
FEDORA_IMAGE="fedora:latest"
ARCH_IMAGE="archlinux:latest"
ALPINE_IMAGE="alpine:latest"
OPENWRT_IMAGE="openwrt/rootfs:x86_64-24.10.5"

mkdir -p "$RESULTS_DIR"

log() {
  printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$1" | tee -a "$RESULTS_FILE"
}

log_success() {
  printf "${GREEN}[PASS]${NC} %s\n" "$1" | tee -a "$RESULTS_FILE"
}

log_fail() {
  printf "${RED}[FAIL]${NC} %s\n" "$1" | tee -a "$RESULTS_FILE"
}

log_skip() {
  printf "${YELLOW}[SKIP]${NC} %s\n" "$1" | tee -a "$RESULTS_FILE"
}

log_info() {
  printf "${BLUE}[INFO]${NC} %s\n" "$1" | tee -a "$RESULTS_FILE"
}

# Check if Docker is available
check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log_fail "Docker not found. Docker tests will be skipped."
    return 1
  fi
  return 0
}

# Create test config
# Enable cargo and eza to verify Rust-based CLI tools work via installer
create_test_config() {
  cat > "$SCRIPT_DIR/test_config.json" << 'EOF'
{
  "prompts": {
    "prompt_for_confirmation": false,
    "ssh_port": "22",
    "server_address": "",
    "ssh_user": "",
    "ssh_key_action": "skip",
    "ssh_public_keys": []
  },
  "installation": {
    "skip_package_update": false,
    "skip_zinit": false,
    "skip_mcp_setup": false
  },
  "packages": {
    "nvm": true,
    "uv": true,
    "cargo": true,
    "ruff": false,
    "ty": false
  },
  "cli_tools": {
    "fzf": true,
    "eza": true,
    "bat": false,
    "fd": false,
    "ripgrep": false,
    "zoxide": false,
    "dust": false,
    "duf": false,
    "mcfly": false,
    "sd": false,
    "choose": false,
    "bottom": false,
    "procs": false,
    "gping": false,
    "delta": false,
    "hishtory": false,
    "cheat": false,
    "lsd": false
  }
}
EOF
}

# Verify installation results
verify_results() {
  container="$1"
  platform="$2"

  log_info "Verifying installation results for $platform..."
  errors=0

  # Check zsh
  if docker exec "$container" sh -c 'command -v zsh >/dev/null 2>&1'; then
    log_success "$platform: zsh installed"
  else
    log_fail "$platform: zsh not found"
    errors=$((errors + 1))
  fi

  # Check fzf
  if docker exec -u testuser "$container" sh -c '[ -d ~/.fzf ]'; then
    log_success "$platform: fzf installed"
  else
    log_fail "$platform: fzf not found"
    errors=$((errors + 1))
  fi

  # Check zinit
  if docker exec -u testuser "$container" sh -c '[ -d ~/.local/share/zinit/zinit.git ]'; then
    log_success "$platform: zinit installed"
  else
    log_fail "$platform: zinit not found"
    errors=$((errors + 1))
  fi

  # Check MCP servers
  mcp_count=$(docker exec -u testuser "$container" sh -c 'ls ~/.config/mcp/servers/ 2>/dev/null | wc -l' 2>/dev/null || echo "0")
  if [ "$mcp_count" -gt 0 ]; then
    log_success "$platform: MCP servers configured ($mcp_count configs)"
  else
    log_fail "$platform: No MCP servers found"
    errors=$((errors + 1))
  fi

  # Check uv
  if docker exec -u testuser "$container" sh -c '~/.local/bin/uv --version >/dev/null 2>&1'; then
    log_success "$platform: uv installed"
  else
    log_fail "$platform: uv not found"
    errors=$((errors + 1))
  fi

  # Check cargo
  if docker exec -u testuser "$container" sh -c '~/.cargo/bin/cargo --version >/dev/null 2>&1'; then
    log_success "$platform: cargo installed"
  else
    log_fail "$platform: cargo not found"
    errors=$((errors + 1))
  fi

  # Check eza (Rust-based CLI tool installed via cargo)
  if docker exec -u testuser "$container" sh -c '~/.cargo/bin/eza --version >/dev/null 2>&1'; then
    log_success "$platform: eza installed"
  else
    log_fail "$platform: eza not found"
    errors=$((errors + 1))
  fi

  return $errors
}

# Test on a specific Docker platform
test_docker_platform() {
  image="$1"
  platform_name="$2"
  container_name="setup-test-${platform_name}"

  log "============================================="
  log "Testing on $platform_name ($image)"
  log "============================================="

  # Clean up any existing container
  docker rm -f "$container_name" 2>/dev/null || true

  # Start container with explicit DNS to avoid resolution issues
  log_info "Starting $platform_name container..."
  if ! docker run -d --platform "$DOCKER_PLATFORM" --dns 8.8.8.8 --dns 1.1.1.1 --name "$container_name" "$image" sleep infinity; then
    log_fail "Failed to start $platform_name container"
    return 1
  fi

  # Wait for container to be ready
  sleep 2

  # Install prerequisites and create test user
  log_info "Setting up $platform_name container..."
  case "$platform_name" in
    ubuntu)
      docker exec "$container_name" sh -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -qq -y sudo curl ca-certificates
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
      '
      ;;
    fedora)
      docker exec "$container_name" sh -c '
        dnf -y install sudo shadow-utils
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
      '
      ;;
    arch)
      docker exec "$container_name" sh -c '
        pacman -Sy --noconfirm sudo
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
      '
      ;;
    alpine)
      docker exec "$container_name" sh -c '
        apk add --no-cache sudo shadow bash
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
      '
      ;;
    openwrt)
      docker exec "$container_name" sh -c '
        # Create required directories for opkg
        mkdir -p /var/lock /var/run
        opkg update
        opkg install sudo shadow-useradd bash curl ca-certificates
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
      '
      ;;
  esac

  # Copy files to container
  log_info "Copying files to $platform_name container..."
  docker cp "$REPO_DIR/install_local.sh" "$container_name:/home/testuser/"
  docker cp "$SCRIPT_DIR/test_config.json" "$container_name:/home/testuser/config.json"
  docker cp "$REPO_DIR/mcp" "$container_name:/home/testuser/"
  docker cp "$REPO_DIR/configs" "$container_name:/home/testuser/"
  docker exec "$container_name" chown -R testuser /home/testuser

  # Run installation
  log_info "Running install_local.sh on $platform_name..."
  install_log="$RESULTS_DIR/${platform_name}_install_$TIMESTAMP.log"

  # Set environment variables based on platform to prevent interactive prompts
  # Build docker exec command conditionally to avoid empty -e flag
  case "$platform_name" in
    ubuntu|openwrt)
      env_flag="-e DEBIAN_FRONTEND=noninteractive"
      ;;
    *)
      env_flag=""
      ;;
  esac

  # shellcheck disable=SC2086
  if docker exec -u testuser $env_flag "$container_name" sh -c '
    cd /home/testuser
    export DEBIAN_FRONTEND=noninteractive
    sh install_local.sh --key-action skip -c config.json -y 2>&1
  ' > "$install_log" 2>&1; then
    log_success "$platform_name: install_local.sh completed"
  else
    log_fail "$platform_name: install_local.sh failed (check $install_log)"
    return 1
  fi

  # Verify results
  verify_results "$container_name" "$platform_name"
  result=$?

  # Cleanup
  if [ "$KEEP_CONTAINERS" != "true" ]; then
    docker rm -f "$container_name" >/dev/null 2>&1 || true
  fi

  return $result
}

# Test install_remote.sh with SSH-enabled container
test_remote_ssh() {
  image="$1"
  platform_name="$2"
  ssh_port="${3:-2222}"
  container_name="setup-test-${platform_name}"

  log "============================================="
  log "Testing install_remote.sh on $platform_name ($image)"
  log "============================================="

  # Clean up any existing container
  docker rm -f "$container_name" 2>/dev/null || true

  # Start container with port mapping and explicit DNS
  log_info "Starting $platform_name container with SSH..."
  if ! docker run -d --platform "$DOCKER_PLATFORM" --dns 8.8.8.8 --dns 1.1.1.1 --name "$container_name" -p "${ssh_port}:22" "$image" sleep infinity; then
    log_fail "Failed to start $platform_name container"
    return 1
  fi

  # Wait for container to be ready
  sleep 2

  # Generate temporary SSH key for testing
  test_key="$SCRIPT_DIR/.test_ssh_key"
  test_key_pub="${test_key}.pub"
  # Force remove existing keys and generate new ones
  rm -f "$test_key" "$test_key_pub" 2>/dev/null || true
  if ! ssh-keygen -t ed25519 -f "$test_key" -N "" -q 2>/dev/null; then
    log_fail "$platform_name: Failed to generate SSH test key"
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    return 1
  fi
  if [ ! -f "$test_key_pub" ]; then
    log_fail "$platform_name: SSH public key was not generated"
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    return 1
  fi

  # Install SSH server and set up user
  log_info "Setting up SSH on $platform_name container..."
  case "$platform_name" in
    ubuntu-remote)
      docker exec "$container_name" sh -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -qq -y sudo curl ca-certificates openssh-server python3
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        mkdir -p /home/testuser/.ssh
        chmod 700 /home/testuser/.ssh
        mkdir -p /run/sshd
        ssh-keygen -A
        sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
        sed -i "s/#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
        sed -i "s/#PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
      '
      ;;
    fedora-remote)
      docker exec "$container_name" sh -c '
        dnf -y install sudo shadow-utils openssh-server openssh-clients python3
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        mkdir -p /home/testuser/.ssh
        chmod 700 /home/testuser/.ssh
        ssh-keygen -A
        sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
        sed -i "s/#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
        sed -i "s/PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
      '
      ;;
    arch-remote)
      docker exec "$container_name" sh -c '
        pacman -Sy --noconfirm sudo openssh python
        useradd -m -s /bin/sh testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        mkdir -p /home/testuser/.ssh
        chmod 700 /home/testuser/.ssh
        ssh-keygen -A
        sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
        sed -i "s/#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
        sed -i "s/PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
      '
      ;;
    alpine-remote)
      docker exec "$container_name" sh -c '
        apk add --no-cache sudo shadow bash openssh python3
        useradd -m -s /bin/sh testuser
        # Unlock the account for SSH key auth (Alpine creates locked accounts by default)
        # Using * instead of ! allows key-based auth without a password
        usermod -p "*" testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        mkdir -p /home/testuser/.ssh
        chmod 700 /home/testuser/.ssh
        ssh-keygen -A
        sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
        sed -i "s/#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
        sed -i "s/PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
      '
      ;;
    openwrt-remote)
      docker exec "$container_name" sh -c '
        # Create required directories for opkg
        mkdir -p /var/lock /var/run
        opkg update
        opkg install sudo shadow-useradd shadow-usermod bash curl ca-certificates openssh-server openssh-keygen python3
        useradd -m -s /bin/sh testuser
        # Unlock the account for SSH key auth (OpenWrt creates locked accounts by default)
        usermod -p "*" testuser
        echo "testuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        mkdir -p /home/testuser/.ssh
        chmod 700 /home/testuser/.ssh
        ssh-keygen -A
        sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
        sed -i "s/#PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
        sed -i "s/PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
      '
      ;;
  esac

  # Copy SSH public key to container
  docker cp "$test_key_pub" "$container_name:/home/testuser/.ssh/authorized_keys"
  docker exec "$container_name" sh -c '
    chown -R testuser:testuser /home/testuser/.ssh
    chmod 600 /home/testuser/.ssh/authorized_keys
  '

  # Start SSH server (handle different paths across distros)
  log_info "Starting SSH server..."
  if ! docker exec "$container_name" sh -c 'if [ -x /usr/sbin/sshd ]; then /usr/sbin/sshd; elif [ -x /usr/bin/sshd ]; then /usr/bin/sshd; else echo "sshd not found" >&2; exit 1; fi' 2>/dev/null; then
    log_fail "$platform_name: Failed to start SSH server"
    rm -f "$test_key" "$test_key_pub" 2>/dev/null || true
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    return 1
  fi

  # Wait for SSH to be ready (increased wait time for slower containers)
  sleep 3

  # Copy test files to container (needed for mcp folder)
  docker cp "$REPO_DIR/mcp" "$container_name:/home/testuser/"
  docker cp "$REPO_DIR/configs" "$container_name:/home/testuser/"
  docker exec "$container_name" chown -R testuser /home/testuser

  # Test SSH connectivity with retry
  log_info "Testing SSH connectivity..."
  ssh_ok=false
  for attempt in 1 2 3; do
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
         -i "$test_key" -p "$ssh_port" testuser@localhost "echo SSH OK" >/dev/null 2>&1; then
      ssh_ok=true
      break
    fi
    sleep 2
  done
  if [ "$ssh_ok" = "false" ]; then
    log_fail "$platform_name: SSH connection failed after 3 attempts"
    rm -f "$test_key" "$test_key_pub" 2>/dev/null || true
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    return 1
  fi

  # Run install_remote.sh
  log_info "Running install_remote.sh on $platform_name..."
  install_log="$RESULTS_DIR/${platform_name}_remote_install_$TIMESTAMP.log"

  # Create a config that works for remote testing
  # Note: hishtory must be explicitly disabled because install_remote.sh defaults it to true,
  # and hishtory install hangs waiting for network sync in test environments
  cat > "$SCRIPT_DIR/test_remote_config.json" << EOF
{
  "prompts": {
    "prompt_for_confirmation": false,
    "ssh_port": "$ssh_port",
    "server_address": "localhost",
    "ssh_user": "testuser",
    "ssh_key_action": "skip",
    "ssh_public_keys": []
  },
  "installation": {
    "skip_package_update": false,
    "skip_zinit": false,
    "skip_mcp_setup": false
  },
  "packages": {
    "nvm": true,
    "uv": true,
    "cargo": true,
    "ruff": false,
    "ty": false
  },
  "cli_tools": {
    "fzf": true,
    "eza": true,
    "bat": false,
    "fd": false,
    "ripgrep": false,
    "zoxide": false,
    "dust": false,
    "duf": false,
    "mcfly": false,
    "sd": false,
    "choose": false,
    "bottom": false,
    "procs": false,
    "gping": false,
    "delta": false,
    "hishtory": false,
    "cheat": false,
    "lsd": false,
    "lazygit": false,
    "lazydocker": false,
    "tldr": false,
    "jq": false,
    "yq": false,
    "hyperfine": false,
    "tokei": false,
    "broot": false,
    "atuin": false,
    "xh": false,
    "difftastic": false
  }
}
EOF

  if sh "$REPO_DIR/install_remote.sh" \
       -H localhost -p "$ssh_port" -u testuser \
       -i "$test_key" --key-action skip -y \
       -c "$SCRIPT_DIR/test_remote_config.json" > "$install_log" 2>&1; then
    log_success "$platform_name: install_remote.sh completed"
  else
    log_fail "$platform_name: install_remote.sh failed (check $install_log)"
    rm -f "$test_key" "$test_key_pub" "$SCRIPT_DIR/test_remote_config.json" 2>/dev/null || true
    docker rm -f "$container_name" >/dev/null 2>&1 || true
    return 1
  fi

  # Verify remote installation results
  verify_results "$container_name" "$platform_name"
  result=$?

  # Cleanup
  rm -f "$test_key" "$test_key_pub" "$SCRIPT_DIR/test_remote_config.json" 2>/dev/null || true
  if [ "$KEEP_CONTAINERS" != "true" ]; then
    docker rm -f "$container_name" >/dev/null 2>&1 || true
  fi

  return $result
}


# Test on macOS (local)
test_macos() {
  log "============================================="
  log "Testing on macOS (local)"
  log "============================================="

  if [ "$(uname -s)" != "Darwin" ]; then
    log_skip "Not running on macOS, skipping local macOS test"
    return 0
  fi

  # Check syntax only for macOS (don't run full install on host)
  log_info "Checking script syntax..."
  if sh -n "$REPO_DIR/install_local.sh" && sh -n "$REPO_DIR/install_remote.sh"; then
    log_success "macOS: Script syntax is valid"
  else
    log_fail "macOS: Script syntax error"
    return 1
  fi

  log_success "macOS: Syntax check passed (full install skipped to avoid modifying host)"
  return 0
}

# Main test runner
main() {
  log "============================================="
  log "Setup Repository Automated Tests"
  log "Started: $(date)"
  log "============================================="

  create_test_config

  total_tests=0
  passed_tests=0
  failed_tests=0

  # Test macOS (syntax only to avoid modifying host)
  total_tests=$((total_tests + 1))
  if test_macos; then
    passed_tests=$((passed_tests + 1))
  else
    failed_tests=$((failed_tests + 1))
  fi

  # Docker tests
  if check_docker; then
    # Ubuntu 24.04
    total_tests=$((total_tests + 1))
    if test_docker_platform "$UBUNTU_IMAGE" "ubuntu"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # Fedora
    total_tests=$((total_tests + 1))
    if test_docker_platform "$FEDORA_IMAGE" "fedora"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # Arch Linux
    total_tests=$((total_tests + 1))
    if test_docker_platform "$ARCH_IMAGE" "arch"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # Alpine Linux
    total_tests=$((total_tests + 1))
    if test_docker_platform "$ALPINE_IMAGE" "alpine"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # OpenWrt local test (using OpenWrt 24.10.5 with opkg)
    total_tests=$((total_tests + 1))
    if test_docker_platform "$OPENWRT_IMAGE" "openwrt"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # Remote tests with SSH
    log "============================================="
    log "Testing install_remote.sh with SSH containers"
    log "============================================="

    # Ubuntu remote test
    total_tests=$((total_tests + 1))
    if test_remote_ssh "$UBUNTU_IMAGE" "ubuntu-remote" "2222"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # Fedora remote test
    total_tests=$((total_tests + 1))
    if test_remote_ssh "$FEDORA_IMAGE" "fedora-remote" "2223"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # Arch remote test
    total_tests=$((total_tests + 1))
    if test_remote_ssh "$ARCH_IMAGE" "arch-remote" "2224"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # Alpine remote test
    total_tests=$((total_tests + 1))
    if test_remote_ssh "$ALPINE_IMAGE" "alpine-remote" "2225"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi

    # OpenWrt remote test (using OpenWrt 24.10.5 with opkg)
    total_tests=$((total_tests + 1))
    if test_remote_ssh "$OPENWRT_IMAGE" "openwrt-remote" "2226"; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi
  else
    log_skip "Docker not available, skipping container tests"
  fi

  # Summary
  log ""
  log "============================================="
  log "Test Summary"
  log "============================================="
  log "Total:  $total_tests"
  log "Passed: $passed_tests"
  log "Failed: $failed_tests"
  log ""
  log "Results saved to: $RESULTS_FILE"
  log "Completed: $(date)"

  if [ "$failed_tests" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main "$@"

