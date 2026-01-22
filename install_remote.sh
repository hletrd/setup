#!/bin/sh

set -e

script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/config.json"

# Command line option defaults (empty = use config/prompt)
opt_server_addr=""
opt_ssh_port=""
opt_ssh_user=""
opt_server_name=""
opt_ssh_key_action=""
opt_pubkey=""
opt_identity_file=""
opt_no_prompt=""
opt_help=""

# Parse command line options
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install development environment on a remote machine via SSH.

Options:
  -H, --host HOST          Server address/hostname (default: localhost)
  -p, --port PORT          SSH port (default: 22)
  -u, --user USER          SSH username (default: current user)
  -n, --name NAME          Server name for MOTD (default: server address)
  -i, --identity FILE      SSH identity file (private key) for authentication
  -k, --key-action ACTION  SSH key action: generate, add, skip (default: generate)
  --pubkey KEY             Public key to install (required if --key-action=add)
  -y, --yes                Non-interactive mode, use defaults without prompting
  -c, --config FILE        Path to config file (default: ./config.json)
  -h, --help               Show this help message

Examples:
  # Non-interactive remote install
  $(basename "$0") -H myserver.com -u admin -y

  # Specify SSH port
  $(basename "$0") -H 192.168.1.100 -p 2222 -u root -y

  # Skip SSH key setup
  $(basename "$0") -H myserver.com -u admin --key-action skip -y

  # Use SSH key for authentication
  $(basename "$0") -H myserver.com -u admin -i ~/.ssh/id_rsa --key-action skip -y

  # Use custom config file
  $(basename "$0") -c /path/to/config.json -y
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -H|--host)
      opt_server_addr="$2"
      shift 2
      ;;
    -p|--port)
      opt_ssh_port="$2"
      shift 2
      ;;
    -u|--user)
      opt_ssh_user="$2"
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
    -i|--identity)
      opt_identity_file="$2"
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
  if [ -f "$file" ]; then
    case "$key" in
      *.*)
        parent="${key%%.*}"
        child="${key#*.}"
        sed -n "/$parent/,/}/p" "$file" | grep "\"$child\"" 2>/dev/null | sed 's/.*: *"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/' | head -1 || true
        ;;
      *)
        grep "\"$key\"" "$file" 2>/dev/null | sed 's/.*: *"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/' | head -1 || true
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
    sed -n "/\"$key\"/,/]/p" "$file" 2>/dev/null | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | grep -v "$key" || true
  fi
}

# Load configuration
cfg_prompt_for_confirmation="true"
cfg_ssh_port="22"
cfg_server_address="localhost"
cfg_ssh_key_action="generate"
cfg_ssh_public_keys=""
cfg_skip_package_update="false"
cfg_skip_zinit="false"
cfg_skip_mcp_setup="false"

# Package manager toggles (default all enabled)
cfg_pkg_nvm="true"
cfg_pkg_uv="true"
cfg_pkg_cargo="true"
cfg_pkg_ruff="true"
cfg_pkg_ty="true"

# CLI tools toggles (default all enabled)
cfg_cli_hishtory="true"
cfg_cli_fzf="true"
cfg_cli_eza="true"
cfg_cli_bat="true"
cfg_cli_delta="true"
cfg_cli_dust="true"
cfg_cli_duf="true"
cfg_cli_fd="true"
cfg_cli_ripgrep="true"
cfg_cli_mcfly="true"
cfg_cli_sd="true"
cfg_cli_choose="true"
cfg_cli_cheat="true"
cfg_cli_bottom="true"
cfg_cli_procs="true"
cfg_cli_zoxide="true"
cfg_cli_lsd="true"
cfg_cli_gping="true"
cfg_cli_lazygit="true"
cfg_cli_lazydocker="true"
cfg_cli_tldr="true"
cfg_cli_jq="true"
cfg_cli_yq="true"
cfg_cli_hyperfine="true"
cfg_cli_tokei="true"
cfg_cli_broot="true"
cfg_cli_atuin="true"
cfg_cli_xh="true"
cfg_cli_difftastic="true"
cfg_cli_zellij="true"

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
  if [ -n "$val" ]; then
    eval "$var_name=\"$val\""
  fi
}

