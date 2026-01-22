#!/bin/sh

set -e

script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/config.json"

# Command line option defaults (empty = use config/prompt)
opt_ssh_port=""
opt_server_name=""
opt_ssh_key_action=""
opt_pubkey=""
opt_no_prompt=""
opt_help=""

# Parse command line options
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install development environment on the local machine.

Options:
  -p, --port PORT          SSH port (default: 22)
  -n, --name NAME          Server name for MOTD (default: hostname)
  -k, --key-action ACTION  SSH key action: generate, add, skip (default: generate)
  --pubkey KEY             Public key to install (required if --key-action=add)
  -y, --yes                Non-interactive mode, use defaults without prompting
  -c, --config FILE        Path to config file (default: ./config.json)
  -h, --help               Show this help message

Examples:
  # Non-interactive with defaults
  $(basename "$0") -y

  # Specify SSH port and server name
  $(basename "$0") -p 2222 -n myserver -y

  # Skip SSH key setup
  $(basename "$0") --key-action skip -y

  # Use custom config file
  $(basename "$0") -c /path/to/config.json -y
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--port)
      opt_ssh_port="$2"
      shift 2
      ;;
    -n|--name)
      opt_server_name="$2"
      shift 2
      ;;
    -k|--key-action)
      opt_ssh_key_action="$2"
      shift 2
      ;;
    --pubkey)
      opt_pubkey="$2"
      shift 2
      ;;
    -y|--yes)
      opt_no_prompt="true"
      shift
      ;;
    -c|--config)
      config_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      printf "Unknown option: %s\n" "$1" >&2
      printf "Use -h or --help for usage information.\n" >&2
      exit 1
      ;;
    *)
      shift
      ;;
  esac
done

# JSON parsing helper (uses grep/sed for POSIX compatibility)
json_get() {
  key="$1"
  file="$2"
  # Simple JSON value extraction for flat or nested keys
  if [ -f "$file" ]; then
    # Handle nested keys like "mcp.disabled_servers" or "prompts.prompt_for_confirmation"
    case "$key" in
      *.*)
        parent="${key%%.*}"
        child="${key#*.}"
        # Use || true to prevent exit with set -e when key not found
        sed -n "/$parent/,/}/p" "$file" | grep "\"$child\"" | sed 's/.*: *"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/' | head -1 || true
        ;;
      *)
        # Use || true to prevent exit with set -e when key not found
        grep "\"$key\"" "$file" | sed 's/.*: *"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/' | head -1 || true
        ;;
    esac
  fi
}

json_get_bool() {
  val="$(json_get "$1" "$2")"
  case "$val" in
    true|True|TRUE|1) printf "true" ;;
    false|False|FALSE|0) printf "false" ;;
    *) printf "" ;;  # Return empty for missing keys to preserve defaults
  esac
}

json_get_array() {
  key="$1"
  file="$2"
  if [ -f "$file" ]; then
    # Extract array contents between [ and ]
    sed -n "/\"$key\"/,/]/p" "$file" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | grep -v "$key"
  fi
}

# Load configuration
cfg_prompt_for_confirmation="true"
cfg_ssh_port="22"
cfg_ssh_key_action="generate"
cfg_ssh_public_keys=""
cfg_skip_package_update="false"
cfg_skip_zinit="false"
cfg_skip_mcp_setup="false"
cfg_editor_cursor="true"
cfg_editor_codex="true"
cfg_editor_opencode="true"
cfg_editor_antigravity="true"
cfg_editor_claude_desktop="true"

# Package manager toggles (default all enabled)
cfg_pkg_nvm="true"
cfg_pkg_uv="true"
cfg_pkg_cargo="true"

# MCP server toggles (default all enabled)
cfg_mcp_auggie_context="true"
cfg_mcp_claude_context="true"
cfg_mcp_context7="true"
cfg_mcp_fetch="true"
cfg_mcp_filesystem="true"
cfg_mcp_git="true"
cfg_mcp_github="true"
cfg_mcp_jupyter="true"
cfg_mcp_memory="true"
cfg_mcp_playwright="true"
cfg_mcp_sequential_thinking="true"

# Helper to set config value only if non-empty
set_if_present() {
  var_name="$1"
  val="$2"
  # Use || true to prevent exit with set -e when val is empty
  [ -n "$val" ] && eval "$var_name=\"$val\"" || true
}

