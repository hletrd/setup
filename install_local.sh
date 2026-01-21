#!/bin/sh

set -e

script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/config.json"

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
        sed -n "/$parent/,/}/p" "$file" | grep "\"$child\"" | sed 's/.*: *"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/' | head -1
        ;;
      *)
        grep "\"$key\"" "$file" | sed 's/.*: *"\{0,1\}\([^",}]*\)"\{0,1\}.*/\1/' | head -1
        ;;
    esac
  fi
}

json_get_bool() {
  val="$(json_get "$1" "$2")"
  case "$val" in
    true|True|TRUE|1) printf "true" ;;
    *) printf "false" ;;
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
cfg_skip_package_update="false"
cfg_skip_oh_my_zsh="false"
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
cfg_mcp_agentic_tools="true"
cfg_mcp_auggie_context="true"
cfg_mcp_claude_context="true"
cfg_mcp_context7="true"
cfg_mcp_fetch="true"
cfg_mcp_filesystem="true"
cfg_mcp_git="true"
cfg_mcp_github="true"
cfg_mcp_graphiti="true"
cfg_mcp_jupyter="true"
cfg_mcp_memory="true"
cfg_mcp_playwright="true"
cfg_mcp_sequential_thinking="true"

if [ -f "$config_file" ]; then
  printf "Loading configuration from %s\n" "$config_file"
  cfg_prompt_for_confirmation="$(json_get_bool "prompt_for_confirmation" "$config_file")"
  cfg_ssh_port="$(json_get "ssh_port" "$config_file")"
  cfg_ssh_key_action="$(json_get "ssh_key_action" "$config_file")"
  cfg_skip_package_update="$(json_get_bool "skip_package_update" "$config_file")"
  cfg_skip_oh_my_zsh="$(json_get_bool "skip_oh_my_zsh" "$config_file")"
  cfg_skip_mcp_setup="$(json_get_bool "skip_mcp_setup" "$config_file")"
  cfg_editor_cursor="$(json_get_bool "cursor" "$config_file")"
  cfg_editor_codex="$(json_get_bool "codex" "$config_file")"
  cfg_editor_opencode="$(json_get_bool "opencode" "$config_file")"
  cfg_editor_antigravity="$(json_get_bool "antigravity" "$config_file")"
  cfg_editor_claude_desktop="$(json_get_bool "claude_desktop" "$config_file")"

  # Load package manager toggles
  cfg_pkg_nvm="$(json_get_bool "nvm" "$config_file")"
  cfg_pkg_uv="$(json_get_bool "uv" "$config_file")"
  cfg_pkg_cargo="$(json_get_bool "cargo" "$config_file")"
  cfg_pkg_ruff="$(json_get_bool "ruff" "$config_file")"
  cfg_pkg_ty="$(json_get_bool "ty" "$config_file")"

  # Load CLI tools toggles
  cfg_cli_hishtory="$(json_get_bool "hishtory" "$config_file")"
  cfg_cli_fzf="$(json_get_bool "fzf" "$config_file")"
  cfg_cli_eza="$(json_get_bool "eza" "$config_file")"
  cfg_cli_bat="$(json_get_bool "bat" "$config_file")"
  cfg_cli_delta="$(json_get_bool "delta" "$config_file")"
  cfg_cli_dust="$(json_get_bool "dust" "$config_file")"
  cfg_cli_duf="$(json_get_bool "duf" "$config_file")"
  cfg_cli_fd="$(json_get_bool "fd" "$config_file")"
  cfg_cli_ripgrep="$(json_get_bool "ripgrep" "$config_file")"
  cfg_cli_mcfly="$(json_get_bool "mcfly" "$config_file")"
  cfg_cli_sd="$(json_get_bool "sd" "$config_file")"
  cfg_cli_choose="$(json_get_bool "choose" "$config_file")"
  cfg_cli_cheat="$(json_get_bool "cheat" "$config_file")"
  cfg_cli_bottom="$(json_get_bool "bottom" "$config_file")"
  cfg_cli_procs="$(json_get_bool "procs" "$config_file")"
  cfg_cli_zoxide="$(json_get_bool "zoxide" "$config_file")"
  cfg_cli_lsd="$(json_get_bool "lsd" "$config_file")"
  cfg_cli_gping="$(json_get_bool "gping" "$config_file")"

  # Load MCP server toggles
  cfg_mcp_agentic_tools="$(json_get_bool "agentic-tools" "$config_file")"
  cfg_mcp_auggie_context="$(json_get_bool "auggie-context" "$config_file")"
  cfg_mcp_claude_context="$(json_get_bool "claude-context" "$config_file")"
  cfg_mcp_context7="$(json_get_bool "context7" "$config_file")"
  cfg_mcp_fetch="$(json_get_bool "fetch" "$config_file")"
  cfg_mcp_filesystem="$(json_get_bool "filesystem" "$config_file")"
  cfg_mcp_git="$(json_get_bool "git" "$config_file")"
  cfg_mcp_github="$(json_get_bool "github" "$config_file")"
  cfg_mcp_graphiti="$(json_get_bool "graphiti" "$config_file")"
  cfg_mcp_jupyter="$(json_get_bool "jupyter" "$config_file")"
  cfg_mcp_memory="$(json_get_bool "memory" "$config_file")"
  cfg_mcp_playwright="$(json_get_bool "playwright" "$config_file")"
  cfg_mcp_sequential_thinking="$(json_get_bool "sequential-thinking" "$config_file")"

  [ -z "$cfg_ssh_port" ] && cfg_ssh_port="22"
  [ -z "$cfg_ssh_key_action" ] && cfg_ssh_key_action="generate"
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
  if [ "$cfg_prompt_for_confirmation" = "true" ]; then
    result="$(prompt_read "$prompt")"
    if [ -z "$result" ]; then
      result="$default"
    fi
  else
    result="$default"
    printf "%s%s\n" "$prompt" "$default"
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