if [ -f "$config_file" ]; then
  printf "Loading configuration from %s\n" "$config_file"
  set_if_present cfg_prompt_for_confirmation "$(json_get_bool "prompt_for_confirmation" "$config_file")"
  set_if_present cfg_ssh_port "$(json_get "ssh_port" "$config_file")"
  set_if_present cfg_server_address "$(json_get "server_address" "$config_file")"
  set_if_present cfg_ssh_user "$(json_get "ssh_user" "$config_file")"
  set_if_present cfg_ssh_key_action "$(json_get "ssh_key_action" "$config_file")"
  cfg_ssh_public_keys="$(json_get_array "ssh_public_keys" "$config_file")"
  set_if_present cfg_skip_package_update "$(json_get_bool "skip_package_update" "$config_file")"
  set_if_present cfg_skip_zinit "$(json_get_bool "skip_zinit" "$config_file")"
  set_if_present cfg_skip_mcp_setup "$(json_get_bool "skip_mcp_setup" "$config_file")"

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
[ -n "$opt_server_addr" ] && cfg_server_address="$opt_server_addr"
[ -n "$opt_ssh_port" ] && cfg_ssh_port="$opt_ssh_port"
[ -n "$opt_ssh_user" ] && cfg_ssh_user="$opt_ssh_user"
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

default_user="${cfg_ssh_user:-$(id -un)}"

# Use command line options if provided, otherwise prompt/use default
if [ -n "$opt_server_addr" ]; then
  server_addr="$opt_server_addr"
  printf "Server address: %s\n" "$server_addr"
else
  server_addr="$(prompt_or_default "Server address (default: ${cfg_server_address}): " "$cfg_server_address")"
fi

if [ -n "$opt_ssh_port" ]; then
  server_port="$opt_ssh_port"
  printf "SSH port: %s\n" "$server_port"
else
  server_port="$(prompt_or_default "SSH port (default: ${cfg_ssh_port}): " "$cfg_ssh_port")"
fi

if [ -n "$opt_ssh_user" ]; then
  ssh_user="$opt_ssh_user"
  printf "SSH user: %s\n" "$ssh_user"
else
  ssh_user="$(prompt_or_default "SSH username (default: ${default_user}): " "$default_user")"
fi

if [ -n "$opt_server_name" ]; then
  servername="$opt_server_name"
  printf "Server name: %s\n" "$servername"
else
  servername="$(prompt_or_default "Server name for MOTD (default: ${server_addr}): " "$server_addr")"
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

# Build SSH options
ssh_opts="-p $server_port"
[ -n "$opt_identity_file" ] && ssh_opts="$ssh_opts -i $opt_identity_file"
ssh_opts="$ssh_opts -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

remote_script_path="/tmp/setup-bootstrap.$$"
# Pass configuration values as environment variables to the remote script
# shellcheck disable=SC2086
ssh $ssh_opts "$ssh_user@$server_addr" "cat > \"$remote_script_path\" && chmod 700 \"$remote_script_path\"" <<EOF
	set -e

	# Configuration passed from local config.json
	cfg_skip_package_update="$cfg_skip_package_update"
	cfg_skip_zinit="$cfg_skip_zinit"
	cfg_skip_mcp_setup="$cfg_skip_mcp_setup"

	# Package manager toggles
	cfg_pkg_nvm="$cfg_pkg_nvm"
	cfg_pkg_uv="$cfg_pkg_uv"
	cfg_pkg_cargo="$cfg_pkg_cargo"
	cfg_pkg_ruff="$cfg_pkg_ruff"
	cfg_pkg_ty="$cfg_pkg_ty"

	# CLI tools toggles
	cfg_cli_hishtory="$cfg_cli_hishtory"
	cfg_cli_fzf="$cfg_cli_fzf"
	cfg_cli_eza="$cfg_cli_eza"
	cfg_cli_bat="$cfg_cli_bat"
	cfg_cli_delta="$cfg_cli_delta"
	cfg_cli_dust="$cfg_cli_dust"
	cfg_cli_duf="$cfg_cli_duf"
	cfg_cli_fd="$cfg_cli_fd"
	cfg_cli_ripgrep="$cfg_cli_ripgrep"
	cfg_cli_mcfly="$cfg_cli_mcfly"
	cfg_cli_sd="$cfg_cli_sd"
	cfg_cli_choose="$cfg_cli_choose"
	cfg_cli_cheat="$cfg_cli_cheat"
	cfg_cli_bottom="$cfg_cli_bottom"
	cfg_cli_procs="$cfg_cli_procs"
	cfg_cli_zoxide="$cfg_cli_zoxide"
	cfg_cli_lsd="$cfg_cli_lsd"
	cfg_cli_gping="$cfg_cli_gping"
	cfg_cli_lazygit="$cfg_cli_lazygit"
	cfg_cli_lazydocker="$cfg_cli_lazydocker"
	cfg_cli_tldr="$cfg_cli_tldr"
	cfg_cli_jq="$cfg_cli_jq"
	cfg_cli_yq="$cfg_cli_yq"
	cfg_cli_hyperfine="$cfg_cli_hyperfine"
	cfg_cli_tokei="$cfg_cli_tokei"
	cfg_cli_broot="$cfg_cli_broot"
	cfg_cli_atuin="$cfg_cli_atuin"
	cfg_cli_xh="$cfg_cli_xh"
	cfg_cli_difftastic="$cfg_cli_difftastic"
	cfg_cli_zellij="$cfg_cli_zellij"

	# MCP server toggles
	cfg_mcp_auggie_context="$cfg_mcp_auggie_context"
	cfg_mcp_claude_context="$cfg_mcp_claude_context"
	cfg_mcp_context7="$cfg_mcp_context7"
	cfg_mcp_fetch="$cfg_mcp_fetch"
	cfg_mcp_filesystem="$cfg_mcp_filesystem"
	cfg_mcp_git="$cfg_mcp_git"
	cfg_mcp_github="$cfg_mcp_github"
	cfg_mcp_jupyter="$cfg_mcp_jupyter"
	cfg_mcp_memory="$cfg_mcp_memory"
	cfg_mcp_playwright="$cfg_mcp_playwright"
	cfg_mcp_sequential_thinking="$cfg_mcp_sequential_thinking"

	printf "Caching sudo credentials...\n"
	sudo -v