if [ -f "$config_file" ]; then
  printf "Loading configuration from %s\n" "$config_file"
  set_if_present cfg_prompt_for_confirmation "$(json_get_bool "prompt_for_confirmation" "$config_file")"
  set_if_present cfg_ssh_port "$(json_get "ssh_port" "$config_file")"
  set_if_present cfg_ssh_key_action "$(json_get "ssh_key_action" "$config_file")"
  cfg_ssh_public_keys="$(json_get_array "ssh_public_keys" "$config_file")"
  set_if_present cfg_skip_package_update "$(json_get_bool "skip_package_update" "$config_file")"
  set_if_present cfg_skip_zinit "$(json_get_bool "skip_zinit" "$config_file")"
  set_if_present cfg_skip_mcp_setup "$(json_get_bool "skip_mcp_setup" "$config_file")"
  set_if_present cfg_editor_cursor "$(json_get_bool "cursor" "$config_file")"
  set_if_present cfg_editor_codex "$(json_get_bool "codex" "$config_file")"
  set_if_present cfg_editor_opencode "$(json_get_bool "opencode" "$config_file")"
  set_if_present cfg_editor_antigravity "$(json_get_bool "antigravity" "$config_file")"
  set_if_present cfg_editor_claude_desktop "$(json_get_bool "claude_desktop" "$config_file")"

  # Load package manager toggles
  set_if_present cfg_pkg_nvm "$(json_get_bool "nvm" "$config_file")"
  set_if_present cfg_pkg_uv "$(json_get_bool "uv" "$config_file")"
  set_if_present cfg_pkg_cargo "$(json_get_bool "cargo" "$config_file")"
  set_if_present cfg_pkg_ruff "$(json_get_bool "ruff" "$config_file")"
  set_if_present cfg_pkg_ty "$(json_get_bool "ty" "$config_file")"

  # Load CLI tools toggles
  set_if_present cfg_cli_hishtory "$(json_get_bool "hishtory" "$config_file")"
  set_if_present cfg_cli_fzf "$(json_get_bool "fzf" "$config_file")"
  set_if_present cfg_cli_eza "$(json_get_bool "eza" "$config_file")"
  set_if_present cfg_cli_bat "$(json_get_bool "bat" "$config_file")"
  set_if_present cfg_cli_delta "$(json_get_bool "delta" "$config_file")"
  set_if_present cfg_cli_dust "$(json_get_bool "dust" "$config_file")"
  set_if_present cfg_cli_duf "$(json_get_bool "duf" "$config_file")"
  set_if_present cfg_cli_fd "$(json_get_bool "fd" "$config_file")"
  set_if_present cfg_cli_ripgrep "$(json_get_bool "ripgrep" "$config_file")"
  set_if_present cfg_cli_mcfly "$(json_get_bool "mcfly" "$config_file")"
  set_if_present cfg_cli_sd "$(json_get_bool "sd" "$config_file")"
  set_if_present cfg_cli_choose "$(json_get_bool "choose" "$config_file")"
  set_if_present cfg_cli_cheat "$(json_get_bool "cheat" "$config_file")"
  set_if_present cfg_cli_bottom "$(json_get_bool "bottom" "$config_file")"
  set_if_present cfg_cli_procs "$(json_get_bool "procs" "$config_file")"
  set_if_present cfg_cli_zoxide "$(json_get_bool "zoxide" "$config_file")"
  set_if_present cfg_cli_lsd "$(json_get_bool "lsd" "$config_file")"
  set_if_present cfg_cli_gping "$(json_get_bool "gping" "$config_file")"
  set_if_present cfg_cli_lazygit "$(json_get_bool "lazygit" "$config_file")"
  set_if_present cfg_cli_lazydocker "$(json_get_bool "lazydocker" "$config_file")"
  set_if_present cfg_cli_tldr "$(json_get_bool "tldr" "$config_file")"
  set_if_present cfg_cli_jq "$(json_get_bool "jq" "$config_file")"
  set_if_present cfg_cli_yq "$(json_get_bool "yq" "$config_file")"
  set_if_present cfg_cli_hyperfine "$(json_get_bool "hyperfine" "$config_file")"
  set_if_present cfg_cli_tokei "$(json_get_bool "tokei" "$config_file")"
  set_if_present cfg_cli_broot "$(json_get_bool "broot" "$config_file")"
  set_if_present cfg_cli_atuin "$(json_get_bool "atuin" "$config_file")"
  set_if_present cfg_cli_xh "$(json_get_bool "xh" "$config_file")"
  set_if_present cfg_cli_difftastic "$(json_get_bool "difftastic" "$config_file")"
  set_if_present cfg_cli_zellij "$(json_get_bool "zellij" "$config_file")"

  # Load MCP server toggles
  set_if_present cfg_mcp_auggie_context "$(json_get_bool "auggie-context" "$config_file")"
  set_if_present cfg_mcp_claude_context "$(json_get_bool "claude-context" "$config_file")"
  set_if_present cfg_mcp_context7 "$(json_get_bool "context7" "$config_file")"
  set_if_present cfg_mcp_fetch "$(json_get_bool "fetch" "$config_file")"
  set_if_present cfg_mcp_filesystem "$(json_get_bool "filesystem" "$config_file")"
  set_if_present cfg_mcp_git "$(json_get_bool "git" "$config_file")"
  set_if_present cfg_mcp_github "$(json_get_bool "github" "$config_file")"
  set_if_present cfg_mcp_jupyter "$(json_get_bool "jupyter" "$config_file")"
  set_if_present cfg_mcp_memory "$(json_get_bool "memory" "$config_file")"
  set_if_present cfg_mcp_playwright "$(json_get_bool "playwright" "$config_file")"
  set_if_present cfg_mcp_sequential_thinking "$(json_get_bool "sequential-thinking" "$config_file")"
fi

# Apply command line overrides
[ -n "$opt_no_prompt" ] && cfg_prompt_for_confirmation="false"
[ -n "$opt_ssh_port" ] && cfg_ssh_port="$opt_ssh_port"
[ -n "$opt_ssh_key_action" ] && cfg_ssh_key_action="$opt_ssh_key_action"

prompt_read() {
  prompt="$1"
  input=""
  if [ -t 0 ]; then
    printf "%s" "$prompt"
    IFS= read -r input || :
  elif [ -e /dev/tty ]; then
    # Try to use /dev/tty, but fail gracefully if it's not available
    if (printf "%s" "$prompt" > /dev/tty) 2>/dev/null; then
      IFS= read -r input < /dev/tty 2>/dev/null || :
    fi
  fi
  printf "%s" "$input"
}

prompt_or_default() {
  prompt="$1"
  default="$2"
  if [ "$cfg_prompt_for_confirmation" = "true" ]; then
    result="$(prompt_read "$prompt")"
    if [ -z "$result" ]; then
      result="$default"
    fi
  else
    result="$default"
    # Print prompt to stderr to avoid capturing it in command substitution
    printf "%s%s\n" "$prompt" "$default" >&2
  fi
  printf "%s" "$result"
}

