#!/bin/sh

set -e

script_dir="$(cd "$(dirname "$0")" && pwd)"
config_file="$script_dir/config.json"

# JSON parsing helper (uses grep/sed for POSIX compatibility)
json_get() {
  key="$1"
  file="$2"
  if [ -f "$file" ]; then
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
    sed -n "/\"$key\"/,/]/p" "$file" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | grep -v "$key"
  fi
}

# Load configuration
cfg_prompt_for_confirmation="true"
cfg_ssh_port="22"
cfg_server_address="localhost"
cfg_ssh_key_action="generate"
cfg_skip_package_update="false"
cfg_skip_oh_my_zsh="false"
cfg_skip_nvm="false"
cfg_skip_mcp_setup="false"

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
  cfg_server_address="$(json_get "server_address" "$config_file")"
  cfg_ssh_key_action="$(json_get "ssh_key_action" "$config_file")"
  cfg_skip_package_update="$(json_get_bool "skip_package_update" "$config_file")"
  cfg_skip_oh_my_zsh="$(json_get_bool "skip_oh_my_zsh" "$config_file")"
  cfg_skip_nvm="$(json_get_bool "skip_nvm" "$config_file")"
  cfg_skip_mcp_setup="$(json_get_bool "skip_mcp_setup" "$config_file")"

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
  [ -z "$cfg_server_address" ] && cfg_server_address="localhost"
  [ -z "$cfg_ssh_key_action" ] && cfg_ssh_key_action="generate"
fi

prompt_read() {
  prompt="$1"
  input=""
  if [ -t 0 ]; then
    printf "%s" "$prompt"
    IFS= read -r input || :
  elif [ -r /dev/tty ] && [ -w /dev/tty ]; then
    printf "%s" "$prompt" > /dev/tty
    IFS= read -r input < /dev/tty || :
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

default_user="$(id -un)"

server_addr="$(prompt_or_default "Server address (default: ${cfg_server_address}): " "$cfg_server_address")"

server_port="$(prompt_or_default "SSH port (default: ${cfg_ssh_port}): " "$cfg_ssh_port")"

ssh_user="$(prompt_or_default "SSH username (default: ${default_user}): " "$default_user")"

servername="$(prompt_or_default "Server name for MOTD (default: ${server_addr}): " "$server_addr")"

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
	
	remote_script_path="/tmp/setup-bootstrap.$$"
	# Pass configuration values as environment variables to the remote script
	ssh -p "$server_port" "$ssh_user@$server_addr" "cat > \"$remote_script_path\" && chmod 700 \"$remote_script_path\"" <<EOF
	set -e

	# Configuration passed from local config.json
	cfg_skip_package_update="$cfg_skip_package_update"
	cfg_skip_oh_my_zsh="$cfg_skip_oh_my_zsh"
	cfg_skip_nvm="$cfg_skip_nvm"
	cfg_skip_mcp_setup="$cfg_skip_mcp_setup"

	# MCP server toggles
	cfg_mcp_agentic_tools="$cfg_mcp_agentic_tools"
	cfg_mcp_auggie_context="$cfg_mcp_auggie_context"
	cfg_mcp_claude_context="$cfg_mcp_claude_context"
	cfg_mcp_context7="$cfg_mcp_context7"
	cfg_mcp_fetch="$cfg_mcp_fetch"
	cfg_mcp_filesystem="$cfg_mcp_filesystem"
	cfg_mcp_git="$cfg_mcp_git"
	cfg_mcp_github="$cfg_mcp_github"
	cfg_mcp_graphiti="$cfg_mcp_graphiti"
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
  packages="\$*"
  if command -v apt-get >/dev/null 2>&1; then
    sudo -n apt-get install -y \$packages
  elif command -v dnf >/dev/null 2>&1; then
    sudo -n dnf -y install \$packages
  elif command -v yum >/dev/null 2>&1; then
    sudo -n yum -y install \$packages
  elif command -v pacman >/dev/null 2>&1; then
    sudo -n pacman -S --noconfirm \$packages
  else
    printf "No supported package manager found.\n" >&2
    return 1
  fi
}

if [ "\$cfg_skip_package_update" = "true" ]; then
  printf "Skipping package update (disabled in config)...\n"
else
  printf "Updating packages...\n"
  pkg_update
fi

printf "Installing openssh-server if missing...\n"
if ! command -v sshd >/dev/null 2>&1; then
  pkg_install openssh-server
fi

if command -v systemctl >/dev/null 2>&1; then
  sudo -n systemctl enable sshd >/dev/null 2>&1 || sudo -n systemctl enable ssh
  sudo -n systemctl start sshd >/dev/null 2>&1 || sudo -n systemctl start ssh