if [ -f /etc/os-release ]; then
  . /etc/os-release
  distro_id="\$ID"
else
  distro_id=""
fi

# Detect OpenWrt specifically
is_openwrt=""
if [ -f /etc/openwrt_release ] || [ "\$distro_id" = "openwrt" ]; then
  is_openwrt="true"
fi

pkg_update() {
  if command -v apt-get >/dev/null 2>&1; then
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
  packages="\$*"
  if command -v apt-get >/dev/null 2>&1; then
    sudo -n apt-get install -y \$packages
  elif command -v dnf >/dev/null 2>&1; then
    sudo -n dnf -y install \$packages
  elif command -v yum >/dev/null 2>&1; then
    sudo -n yum -y install \$packages
  elif command -v pacman >/dev/null 2>&1; then
    sudo -n pacman -S --noconfirm \$packages
  elif command -v apk >/dev/null 2>&1; then
    sudo -n apk add \$packages
  elif command -v opkg >/dev/null 2>&1; then
    sudo -n opkg install \$packages
  else
    printf "No supported package manager found.\n" >&2
    return 1
  fi
}

openssh_package="openssh-server"
if [ "\$is_openwrt" = "true" ]; then
  openssh_package="openssh-server"  # OpenWrt (both opkg and apk versions)
elif command -v pacman >/dev/null 2>&1; then
  openssh_package="openssh"
elif command -v apk >/dev/null 2>&1; then
  openssh_package="openssh"  # Alpine Linux
fi

if [ "\$cfg_skip_package_update" = "true" ]; then
  printf "Skipping package update (disabled in config)...\n"
else
  printf "Updating packages...\n"
  pkg_update
fi

printf "Installing openssh-server if missing...\n"
if ! command -v sshd >/dev/null 2>&1; then
  pkg_install "\$openssh_package"
fi

if command -v systemctl >/dev/null 2>&1; then
  sudo -n systemctl enable sshd >/dev/null 2>&1 || sudo -n systemctl enable ssh >/dev/null 2>&1 || true
  sudo -n systemctl start sshd >/dev/null 2>&1 || sudo -n systemctl start ssh >/dev/null 2>&1 || true
fi

printf "Configuring firewall for SSH...\n"
ssh_port="\$1"
if command -v ufw >/dev/null 2>&1; then
  sudo -n ufw allow "\${ssh_port}/tcp" || true
elif command -v firewall-cmd >/dev/null 2>&1; then
  sudo -n firewall-cmd --permanent --add-port="\${ssh_port}/tcp" 2>/dev/null || true
  sudo -n firewall-cmd --reload 2>/dev/null || true
elif command -v iptables >/dev/null 2>&1; then
  if ! sudo -n iptables -C INPUT -p tcp --dport "\$ssh_port" -j ACCEPT 2>/dev/null; then
    sudo -n iptables -A INPUT -p tcp --dport "\$ssh_port" -j ACCEPT 2>/dev/null || true
  fi