hostname_default=""
if command -v hostname >/dev/null 2>&1; then
  hostname_default="$(hostname)"
fi
if [ -z "$hostname_default" ]; then
  hostname_default="localhost"
fi

# Use command line option if provided, otherwise prompt/use default
if [ -n "$opt_ssh_port" ]; then
  server_port="$opt_ssh_port"
  printf "SSH port: %s\n" "$server_port"
else
  server_port="$(prompt_or_default "SSH port (default: ${cfg_ssh_port}): " "$cfg_ssh_port")"
fi

if [ -n "$opt_server_name" ]; then
  servername="$opt_server_name"
  printf "Server name: %s\n" "$servername"
else
  servername="$(prompt_or_default "Server name for MOTD (default: ${hostname_default}): " "$hostname_default")"
fi

# Determine SSH key action
if [ -n "$opt_ssh_key_action" ]; then
  case "$opt_ssh_key_action" in
    generate) key_choice="g" ;;
    add) key_choice="a" ;;
    skip) key_choice="s" ;;
    *)
      printf "Invalid key action: %s (use generate, add, or skip)\n" "$opt_ssh_key_action" >&2
      exit 1
      ;;
  esac
  printf "SSH public key setup: %s\n" "$opt_ssh_key_action"
elif [ "$cfg_prompt_for_confirmation" = "true" ]; then
  key_choice="$(prompt_read "SSH public key setup: (g)enerate, (a)dd existing, (s)kip [default: g]: ")"
else
  case "$cfg_ssh_key_action" in
    generate) key_choice="g" ;;
    add) key_choice="a" ;;
    skip) key_choice="s" ;;
    *) key_choice="g" ;;
  esac
  printf "SSH public key setup: %s\n" "$cfg_ssh_key_action"
fi

pubkey_path="./.pub"
pubkey=""
pubkeys=""

case "$key_choice" in
  a|A)
    if [ -n "$opt_pubkey" ]; then
      # Single key from command line
      printf "%s\n" "$opt_pubkey" > "$pubkey_path"
      pubkey="$opt_pubkey"
      pubkeys="$opt_pubkey"
    elif [ -n "$cfg_ssh_public_keys" ]; then
      # Multiple keys from config file
      pubkeys="$cfg_ssh_public_keys"
      # Use first key for backward compatibility with pubkey variable
      pubkey="$(printf "%s" "$cfg_ssh_public_keys" | head -1)"
      printf "Using %s SSH public key(s) from config file\n" "$(printf "%s" "$cfg_ssh_public_keys" | wc -l | tr -d ' ')"
    else
      input_pubkey="$(prompt_read "Public key to install: ")"
      if [ -n "$input_pubkey" ]; then
        printf "%s\n" "$input_pubkey" > "$pubkey_path"
        pubkey="$input_pubkey"
        pubkeys="$input_pubkey"
      fi
    fi
    ;;
  s|S)
    pubkey=""
    pubkeys=""
    ;;
  *)
    key_path="./.secret.pem"
    if [ ! -f "$key_path" ]; then
      ssh-keygen -t ecdsa -b 521 -N "" -f "$key_path"
    fi
    cp "${key_path}.pub" "$pubkey_path"
    pubkey="$(cat "$pubkey_path")"
    pubkeys="$pubkey"
    ;;
esac

# Detect OS
is_macos=""
is_openwrt=""
if [ "$(uname -s)" = "Darwin" ]; then
  is_macos="true"
elif [ -f /etc/openwrt_release ] || grep -q '^ID=.*openwrt' /etc/os-release 2>/dev/null; then
  is_openwrt="true"
fi

# Cache sudo credentials (skip on macOS with Homebrew if not needed)
if [ "$is_macos" = "true" ]; then
  printf "Running on macOS - sudo may not be required for most operations...\n"
  # Try to cache sudo, but don't fail if it doesn't work
  sudo -v 2>/dev/null || true
else
  printf "Caching sudo credentials...\n"
  sudo -v || { printf "Failed to cache sudo credentials. Some operations may fail.\n" >&2; }
fi

pkg_update() {
  if [ "$is_macos" = "true" ] && command -v brew >/dev/null 2>&1; then
    brew update
    # Only upgrade formulas (not casks) to avoid sudo password prompts
    brew upgrade --formula || true
  elif command -v apt-get >/dev/null 2>&1; then
    sudo -n apt-get update -y
    sudo -n apt-get upgrade -y
  elif command -v dnf >/dev/null 2>&1; then
    sudo -n dnf -y upgrade --refresh
  elif command -v yum >/dev/null 2>&1; then
    sudo -n yum -y update
  elif command -v pacman >/dev/null 2>&1; then
    sudo -n pacman -Syu --noconfirm
  elif command -v apk >/dev/null 2>&1; then
    sudo -n apk update
    sudo -n apk upgrade
  elif command -v opkg >/dev/null 2>&1; then
    # OpenWrt - create lock directory if missing and update
    sudo -n mkdir -p /var/lock 2>/dev/null || mkdir -p /var/lock 2>/dev/null || true
    sudo -n opkg update
  else
    printf "No supported package manager found.\n" >&2
    return 1
  fi
}

pkg_install() {
  packages="$*"
  if [ "$is_macos" = "true" ] && command -v brew >/dev/null 2>&1; then
    brew install $packages
  elif command -v apt-get >/dev/null 2>&1; then
    sudo -n apt-get install -y $packages
  elif command -v dnf >/dev/null 2>&1; then
    sudo -n dnf -y install $packages
  elif command -v yum >/dev/null 2>&1; then
    sudo -n yum -y install $packages
  elif command -v pacman >/dev/null 2>&1; then
    sudo -n pacman -S --noconfirm $packages
  elif command -v apk >/dev/null 2>&1; then
    sudo -n apk add $packages
  elif command -v opkg >/dev/null 2>&1; then
    sudo -n opkg install $packages
  else
    printf "No supported package manager found.\n" >&2
    return 1
  fi
}