server_port="$(prompt_or_default "SSH port (default: ${cfg_ssh_port}): " "$cfg_ssh_port")"

servername="$(prompt_or_default "Server name for MOTD (default: ${hostname_default}): " "$hostname_default")"

if [ "$cfg_prompt_for_confirmation" = "true" ]; then
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

case "$key_choice" in
  a|A)
    input_pubkey="$(prompt_read "Public key to install: ")"
    if [ -n "$input_pubkey" ]; then
      printf "%s\n" "$input_pubkey" > "$pubkey_path"
      pubkey="$input_pubkey"
    fi
    ;;
  s|S)
    pubkey=""
    ;;
  *)
    key_path="./.secret.pem"
    if [ ! -f "$key_path" ]; then
      ssh-keygen -t ecdsa -b 521 -N "" -f "$key_path"
    fi
    cp "${key_path}.pub" "$pubkey_path"
    pubkey="$(cat "$pubkey_path")"
    ;;
esac

printf "Caching sudo credentials...\n"
sudo -v

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
  else
    printf "No supported package manager found.\n" >&2
    return 1
  fi
}

pkg_install() {
  packages="$*"
  if command -v apt-get >/dev/null 2>&1; then
    sudo -n apt-get install -y $packages
  elif command -v dnf >/dev/null 2>&1; then
    sudo -n dnf -y install $packages
  elif command -v yum >/dev/null 2>&1; then
    sudo -n yum -y install $packages
  elif command -v pacman >/dev/null 2>&1; then
    sudo -n pacman -S --noconfirm $packages
  else
    printf "No supported package manager found.\n" >&2
    return 1
  fi
}

openssh_package="openssh-server"
if command -v pacman >/dev/null 2>&1; then
  openssh_package="openssh"
fi

if [ "$cfg_skip_package_update" = "true" ]; then
  printf "Skipping package update (disabled in config)...\n"
else
  printf "Updating packages...\n"
  pkg_update
fi

printf "Installing openssh-server if missing...\n"
if ! command -v sshd >/dev/null 2>&1; then
  pkg_install "$openssh_package"
fi

if command -v systemctl >/dev/null 2>&1; then
  sudo -n systemctl enable sshd >/dev/null 2>&1 || sudo -n systemctl enable ssh
  sudo -n systemctl start sshd >/dev/null 2>&1 || sudo -n systemctl start ssh
fi

printf "Configuring firewall for SSH...\n"
if command -v ufw >/dev/null 2>&1; then
  sudo -n ufw allow "${server_port}/tcp"
elif command -v iptables >/dev/null 2>&1; then
  if ! sudo -n iptables -C INPUT -p tcp --dport "$server_port" -j ACCEPT >/dev/null 2>&1; then
    sudo -n iptables -A INPUT -p tcp --dport "$server_port" -j ACCEPT
  fi
fi

printf "Setting passwordless sudo for current user...\n"
current_user="$(id -un)"
sudo -n mkdir -p /etc/sudoers.d
sudo -n sh -c "echo \"${current_user} ALL=(ALL:ALL) NOPASSWD: ALL\" > /etc/sudoers.d/${current_user}"
sudo -n chmod 0440 "/etc/sudoers.d/${current_user}"