fi

printf "Setting passwordless sudo for current user...\n"
current_user="\$(id -un)"
sudo -n mkdir -p /etc/sudoers.d
sudo -n sh -c "echo \"\${current_user} ALL=(ALL:ALL) NOPASSWD: ALL\" > /etc/sudoers.d/\${current_user}"
sudo -n chmod 0440 "/etc/sudoers.d/\${current_user}"

printf "Installing base packages...\n"
if [ "\$is_openwrt" = "true" ]; then
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
if [ "\$is_openwrt" = "true" ]; then
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

if [ "\$cfg_pkg_uv" = "true" ]; then
  printf "Installing uv...\n"
  if ! command -v uv >/dev/null 2>&1; then
    curl -fsSL https://astral.sh/uv/install.sh | sh
  fi
else
  printf "Skipping uv installation (disabled in config)...\n"
fi

if [ "\$cfg_pkg_cargo" = "true" ]; then
  printf "Installing cargo (Rust)...\n"
  if ! command -v cargo >/dev/null 2>&1; then
    curl -fsSL https://sh.rustup.rs | sh -s -- -y
  fi
else
  printf "Skipping cargo installation (disabled in config)...\n"
fi

if [ "\$cfg_pkg_ruff" = "true" ]; then
  printf "Installing ruff...\n"
  "\$HOME/.local/bin/uv" tool install ruff 2>/dev/null || uv tool install ruff
else
  printf "Skipping ruff installation (disabled in config)...\n"
fi

if [ "\$cfg_pkg_ty" = "true" ]; then
  printf "Installing ty...\n"
  "\$HOME/.local/bin/uv" tool install ty 2>/dev/null || uv tool install ty
else
  printf "Skipping ty installation (disabled in config)...\n"
fi

# Install modern CLI tools (Rust-based tools via cargo)
cargo_bin="\$HOME/.cargo/bin/cargo"
install_cargo_tool() {
  tool_name="\$1"
  cargo_pkg="\${2:-\$1}"
  if [ -x "\$cargo_bin" ]; then
    "\$cargo_bin" install "\$cargo_pkg"
  elif command -v cargo >/dev/null 2>&1; then
    cargo install "\$cargo_pkg"
  else
    printf "Warning: cargo not available, skipping %s\n" "\$tool_name"
  fi
}