openssh_package="openssh-server"
if [ "$is_macos" = "true" ]; then
  openssh_package=""  # macOS has SSH built-in
elif [ "$is_openwrt" = "true" ]; then
  openssh_package="openssh-server"  # OpenWrt (both opkg and apk versions)
elif command -v pacman >/dev/null 2>&1; then
  openssh_package="openssh"
elif command -v apk >/dev/null 2>&1; then
  openssh_package="openssh"  # Alpine Linux
fi

if [ "$cfg_skip_package_update" = "true" ]; then
  printf "Skipping package update (disabled in config)...\n"
else
  printf "Updating packages...\n"
  pkg_update
fi

# SSH server setup (skip on macOS - has built-in SSH)
if [ "$is_macos" != "true" ]; then
  printf "Installing openssh-server if missing...\n"
  if ! command -v sshd >/dev/null 2>&1; then
    pkg_install "$openssh_package"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    sudo -n systemctl enable sshd >/dev/null 2>&1 || sudo -n systemctl enable ssh >/dev/null 2>&1 || true
    sudo -n systemctl start sshd >/dev/null 2>&1 || sudo -n systemctl start ssh >/dev/null 2>&1 || true
  fi

  printf "Configuring firewall for SSH...\n"
  if command -v ufw >/dev/null 2>&1; then
    sudo -n ufw allow "${server_port}/tcp" || true
  elif command -v firewall-cmd >/dev/null 2>&1; then
    sudo -n firewall-cmd --permanent --add-port="${server_port}/tcp" 2>/dev/null || true
    sudo -n firewall-cmd --reload 2>/dev/null || true
  elif command -v iptables >/dev/null 2>&1; then
    if ! sudo -n iptables -C INPUT -p tcp --dport "$server_port" -j ACCEPT 2>/dev/null; then
      sudo -n iptables -A INPUT -p tcp --dport "$server_port" -j ACCEPT 2>/dev/null || true
    fi
  fi

  printf "Setting passwordless sudo for current user...\n"
  current_user="$(id -un)"
  sudo -n mkdir -p /etc/sudoers.d
  sudo -n sh -c "echo \"${current_user} ALL=(ALL:ALL) NOPASSWD: ALL\" > /etc/sudoers.d/${current_user}"
  sudo -n chmod 0440 "/etc/sudoers.d/${current_user}"
else
  printf "Skipping SSH server setup (macOS has built-in SSH)...\n"
fi

printf "Installing base packages...\n"
if [ "$is_macos" = "true" ]; then
  # macOS with Homebrew
  pkg_install zsh figlet git curl vim neofetch
elif [ "$is_openwrt" = "true" ]; then
  # OpenWrt - figlet/screenfetch not available, use minimal set
  # Install git-http for https support, shadow-chsh for chsh command
  if command -v opkg >/dev/null 2>&1; then
    pkg_install zsh bash git git-http curl vim shadow-chsh
  else
    # OpenWrt with apk (newer versions) - git-http is a separate package
    pkg_install zsh bash git git-http curl vim shadow-chsh
  fi
elif command -v apk >/dev/null 2>&1; then
  # Alpine Linux - screenfetch/neofetch not available in main repos
  pkg_install zsh figlet git curl vim
else
  pkg_install zsh figlet screenfetch git curl vim
fi

printf "Installing build tools...\n"
if [ "$is_macos" = "true" ]; then
  # macOS - check for Xcode Command Line Tools
  if ! xcode-select -p >/dev/null 2>&1; then
    printf "Installing Xcode Command Line Tools...\n"
    xcode-select --install 2>/dev/null || true
    printf "Please complete the Xcode Command Line Tools installation if prompted.\n"
  else
    printf "Xcode Command Line Tools already installed.\n"
  fi
elif [ "$is_openwrt" = "true" ]; then
  # OpenWrt - install build tools and GNU utilities (needed for uv/rustup/cargo installers)
  # Note: build-base is not available on OpenWrt, use make and gcc directly
  # GNU tar/grep are needed because BusyBox versions lack required features
  if command -v opkg >/dev/null 2>&1; then
    sudo -n opkg install make gcc tar grep 2>/dev/null || true
  else
    sudo -n apk add make gcc tar grep 2>/dev/null || true
  fi
  # Fix /tmp permissions if needed (OpenWrt containers may have restrictive permissions)
  if ! mktemp -u >/dev/null 2>&1; then
    sudo -n chmod 1777 /tmp 2>/dev/null || true
  fi
elif command -v apt-get >/dev/null 2>&1; then
  sudo -n apt-get install -y build-essential 2>/dev/null || true
elif command -v dnf >/dev/null 2>&1; then
  sudo -n dnf -y install gcc 2>/dev/null || true
elif command -v yum >/dev/null 2>&1; then
  sudo -n yum -y install gcc 2>/dev/null || true
elif command -v pacman >/dev/null 2>&1; then
  sudo -n pacman -S --noconfirm base-devel 2>/dev/null || true
elif command -v apk >/dev/null 2>&1; then
  sudo -n apk add build-base 2>/dev/null || true
fi

if [ "$cfg_pkg_uv" = "true" ]; then
  printf "Installing uv...\n"
  if ! command -v uv >/dev/null 2>&1; then
    curl -fsSL https://astral.sh/uv/install.sh | sh
  fi
else
  printf "Skipping uv installation (disabled in config)...\n"