fi

printf "Configuring firewall for SSH...\n"
ssh_port="$1"
if command -v ufw >/dev/null 2>&1; then
  sudo -n ufw allow "${ssh_port}/tcp"
elif command -v iptables >/dev/null 2>&1; then
  if ! sudo -n iptables -C INPUT -p tcp --dport "$ssh_port" -j ACCEPT >/dev/null 2>&1; then
    sudo -n iptables -A INPUT -p tcp --dport "$ssh_port" -j ACCEPT
  fi
fi

printf "Setting passwordless sudo for current user...\n"
current_user="$(id -un)"
sudo -n mkdir -p /etc/sudoers.d
sudo -n sh -c "echo \"${current_user} ALL=(ALL:ALL) NOPASSWD: ALL\" > /etc/sudoers.d/${current_user}"
sudo -n chmod 0440 "/etc/sudoers.d/${current_user}"

printf "Installing base packages...\n"
pkg_install zsh figlet screenfetch git curl vim

printf "Installing uv...\n"
if ! command -v uv >/dev/null 2>&1; then
  curl -fsSL https://astral.sh/uv/install.sh | sh
fi

printf "Set up motd...\n"
sudo -n rm -f /etc/update-motd.d/01-hello
sudo -n sh -c 'echo "#!/bin/bash" >> /etc/update-motd.d/01-hello'
sudo -n sh -c "echo \"/usr/bin/screenfetch -d '-disk' -w 80\" >> /etc/update-motd.d/01-hello"
sudo -n sh -c "echo \"figlet -t ${2}\" >> /etc/update-motd.d/01-hello"
sudo -n chmod a+x /etc/update-motd.d/01-hello

if [ -n "$3" ]; then
  printf "Registering SSH public key...\n"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  printf "%s\n" "$3" >> "$HOME/.ssh/authorized_keys"
  chmod 600 "$HOME/.ssh/authorized_keys"
else
  printf "Skipping SSH public key registration...\n"
fi

printf "Setting default shell to zsh...\n"
if command -v zsh >/dev/null 2>&1; then
  sudo -n chsh -s "$(command -v zsh)" "$USER"
fi

if [ "\$cfg_skip_oh_my_zsh" = "true" ]; then
  printf "Skipping oh-my-zsh setup (disabled in config)...\n"
else
  printf "Setting up oh my zsh...\n"
  if [ ! -d "\$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  printf "Set up oh my zsh...\n"

  zsh_custom="\${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}"
  mkdir -p "\$zsh_custom/plugins"
  if [ ! -d "\$zsh_custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions "\$zsh_custom/plugins/zsh-autosuggestions"
  fi
  if [ ! -d "\$zsh_custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "\$zsh_custom/plugins/zsh-syntax-highlighting"
  fi

  omz_cmd="\$HOME/.oh-my-zsh/bin/omz"
  if [ -x "\$omz_cmd" ]; then
    ZSH="\$HOME/.oh-my-zsh" "\$omz_cmd" theme set agnoster
    ZSH="\$HOME/.oh-my-zsh" "\$omz_cmd" plugin load zsh-syntax-highlighting zsh-autosuggestions
    ZSH="\$HOME/.oh-my-zsh" "\$omz_cmd" plugin enable zsh-syntax-highlighting zsh-autosuggestions
  fi
fi

if [ "\$cfg_skip_nvm" = "true" ]; then
  printf "Skipping nvm and Node.js setup (disabled in config)...\n"
else
	printf "Setting up nvm and Node.js...\n"
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
      agentic-tools) [ "\$cfg_mcp_agentic_tools" = "true" ] ;;
      auggie-context) [ "\$cfg_mcp_auggie_context" = "true" ] ;;
      claude-context) [ "\$cfg_mcp_claude_context" = "true" ] ;;
      context7) [ "\$cfg_mcp_context7" = "true" ] ;;
      fetch) [ "\$cfg_mcp_fetch" = "true" ] ;;
      filesystem) [ "\$cfg_mcp_filesystem" = "true" ] ;;
      git) [ "\$cfg_mcp_git" = "true" ] ;;
      github) [ "\$cfg_mcp_github" = "true" ] ;;
      graphiti) [ "\$cfg_mcp_graphiti" = "true" ] ;;
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
	ensure_zshrc_line 'export NVM_DIR="$HOME/.nvm"'
	ensure_zshrc_line '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
	ensure_zshrc_line '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'
EOF

ssh -tt -p "$server_port" "$ssh_user@$server_addr" "sh \"$remote_script_path\" \"$server_port\" \"$servername\" \"$pubkey\"; rc=\$?; rm -f \"$remote_script_path\"; exit \$rc" < /dev/tty