if [ "\$cfg_cli_fzf" = "true" ]; then
  printf "Installing fzf...\n"
  if [ ! -d "\$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "\$HOME/.fzf"
    "\$HOME/.fzf/install" --all --no-bash --no-fish
  fi
fi

if [ "\$cfg_cli_hishtory" = "true" ]; then
  printf "Installing hishtory...\n"
  curl -fsSL https://hishtory.dev/install.py | python3 -
fi

if [ "\$cfg_cli_eza" = "true" ]; then
  printf "Installing eza...\n"
  install_cargo_tool eza
fi

if [ "\$cfg_cli_bat" = "true" ]; then
  printf "Installing bat...\n"
  install_cargo_tool bat
fi

if [ "\$cfg_cli_delta" = "true" ]; then
  printf "Installing delta...\n"
  install_cargo_tool delta git-delta
fi

if [ "\$cfg_cli_dust" = "true" ]; then
  printf "Installing dust...\n"
  install_cargo_tool dust du-dust
fi

if [ "\$cfg_cli_duf" = "true" ]; then
  printf "Installing duf...\n"
  pkg_install duf || printf "Warning: duf not available in package manager\n"
fi

if [ "\$cfg_cli_fd" = "true" ]; then
  printf "Installing fd...\n"
  install_cargo_tool fd fd-find
fi

if [ "\$cfg_cli_ripgrep" = "true" ]; then
  printf "Installing ripgrep...\n"
  install_cargo_tool rg ripgrep
fi

if [ "\$cfg_cli_mcfly" = "true" ]; then
  printf "Installing mcfly...\n"
  install_cargo_tool mcfly
fi

if [ "\$cfg_cli_sd" = "true" ]; then
  printf "Installing sd...\n"
  install_cargo_tool sd
fi

if [ "\$cfg_cli_choose" = "true" ]; then
  printf "Installing choose...\n"
  install_cargo_tool choose
fi

if [ "\$cfg_cli_cheat" = "true" ]; then
  printf "Installing cheat...\n"
  pkg_install cheat || printf "Warning: cheat not available in package manager\n"
fi

if [ "\$cfg_cli_bottom" = "true" ]; then
  printf "Installing bottom...\n"
  install_cargo_tool btm bottom
fi

if [ "\$cfg_cli_procs" = "true" ]; then
  printf "Installing procs...\n"
  install_cargo_tool procs
fi

if [ "\$cfg_cli_zoxide" = "true" ]; then
  printf "Installing zoxide...\n"
  install_cargo_tool zoxide
fi

if [ "\$cfg_cli_lsd" = "true" ]; then
  printf "Installing lsd...\n"
  install_cargo_tool lsd
fi

if [ "\$cfg_cli_gping" = "true" ]; then
  printf "Installing gping...\n"
  install_cargo_tool gping
fi

if [ "\$cfg_cli_lazygit" = "true" ]; then
  printf "Installing lazygit...\n"
  install_cargo_tool lazygit
fi

if [ "\$cfg_cli_lazydocker" = "true" ]; then
  printf "Installing lazydocker...\n"
  curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
fi

if [ "\$cfg_cli_tldr" = "true" ]; then
  printf "Installing tldr...\n"
  install_cargo_tool tldr tealdeer
fi

if [ "\$cfg_cli_jq" = "true" ]; then
  printf "Installing jq...\n"
  pkg_install jq
fi

if [ "\$cfg_cli_yq" = "true" ]; then
  printf "Installing yq...\n"
  pip3 install yq 2>/dev/null || pkg_install yq || printf "Warning: yq not available\n"
fi

if [ "\$cfg_cli_hyperfine" = "true" ]; then
  printf "Installing hyperfine...\n"
  install_cargo_tool hyperfine
fi

if [ "\$cfg_cli_tokei" = "true" ]; then
  printf "Installing tokei...\n"
  install_cargo_tool tokei
fi

if [ "\$cfg_cli_broot" = "true" ]; then
  printf "Installing broot...\n"
  install_cargo_tool broot
fi

if [ "\$cfg_cli_atuin" = "true" ]; then
  printf "Installing atuin...\n"
  install_cargo_tool atuin
fi

if [ "\$cfg_cli_xh" = "true" ]; then
  printf "Installing xh...\n"
  install_cargo_tool xh
fi

if [ "\$cfg_cli_difftastic" = "true" ]; then
  printf "Installing difftastic...\n"
  install_cargo_tool difft difftastic
fi

if [ "\$cfg_cli_zellij" = "true" ]; then
  printf "Installing zellij...\n"
  install_cargo_tool zellij
fi

printf "Set up motd...\n"
sudo -n mkdir -p /etc/update-motd.d
sudo -n rm -f /etc/update-motd.d/01-hello
sudo -n sh -c 'echo "#!/bin/bash" >> /etc/update-motd.d/01-hello'
sudo -n sh -c "echo \"/usr/bin/screenfetch -d '-disk' -w 80\" >> /etc/update-motd.d/01-hello"
sudo -n sh -c "echo \"figlet -t ${2}\" >> /etc/update-motd.d/01-hello"
sudo -n chmod a+x /etc/update-motd.d/01-hello

if [ -n "$3" ]; then
  key_count="\$(printf \"%s\" \"\$3\" | wc -l | tr -d ' ')"
  printf "Registering %s SSH public key(s)...\n" "\$key_count"
  mkdir -p "\$HOME/.ssh"
  chmod 700 "\$HOME/.ssh"
  # Add each key on a separate line
  printf "%s\n" "\$3" | while IFS= read -r key; do
    if [ -n "\$key" ]; then
      # Check if key already exists to avoid duplicates
      if ! grep -qF "\$key" "\$HOME/.ssh/authorized_keys" 2>/dev/null; then
        printf "%s\n" "\$key" >> "\$HOME/.ssh/authorized_keys"
      fi
    fi
  done
  chmod 600 "\$HOME/.ssh/authorized_keys"
else
  printf "Skipping SSH public key registration...\n"
fi

printf "Setting default shell to zsh...\n"
if command -v zsh >/dev/null 2>&1; then
  current_user="\${USER:-\$(id -un)}"
  sudo -n chsh -s "\$(command -v zsh)" "\$current_user"
fi

if [ "\$cfg_skip_zinit" = "true" ]; then
  printf "Skipping zinit setup (disabled in config)...\n"
else
  printf "Setting up zinit and powerlevel10k...\n"
  ZINIT_HOME="\${XDG_DATA_HOME:-\$HOME/.local/share}/zinit/zinit.git"
  if [ ! -d "\$ZINIT_HOME" ]; then
    mkdir -p "\$(dirname "\$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "\$ZINIT_HOME"
  fi
  printf "Zinit installed.\n"
fi

if [ "\$cfg_pkg_nvm" = "true" ]; then
  printf "Setting up nvm and Node.js...\n"
  if [ "\$is_openwrt" = "true" ]; then
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
    nvm_dir="\$HOME/.nvm"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | PROFILE=/dev/null NVM_DIR="\$nvm_dir" bash
    if [ -s "\$nvm_dir/nvm.sh" ] && command -v bash >/dev/null 2>&1; then
      bash -c ". \"\$nvm_dir/nvm.sh\" && nvm install --lts --latest-npm && nvm alias default 'lts/*' && nvm use --lts"
      printf "Installing Claude Code, OpenCode, and Codex CLIs...\n"
      bash -c ". \"\$nvm_dir/nvm.sh\" && nvm use --lts >/dev/null && npm install -g @anthropic-ai/claude-code opencode-ai @openai/codex"
    fi
  fi
else
  printf "Skipping nvm and Node.js setup (disabled in config)...\n"
fi
	
if [ "\$cfg_skip_mcp_setup" = "true" ]; then
  printf "Skipping MCP setup (disabled in config)...\n"
else
	printf "Configuring global MCP servers...\n"
	mcp_config_dir="\$HOME/.config/mcp"
  mcp_servers_dir="\$mcp_config_dir/servers"
  mcp_config="\$mcp_config_dir/mcp.json"
  mkdir -p "\$mcp_servers_dir"

  # Check if a server is enabled based on config toggles
  is_server_enabled() {
    server_name="\$1"
    case "\$server_name" in
      auggie-context) [ "\$cfg_mcp_auggie_context" = "true" ] ;;
      claude-context) [ "\$cfg_mcp_claude_context" = "true" ] ;;
      context7) [ "\$cfg_mcp_context7" = "true" ] ;;
      fetch) [ "\$cfg_mcp_fetch" = "true" ] ;;
      filesystem) [ "\$cfg_mcp_filesystem" = "true" ] ;;
      git) [ "\$cfg_mcp_git" = "true" ] ;;
      github) [ "\$cfg_mcp_github" = "true" ] ;;
      jupyter) [ "\$cfg_mcp_jupyter" = "true" ] ;;
      memory) [ "\$cfg_mcp_memory" = "true" ] ;;
      playwright) [ "\$cfg_mcp_playwright" = "true" ] ;;
      sequential-thinking) [ "\$cfg_mcp_sequential_thinking" = "true" ] ;;
      *) return 0 ;;  # Unknown servers are enabled by default
    esac
  }

  write_server_config() {
    server_name="\$1"
    if ! is_server_enabled "\$server_name"; then
      printf "  Skipping disabled server: %s\n" "\$server_name"
      return
    fi
    cat > "\$mcp_servers_dir/\$server_name.json"
  }

  write_server_config "filesystem" <<'MCP_EOF'