fi

if [ "$cfg_pkg_cargo" = "true" ]; then
  printf "Installing cargo (Rust)...\n"
  if ! command -v cargo >/dev/null 2>&1; then
    curl -fsSL https://sh.rustup.rs | sh -s -- -y
  fi
else
  printf "Skipping cargo installation (disabled in config)...\n"
fi

if [ "$cfg_pkg_ruff" = "true" ]; then
  printf "Installing ruff...\n"
  "$HOME/.local/bin/uv" tool install ruff 2>/dev/null || uv tool install ruff
else
  printf "Skipping ruff installation (disabled in config)...\n"
fi

if [ "$cfg_pkg_ty" = "true" ]; then
  printf "Installing ty...\n"
  "$HOME/.local/bin/uv" tool install ty 2>/dev/null || uv tool install ty
else
  printf "Skipping ty installation (disabled in config)...\n"
fi

# Install modern CLI tools (Rust-based tools via cargo)
cargo_bin="$HOME/.cargo/bin/cargo"
install_cargo_tool() {
  tool_name="$1"
  cargo_pkg="${2:-$1}"
  if [ -x "$cargo_bin" ]; then
    "$cargo_bin" install "$cargo_pkg"
  elif command -v cargo >/dev/null 2>&1; then
    cargo install "$cargo_pkg"
  else
    printf "Warning: cargo not available, skipping %s\n" "$tool_name"
  fi
}

if [ "$cfg_cli_fzf" = "true" ]; then
  printf "Installing fzf...\n"
  if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all --no-bash --no-fish
  fi
fi

if [ "$cfg_cli_hishtory" = "true" ]; then
  printf "Installing hishtory...\n"
  curl -fsSL https://hishtory.dev/install.py | python3 -
fi

if [ "$cfg_cli_eza" = "true" ]; then
  printf "Installing eza...\n"
  install_cargo_tool eza
fi

if [ "$cfg_cli_bat" = "true" ]; then
  printf "Installing bat...\n"
  install_cargo_tool bat
fi

if [ "$cfg_cli_delta" = "true" ]; then
  printf "Installing delta...\n"
  install_cargo_tool delta git-delta
fi

if [ "$cfg_cli_dust" = "true" ]; then
  printf "Installing dust...\n"
  install_cargo_tool dust du-dust
fi

if [ "$cfg_cli_duf" = "true" ]; then
  printf "Installing duf...\n"
  pkg_install duf || printf "Warning: duf not available in package manager\n"
fi

if [ "$cfg_cli_fd" = "true" ]; then
  printf "Installing fd...\n"
  install_cargo_tool fd fd-find
fi

if [ "$cfg_cli_ripgrep" = "true" ]; then
  printf "Installing ripgrep...\n"
  install_cargo_tool rg ripgrep
fi

if [ "$cfg_cli_mcfly" = "true" ]; then
  printf "Installing mcfly...\n"
  install_cargo_tool mcfly
fi

if [ "$cfg_cli_sd" = "true" ]; then
  printf "Installing sd...\n"
  install_cargo_tool sd
fi

if [ "$cfg_cli_choose" = "true" ]; then
  printf "Installing choose...\n"
  install_cargo_tool choose
fi

if [ "$cfg_cli_cheat" = "true" ]; then
  printf "Installing cheat...\n"
  pkg_install cheat || printf "Warning: cheat not available in package manager\n"
fi

if [ "$cfg_cli_bottom" = "true" ]; then
  printf "Installing bottom...\n"
  install_cargo_tool btm bottom
fi

if [ "$cfg_cli_procs" = "true" ]; then
  printf "Installing procs...\n"
  install_cargo_tool procs
fi

if [ "$cfg_cli_zoxide" = "true" ]; then
  printf "Installing zoxide...\n"
  install_cargo_tool zoxide
fi

if [ "$cfg_cli_lsd" = "true" ]; then
  printf "Installing lsd...\n"
  install_cargo_tool lsd
fi

if [ "$cfg_cli_gping" = "true" ]; then
  printf "Installing gping...\n"
  install_cargo_tool gping
fi

if [ "$cfg_cli_lazygit" = "true" ]; then
  printf "Installing lazygit...\n"
  if [ "$is_macos" = "true" ]; then
    pkg_install lazygit
  else
    install_cargo_tool lazygit
  fi
fi

if [ "$cfg_cli_lazydocker" = "true" ]; then
  printf "Installing lazydocker...\n"
  if [ "$is_macos" = "true" ]; then
    pkg_install lazydocker
  else
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  fi
fi

if [ "$cfg_cli_tldr" = "true" ]; then
  printf "Installing tldr...\n"
  if [ "$is_macos" = "true" ]; then
    pkg_install tldr
  else
    install_cargo_tool tldr tealdeer
  fi
fi

if [ "$cfg_cli_jq" = "true" ]; then
  printf "Installing jq...\n"
  pkg_install jq
fi

if [ "$cfg_cli_yq" = "true" ]; then
  printf "Installing yq...\n"
  if [ "$is_macos" = "true" ]; then
    pkg_install yq
  else
    # Install via pip as fallback
    pip3 install yq 2>/dev/null || pkg_install yq || printf "Warning: yq not available\n"
  fi
fi

if [ "$cfg_cli_hyperfine" = "true" ]; then
  printf "Installing hyperfine...\n"
  install_cargo_tool hyperfine
fi

if [ "$cfg_cli_tokei" = "true" ]; then
  printf "Installing tokei...\n"
  install_cargo_tool tokei
fi

if [ "$cfg_cli_broot" = "true" ]; then
  printf "Installing broot...\n"
  if [ "$is_macos" = "true" ]; then
    pkg_install broot
  else
    install_cargo_tool broot
  fi