printf "Installing base packages...\n"
pkg_install zsh figlet screenfetch git curl vim

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

printf "Set up motd...\n"
sudo -n rm -f /etc/update-motd.d/01-hello
sudo -n sh -c 'echo "#!/bin/bash" >> /etc/update-motd.d/01-hello'
sudo -n sh -c "echo \"/usr/bin/screenfetch -d '-disk' -w 80\" >> /etc/update-motd.d/01-hello"
sudo -n sh -c "echo \"figlet -t ${servername}\" >> /etc/update-motd.d/01-hello"
sudo -n chmod a+x /etc/update-motd.d/01-hello

if [ -n "$pubkey" ]; then
  printf "Registering SSH public key...\n"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  printf "%s\n" "$pubkey" >> "$HOME/.ssh/authorized_keys"
  chmod 600 "$HOME/.ssh/authorized_keys"
else
  printf "Skipping SSH public key registration...\n"
fi

printf "Setting default shell to zsh...\n"
if command -v zsh >/dev/null 2>&1; then
  sudo -n chsh -s "$(command -v zsh)" "$USER"
fi

if [ "$cfg_skip_oh_my_zsh" = "true" ]; then
  printf "Skipping oh-my-zsh setup (disabled in config)...\n"
else
  printf "Setting up oh my zsh...\n"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  printf "Set up oh my zsh...\n"

  zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$zsh_custom/plugins"
  if [ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
  fi
  if [ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting"
  fi

  omz_cmd="$HOME/.oh-my-zsh/bin/omz"
  if [ -x "$omz_cmd" ]; then
    ZSH="$HOME/.oh-my-zsh" "$omz_cmd" theme set agnoster
    ZSH="$HOME/.oh-my-zsh" "$omz_cmd" plugin load zsh-syntax-highlighting zsh-autosuggestions
    ZSH="$HOME/.oh-my-zsh" "$omz_cmd" plugin enable zsh-syntax-highlighting zsh-autosuggestions
  fi
fi

if [ "$cfg_pkg_nvm" = "true" ]; then
  printf "Setting up nvm and Node.js...\n"
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
      agentic-tools) [ "$cfg_mcp_agentic_tools" = "true" ] ;;
      auggie-context) [ "$cfg_mcp_auggie_context" = "true" ] ;;
      claude-context) [ "$cfg_mcp_claude_context" = "true" ] ;;
      context7) [ "$cfg_mcp_context7" = "true" ] ;;
      fetch) [ "$cfg_mcp_fetch" = "true" ] ;;
      filesystem) [ "$cfg_mcp_filesystem" = "true" ] ;;
      git) [ "$cfg_mcp_git" = "true" ] ;;
      github) [ "$cfg_mcp_github" = "true" ] ;;
      graphiti) [ "$cfg_mcp_graphiti" = "true" ] ;;
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
set_zshrc_plugins() {
  plugins_line="$1"
  if grep -q "^plugins=" "$zshrc"; then
    tmp="${zshrc}.tmp"
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        plugins=*) printf "%s\n" "$plugins_line" ;;
        *) printf "%s\n" "$line" ;;
      esac
    done < "$zshrc" > "$tmp"
    mv "$tmp" "$zshrc"
  else
    printf "%s\n" "$plugins_line" >> "$zshrc"
  fi
}
set_zshrc_value "ZSH_THEME" "\"agnoster\""
set_zshrc_plugins "plugins=(git zsh-syntax-highlighting zsh-autosuggestions)"
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

# Tool initializations
[ -f "$HOME/.fzf.zsh" ] && ensure_zshrc_line '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh'
[ -x "$HOME/.cargo/bin/zoxide" ] || command -v zoxide >/dev/null 2>&1 && ensure_zshrc_line 'eval "$(zoxide init zsh)"'
[ -x "$HOME/.cargo/bin/mcfly" ] || command -v mcfly >/dev/null 2>&1 && ensure_zshrc_line 'eval "$(mcfly init zsh)"'
command -v hishtory >/dev/null 2>&1 && ensure_zshrc_line 'eval "$(hishtory init zsh)"'

# Configure delta as git pager
[ -x "$HOME/.cargo/bin/delta" ] || command -v delta >/dev/null 2>&1 && {
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.side-by-side true
  git config --global merge.conflictstyle diff3
  git config --global diff.colorMoved default
}
