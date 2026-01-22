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

# Create minimal test config for faster testing
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
    "cargo": false,
    "ruff": false,
    "ty": false
  },
  "cli_tools": {
    "fzf": true,
    "eza": false,
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

  # Start container
  log_info "Starting $platform_name container..."
  if ! docker run -d --platform "$DOCKER_PLATFORM" --name "$container_name" "$image" sleep infinity; then
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

  if docker exec -u testuser "$container_name" sh -c '
    cd /home/testuser
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