fi

if [ "$cfg_cli_atuin" = "true" ]; then
  printf "Installing atuin...\n"
  if [ "$is_macos" = "true" ]; then
    pkg_install atuin
  else
    install_cargo_tool atuin
  fi
fi

if [ "$cfg_cli_xh" = "true" ]; then
  printf "Installing xh...\n"
  install_cargo_tool xh
fi

if [ "$cfg_cli_difftastic" = "true" ]; then
  printf "Installing difftastic...\n"
  install_cargo_tool difft difftastic
fi

if [ "$cfg_cli_zellij" = "true" ]; then
  printf "Installing zellij...\n"
  if [ "$is_macos" = "true" ]; then
    pkg_install zellij
  else
    install_cargo_tool zellij
  fi
fi

# Set up MOTD (skip on macOS - doesn't use update-motd.d)
if [ "$is_macos" != "true" ]; then
  printf "Set up motd...\n"
  sudo -n mkdir -p /etc/update-motd.d
  sudo -n rm -f /etc/update-motd.d/01-hello
  sudo -n sh -c 'echo "#!/bin/bash" >> /etc/update-motd.d/01-hello'
  sudo -n sh -c "echo \"/usr/bin/screenfetch -d '-disk' -w 80\" >> /etc/update-motd.d/01-hello"
  sudo -n sh -c "echo \"figlet -t ${servername}\" >> /etc/update-motd.d/01-hello"
  sudo -n chmod a+x /etc/update-motd.d/01-hello
else
  printf "Skipping MOTD setup (not applicable on macOS)...\n"
fi

if [ -n "$pubkeys" ]; then
  key_count="$(printf "%s" "$pubkeys" | wc -l | tr -d ' ')"
  printf "Registering %s SSH public key(s)...\n" "$key_count"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  # Add each key on a separate line
  printf "%s\n" "$pubkeys" | while IFS= read -r key; do
    if [ -n "$key" ]; then
      # Check if key already exists to avoid duplicates
      if ! grep -qF "$key" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
        printf "%s\n" "$key" >> "$HOME/.ssh/authorized_keys"
      fi
    fi
  done
  chmod 600 "$HOME/.ssh/authorized_keys"
else
  printf "Skipping SSH public key registration...\n"
fi

printf "Setting default shell to zsh...\n"
if command -v zsh >/dev/null 2>&1; then
  current_user="${USER:-$(id -un)}"
  zsh_path="$(command -v zsh)"
  # Check if current shell is already zsh
  current_shell=$(getent passwd "$current_user" 2>/dev/null | cut -d: -f7 || dscl . -read /Users/"$current_user" UserShell 2>/dev/null | awk '{print $2}')
  if [ "$current_shell" = "$zsh_path" ] || [ "$current_shell" = "/bin/zsh" ]; then
    printf "Shell is already zsh, skipping...\n"
  elif [ "$is_macos" = "true" ]; then
    # macOS: chsh doesn't need sudo for current user, but needs password
    # Check if zsh is in /etc/shells
    if ! grep -q "^${zsh_path}$" /etc/shells 2>/dev/null; then
      sudo -n sh -c "echo '$zsh_path' >> /etc/shells" 2>/dev/null || true
    fi
    # On macOS, chsh requires password interactively - skip in non-interactive mode
    if [ -t 0 ]; then
      printf "Run 'chsh -s %s' manually if you want to change your default shell.\n" "$zsh_path"
    else
      printf "Skipping shell change (non-interactive mode, run 'chsh -s %s' manually).\n" "$zsh_path"
    fi
  else
    sudo -n chsh -s "$zsh_path" "$current_user" || true
  fi
fi

if [ "$cfg_skip_zinit" = "true" ]; then
  printf "Skipping zinit setup (disabled in config)...\n"
else
  printf "Setting up zinit and powerlevel10k...\n"
  ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
  if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  fi
  printf "Zinit installed.\n"
fi

if [ "$cfg_pkg_nvm" = "true" ]; then
  printf "Setting up nvm and Node.js...\n"
  if [ "$is_openwrt" = "true" ]; then
    # OpenWrt - use system packages instead of nvm (nvm doesn't work well on OpenWrt)
    printf "Installing Node.js from system packages (OpenWrt)...\n"
    if command -v opkg >/dev/null 2>&1; then
      pkg_install node node-npm 2>/dev/null || printf "Warning: Node.js packages not available on this OpenWrt installation\n"
    else
      # OpenWrt with apk (newer versions) - nodejs may not be available
      pkg_install nodejs npm 2>/dev/null || printf "Warning: Node.js packages not available on this OpenWrt installation\n"
    fi
    if command -v npm >/dev/null 2>&1; then
      printf "Installing Claude Code, OpenCode, and Codex CLIs...\n"
      npm install -g @anthropic-ai/claude-code opencode-ai @openai/codex 2>/dev/null || printf "Warning: Some npm packages may not install on OpenWrt\n"
    else
      printf "Skipping npm package installation (Node.js not available)\n"
    fi
  elif command -v apk >/dev/null 2>&1; then
    # Alpine Linux - use system nodejs package (nvm requires glibc)
    printf "Installing Node.js from apk (Alpine)...\n"
    pkg_install nodejs npm
    if command -v npm >/dev/null 2>&1; then
      printf "Installing Claude Code, OpenCode, and Codex CLIs...\n"
      npm install -g @anthropic-ai/claude-code opencode-ai @openai/codex 2>/dev/null || printf "Warning: Some npm packages may not install on Alpine\n"
    fi
  else
    if ! command -v bash >/dev/null 2>&1; then
      pkg_install bash
    fi
    nvm_dir="$HOME/.nvm"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | PROFILE=/dev/null NVM_DIR="$nvm_dir" bash
    if [ -s "$nvm_dir/nvm.sh" ] && command -v bash >/dev/null 2>&1; then
      bash -c ". \"$nvm_dir/nvm.sh\" && nvm install --lts --latest-npm && nvm alias default 'lts/*' && nvm use --lts"
      printf "Installing Claude Code, OpenCode, and Codex CLIs...\n"
      bash -c ". \"$nvm_dir/nvm.sh\" && nvm use --lts >/dev/null && npm install -g @anthropic-ai/claude-code opencode-ai @openai/codex"
    fi
  fi