"filesystem": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "__HOME__"]
}
MCP_EOF

  write_server_config "fetch" <<'MCP_EOF'
"fetch": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-fetch"]
}
MCP_EOF

  write_server_config "memory" <<'MCP_EOF'
"memory": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"],
  "env": {
    "MEMORY_FILE_PATH": "__HOME__/.config/mcp/memory.jsonl"
  }
}
MCP_EOF

  write_server_config "github" <<'MCP_EOF'
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"]
}
MCP_EOF

  write_server_config "git" <<'MCP_EOF'
"git": {
  "command": "uvx",
  "args": ["mcp-server-git"]
}
MCP_EOF

  write_server_config "sequential-thinking" <<'MCP_EOF'
"sequential-thinking": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
}
MCP_EOF

  write_server_config "playwright" <<'MCP_EOF'
"playwright": {
  "command": "npx",
  "args": ["-y", "@playwright/mcp@latest"]
}
MCP_EOF

  write_server_config "jupyter" <<'MCP_EOF'
"jupyter": {
  "command": "uvx",
  "args": ["mcp-server-jupyter", "stdio"]
}
MCP_EOF

  write_server_config "context7" <<'MCP_EOF'
"context7": {
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp@latest"]
}
MCP_EOF

  write_server_config "auggie-context" <<'MCP_EOF'
"auggie-context": {
  "command": "npx",
  "args": ["-y", "auggie-context-mcp@latest"]
}
MCP_EOF

  write_server_config "claude-context" <<'MCP_EOF'