else
  printf "Skipping nvm and Node.js setup (disabled in config)...\n"
fi

if [ "$cfg_skip_mcp_setup" = "true" ]; then
  printf "Skipping MCP setup (disabled in config)...\n"
else
  printf "Configuring global MCP servers...\n"
  mcp_repo_dir="$script_dir/mcp"
  mcp_config_dir="$HOME/.config/mcp"
  mcp_servers_dir="$mcp_config_dir/servers"
  mcp_config="$mcp_config_dir/mcp.json"
  mkdir -p "$mcp_servers_dir"

  # Check if a server is disabled based on config toggles
  is_server_enabled() {
    server_name="$1"
    case "$server_name" in
      auggie-context) [ "$cfg_mcp_auggie_context" = "true" ] ;;
      claude-context) [ "$cfg_mcp_claude_context" = "true" ] ;;
      context7) [ "$cfg_mcp_context7" = "true" ] ;;
      fetch) [ "$cfg_mcp_fetch" = "true" ] ;;
      filesystem) [ "$cfg_mcp_filesystem" = "true" ] ;;
      git) [ "$cfg_mcp_git" = "true" ] ;;
      github) [ "$cfg_mcp_github" = "true" ] ;;
      jupyter) [ "$cfg_mcp_jupyter" = "true" ] ;;
      memory) [ "$cfg_mcp_memory" = "true" ] ;;
      playwright) [ "$cfg_mcp_playwright" = "true" ] ;;
      sequential-thinking) [ "$cfg_mcp_sequential_thinking" = "true" ] ;;
      *) return 0 ;;  # Unknown servers are enabled by default
    esac
  }

  if [ -d "$mcp_repo_dir/servers" ]; then
    for server_file in "$mcp_repo_dir"/servers/*.json; do
      [ -f "$server_file" ] || continue
      server_name="$(basename "$server_file" .json)"
      if ! is_server_enabled "$server_name"; then
        printf "  Skipping disabled server: %s\n" "$server_name"
        continue
      fi
      cp "$server_file" "$mcp_servers_dir/"
    done
  fi

  build_mcp_config() {
    printf "{\n  \"mcpServers\": {\n" > "$mcp_config"
    first=1
    for server_file in "$mcp_servers_dir"/*.json; do
      [ -f "$server_file" ] || continue
      server_name="$(basename "$server_file" .json)"
      if ! is_server_enabled "$server_name"; then
        continue
      fi
      if [ $first -eq 0 ]; then
        printf ",\n" >> "$mcp_config"
      fi
      first=0
      while IFS= read -r line || [ -n "$line" ]; do
        while :; do
          case "$line" in
            *__HOME__*)
              prefix=${line%%__HOME__*}
              suffix=${line#*__HOME__}
              line=${prefix}${HOME}${suffix}
              ;;
            *)
              break
              ;;
          esac
        done
        printf "    %s\n" "$line" >> "$mcp_config"
      done < "$server_file"
    done
    printf "  }\n}\n" >> "$mcp_config"
  }
  build_mcp_config

  link_mcp_config() {
    target="$1"
    if [ ! -e "$target" ]; then
      mkdir -p "$(dirname "$target")"
      ln -s "$mcp_config" "$target"
    fi
  }

  # Link MCP config to editors based on configuration
  [ "$cfg_editor_cursor" = "true" ] && link_mcp_config "$HOME/.cursor/mcp.json"
  [ "$cfg_editor_codex" = "true" ] && link_mcp_config "$HOME/.config/codex/mcp.json"
  [ "$cfg_editor_opencode" = "true" ] && link_mcp_config "$HOME/.config/opencode/mcp.json"
  [ "$cfg_editor_antigravity" = "true" ] && link_mcp_config "$HOME/.config/antigravity/mcp.json"
  [ "$cfg_editor_claude_desktop" = "true" ] && link_mcp_config "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
fi

printf "Configuring zsh settings...\n"
zshrc="$HOME/.zshrc"
touch "$zshrc"
ensure_zshrc_line() {
  line="$1"
  if ! grep -Fqx "$line" "$zshrc"; then
    printf "%s\n" "$line" >> "$zshrc"
  fi
}
set_zshrc_value() {
  key="$1"
  value="$2"
  if grep -q "^${key}=" "$zshrc"; then
    tmp="${zshrc}.tmp"
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        ${key}=*) printf "%s\n" "${key}=${value}" ;;
        *) printf "%s\n" "$line" ;;
      esac
    done < "$zshrc" > "$tmp"
    mv "$tmp" "$zshrc"
  else
    printf "%s\n" "${key}=${value}" >> "$zshrc"
  fi
}
# Zinit initialization
ensure_zshrc_line 'ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"'
ensure_zshrc_line '[ -f "$ZINIT_HOME/zinit.zsh" ] && source "$ZINIT_HOME/zinit.zsh"'

# Powerlevel10k theme
ensure_zshrc_line 'zinit ice depth=1; zinit light romkatv/powerlevel10k'

# Zinit plugins
ensure_zshrc_line 'zinit light zsh-users/zsh-autosuggestions'
ensure_zshrc_line 'zinit light zsh-users/zsh-syntax-highlighting'

# Powerlevel10k instant prompt (should be near top of .zshrc, but we add it here for simplicity)
ensure_zshrc_line '# Enable Powerlevel10k instant prompt'
ensure_zshrc_line 'if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then'
ensure_zshrc_line '  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"'
ensure_zshrc_line 'fi'
ensure_zshrc_line '# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh'
ensure_zshrc_line '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'

ensure_zshrc_line 'HISTFILE=~/.histfile'
ensure_zshrc_line 'HISTSIZE=100000'
ensure_zshrc_line 'SAVEHIST=100000'
ensure_zshrc_line 'setopt autocd'
ensure_zshrc_line 'bindkey -e'
ensure_zshrc_line 'export HOMEBREW_NO_ANALYTICS=1'
ensure_zshrc_line 'DISABLE_UPDATE_PROMPT=true'
ensure_zshrc_line 'export EDITOR=vim'
ensure_zshrc_line 'export VISUAL=vim'
ensure_zshrc_line 'alias nano=vim'
ensure_zshrc_line 'export PATH="$HOME/.local/bin:$PATH"'
ensure_zshrc_line 'export PATH="$HOME/.cargo/bin:$PATH"'
ensure_zshrc_line 'export NVM_DIR="$HOME/.nvm"'
ensure_zshrc_line '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
ensure_zshrc_line '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'

# Modern CLI tool aliases (only add if the tool is installed)
[ -x "$HOME/.cargo/bin/eza" ] || command -v eza >/dev/null 2>&1 && ensure_zshrc_line 'alias ls="eza"'
[ -x "$HOME/.cargo/bin/eza" ] || command -v eza >/dev/null 2>&1 && ensure_zshrc_line 'alias ll="eza -l"'
[ -x "$HOME/.cargo/bin/eza" ] || command -v eza >/dev/null 2>&1 && ensure_zshrc_line 'alias la="eza -la"'
[ -x "$HOME/.cargo/bin/bat" ] || command -v bat >/dev/null 2>&1 && ensure_zshrc_line 'alias cat="bat"'
[ -x "$HOME/.cargo/bin/dust" ] || command -v dust >/dev/null 2>&1 && ensure_zshrc_line 'alias du="dust"'
command -v duf >/dev/null 2>&1 && ensure_zshrc_line 'alias df="duf"'
[ -x "$HOME/.cargo/bin/fd" ] || command -v fd >/dev/null 2>&1 && ensure_zshrc_line 'alias find="fd"'
[ -x "$HOME/.cargo/bin/rg" ] || command -v rg >/dev/null 2>&1 && ensure_zshrc_line 'alias grep="rg"'
[ -x "$HOME/.cargo/bin/sd" ] || command -v sd >/dev/null 2>&1 && ensure_zshrc_line 'alias sed="sd"'
[ -x "$HOME/.cargo/bin/choose" ] || command -v choose >/dev/null 2>&1 && ensure_zshrc_line 'alias cut="choose"'
[ -x "$HOME/.cargo/bin/btm" ] || command -v btm >/dev/null 2>&1 && ensure_zshrc_line 'alias top="btm"'
[ -x "$HOME/.cargo/bin/procs" ] || command -v procs >/dev/null 2>&1 && ensure_zshrc_line 'alias ps="procs"'
[ -x "$HOME/.cargo/bin/gping" ] || command -v gping >/dev/null 2>&1 && ensure_zshrc_line 'alias ping="gping"'
[ -x "$HOME/.cargo/bin/lsd" ] || command -v lsd >/dev/null 2>&1 && ensure_zshrc_line 'alias lsd="lsd"'
[ -x "$HOME/.cargo/bin/difft" ] || command -v difft >/dev/null 2>&1 && ensure_zshrc_line 'alias diff="difftastic"'
[ -x "$HOME/.cargo/bin/xh" ] || command -v xh >/dev/null 2>&1 && ensure_zshrc_line 'alias http="xh"'
command -v lazygit >/dev/null 2>&1 && ensure_zshrc_line 'alias lg="lazygit"'
command -v lazydocker >/dev/null 2>&1 && ensure_zshrc_line 'alias lzd="lazydocker"'

# Tool initializations
[ -f "$HOME/.fzf.zsh" ] && ensure_zshrc_line '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh'
[ -x "$HOME/.cargo/bin/zoxide" ] || command -v zoxide >/dev/null 2>&1 && ensure_zshrc_line 'eval "$(zoxide init zsh)"'
[ -x "$HOME/.cargo/bin/zoxide" ] || command -v zoxide >/dev/null 2>&1 && ensure_zshrc_line 'alias cd="z"'
[ -x "$HOME/.cargo/bin/mcfly" ] || command -v mcfly >/dev/null 2>&1 && ensure_zshrc_line 'eval "$(mcfly init zsh)"'
command -v hishtory >/dev/null 2>&1 && ensure_zshrc_line 'eval "$(hishtory init zsh)"'

# Broot file navigator
[ -f "$HOME/.config/broot/launcher/bash/br" ] && ensure_zshrc_line '[ -f ~/.config/broot/launcher/bash/br ] && source ~/.config/broot/launcher/bash/br'

# Atuin shell history
command -v atuin >/dev/null 2>&1 && ensure_zshrc_line 'eval "$(atuin init zsh)"'

# Configure delta as git pager
[ -x "$HOME/.cargo/bin/delta" ] || command -v delta >/dev/null 2>&1 && {
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.side-by-side true
  git config --global merge.conflictstyle diff3
  git config --global diff.colorMoved default
}