"claude-context": {
  "command": "npx",
  "args": ["-y", "@zilliz/claude-context-mcp@latest"]
}
MCP_EOF

  build_mcp_config() {
    printf "{\n  \"mcpServers\": {\n" > "\$mcp_config"
    first=1
    for server_file in "\$mcp_servers_dir"/*.json; do
      [ -f "\$server_file" ] || continue
      server_name="\$(basename "\$server_file" .json)"
      if ! is_server_enabled "\$server_name"; then
        continue
      fi
      if [ \$first -eq 0 ]; then
        printf ",\n" >> "\$mcp_config"
      fi
      first=0
      while IFS= read -r line || [ -n "\$line" ]; do
        while :; do
          case "\$line" in
            *__HOME__*)
              prefix=\${line%%__HOME__*}
              suffix=\${line#*__HOME__}
              line=\${prefix}\${HOME}\${suffix}
              ;;
            *)
              break
              ;;
          esac
        done
        printf "    %s\n" "\$line" >> "\$mcp_config"
      done < "\$server_file"
    done
    printf "  }\n}\n" >> "\$mcp_config"
  }
  build_mcp_config

  link_mcp_config() {
    target="\$1"
    if [ ! -e "\$target" ]; then
      mkdir -p "\$(dirname "\$target")"
      ln -s "\$mcp_config" "\$target"
    fi
  }
  link_mcp_config "\$HOME/.cursor/mcp.json"
  link_mcp_config "\$HOME/.config/codex/mcp.json"
  link_mcp_config "\$HOME/.config/antigravity/mcp.json"
fi

printf "Configuring zsh settings...\n"
zshrc="\$HOME/.zshrc"
touch "\$zshrc"
ensure_zshrc_line() {
  line="\$1"
  if ! grep -Fqx "\$line" "\$zshrc"; then
    printf "%s\n" "\$line" >> "\$zshrc"
  fi
}
set_zshrc_value() {
  key="\$1"
  value="\$2"
  if grep -q "^\${key}=" "\$zshrc"; then
    tmp="\${zshrc}.tmp"
    while IFS= read -r line || [ -n "\$line" ]; do
      case "\$line" in
        \${key}=*) printf "%s\n" "\${key}=\${value}" ;;
        *) printf "%s\n" "\$line" ;;
      esac
    done < "\$zshrc" > "\$tmp"
    mv "\$tmp" "\$zshrc"
  else
    printf "%s\n" "\${key}=\${value}" >> "\$zshrc"
  fi
}
# Zinit initialization
ensure_zshrc_line 'ZINIT_HOME="\${XDG_DATA_HOME:-\$HOME/.local/share}/zinit/zinit.git"'
ensure_zshrc_line '[ -f "\$ZINIT_HOME/zinit.zsh" ] && source "\$ZINIT_HOME/zinit.zsh"'

# Powerlevel10k theme
ensure_zshrc_line 'zinit ice depth=1; zinit light romkatv/powerlevel10k'

# Zinit plugins
ensure_zshrc_line 'zinit light zsh-users/zsh-autosuggestions'
ensure_zshrc_line 'zinit light zsh-users/zsh-syntax-highlighting'

# Powerlevel10k instant prompt (should be near top of .zshrc, but we add it here for simplicity)
ensure_zshrc_line '# Enable Powerlevel10k instant prompt'
ensure_zshrc_line 'if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then'
ensure_zshrc_line '  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"'
ensure_zshrc_line 'fi'
ensure_zshrc_line '# To customize prompt, run \`p10k configure\` or edit ~/.p10k.zsh'
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
	ensure_zshrc_line 'export PATH="\$HOME/.local/bin:\$PATH"'
	ensure_zshrc_line 'export PATH="\$HOME/.cargo/bin:\$PATH"'
	ensure_zshrc_line 'export NVM_DIR="\$HOME/.nvm"'
	ensure_zshrc_line '[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"'
	ensure_zshrc_line '[ -s "\$NVM_DIR/bash_completion" ] && . "\$NVM_DIR/bash_completion"'

# Modern CLI tool aliases (only add if the tool is installed)
[ -x "\$HOME/.cargo/bin/eza" ] || command -v eza >/dev/null 2>&1 && ensure_zshrc_line 'alias ls="eza"'
[ -x "\$HOME/.cargo/bin/eza" ] || command -v eza >/dev/null 2>&1 && ensure_zshrc_line 'alias ll="eza -l"'
[ -x "\$HOME/.cargo/bin/eza" ] || command -v eza >/dev/null 2>&1 && ensure_zshrc_line 'alias la="eza -la"'
[ -x "\$HOME/.cargo/bin/bat" ] || command -v bat >/dev/null 2>&1 && ensure_zshrc_line 'alias cat="bat"'
[ -x "\$HOME/.cargo/bin/dust" ] || command -v dust >/dev/null 2>&1 && ensure_zshrc_line 'alias du="dust"'
command -v duf >/dev/null 2>&1 && ensure_zshrc_line 'alias df="duf"'
[ -x "\$HOME/.cargo/bin/fd" ] || command -v fd >/dev/null 2>&1 && ensure_zshrc_line 'alias find="fd"'
[ -x "\$HOME/.cargo/bin/rg" ] || command -v rg >/dev/null 2>&1 && ensure_zshrc_line 'alias grep="rg"'
[ -x "\$HOME/.cargo/bin/sd" ] || command -v sd >/dev/null 2>&1 && ensure_zshrc_line 'alias sed="sd"'
[ -x "\$HOME/.cargo/bin/choose" ] || command -v choose >/dev/null 2>&1 && ensure_zshrc_line 'alias cut="choose"'
[ -x "\$HOME/.cargo/bin/btm" ] || command -v btm >/dev/null 2>&1 && ensure_zshrc_line 'alias top="btm"'
[ -x "\$HOME/.cargo/bin/procs" ] || command -v procs >/dev/null 2>&1 && ensure_zshrc_line 'alias ps="procs"'
[ -x "\$HOME/.cargo/bin/gping" ] || command -v gping >/dev/null 2>&1 && ensure_zshrc_line 'alias ping="gping"'
[ -x "\$HOME/.cargo/bin/lsd" ] || command -v lsd >/dev/null 2>&1 && ensure_zshrc_line 'alias lsd="lsd"'
[ -x "\$HOME/.cargo/bin/difft" ] || command -v difft >/dev/null 2>&1 && ensure_zshrc_line 'alias diff="difftastic"'
[ -x "\$HOME/.cargo/bin/xh" ] || command -v xh >/dev/null 2>&1 && ensure_zshrc_line 'alias http="xh"'
command -v lazygit >/dev/null 2>&1 && ensure_zshrc_line 'alias lg="lazygit"'
command -v lazydocker >/dev/null 2>&1 && ensure_zshrc_line 'alias lzd="lazydocker"'

# Tool initializations
[ -f "\$HOME/.fzf.zsh" ] && ensure_zshrc_line '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh'
[ -x "\$HOME/.cargo/bin/zoxide" ] || command -v zoxide >/dev/null 2>&1 && ensure_zshrc_line 'eval "\$(zoxide init zsh)"'
[ -x "\$HOME/.cargo/bin/zoxide" ] || command -v zoxide >/dev/null 2>&1 && ensure_zshrc_line 'alias cd="z"'
[ -x "\$HOME/.cargo/bin/mcfly" ] || command -v mcfly >/dev/null 2>&1 && ensure_zshrc_line 'eval "\$(mcfly init zsh)"'
command -v hishtory >/dev/null 2>&1 && ensure_zshrc_line 'eval "\$(hishtory init zsh)"'

# Broot file navigator
[ -f "\$HOME/.config/broot/launcher/bash/br" ] && ensure_zshrc_line '[ -f ~/.config/broot/launcher/bash/br ] && source ~/.config/broot/launcher/bash/br'

# Atuin shell history
command -v atuin >/dev/null 2>&1 && ensure_zshrc_line 'eval "\$(atuin init zsh)"'

# Configure delta as git pager
[ -x "\$HOME/.cargo/bin/delta" ] || command -v delta >/dev/null 2>&1 && {
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.side-by-side true
  git config --global merge.conflictstyle diff3
  git config --global diff.colorMoved default
}
EOF

# Use TTY mode if available, otherwise run without TTY
# shellcheck disable=SC2086
if [ -t 0 ]; then
  ssh -tt $ssh_opts "$ssh_user@$server_addr" "sh \"$remote_script_path\" \"$server_port\" \"$servername\" \"$pubkeys\"; rc=\$?; rm -f \"$remote_script_path\"; exit \$rc" < /dev/tty
else
  ssh $ssh_opts "$ssh_user@$server_addr" "sh \"$remote_script_path\" \"$server_port\" \"$servername\" \"$pubkeys\"; rc=\$?; rm -f \"$remote_script_path\"; exit \$rc"
fi
