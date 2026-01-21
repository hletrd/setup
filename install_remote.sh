#!/bin/sh

set -e

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

default_user="$(id -un)"

server_addr="$(prompt_read "Server address (default: localhost): ")"
if [ -z "$server_addr" ]; then
  server_addr="localhost"
fi

server_port="$(prompt_read "SSH port (default: 22): ")"
if [ -z "$server_port" ]; then
  server_port="22"
fi

ssh_user="$(prompt_read "SSH username (default: ${default_user}): ")"
if [ -z "$ssh_user" ]; then
  ssh_user="$default_user"
fi

servername="$(prompt_read "Server name for MOTD (default: ${server_addr}): ")"
if [ -z "$servername" ]; then
  servername="$server_addr"
fi

key_choice="$(prompt_read "SSH public key setup: (g)enerate, (a)dd existing, (s)kip [default: g]: ")"

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

ssh -p "$server_port" "$ssh_user@$server_addr" sh -s -- "$server_port" "$servername" "$pubkey" <<'EOF'
set -e

printf "Caching sudo credentials...\n"
sudo -v

if [ -f /etc/os-release ]; then
  . /etc/os-release
  distro_id="$ID"
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

printf "Updating packages...\n"
pkg_update

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

printf "Setting up nvm and Node.js...\n"
if ! command -v bash >/dev/null 2>&1; then
  pkg_install bash
fi
nvm_dir="$HOME/.nvm"
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | PROFILE=/dev/null NVM_DIR="$nvm_dir" bash
if [ -s "$nvm_dir/nvm.sh" ] && command -v bash >/dev/null 2>&1; then
  bash -c ". \"$nvm_dir/nvm.sh\" && nvm install --lts --latest-npm && nvm alias default 'lts/*' && nvm use --lts"
fi

printf "Configuring global MCP servers...\n"
mcp_config_dir="$HOME/.config/mcp"
mcp_servers_dir="$mcp_config_dir/servers"
mcp_config="$mcp_config_dir/mcp.json"
mkdir -p "$mcp_servers_dir"
cat <<'MCP_EOF' > "$mcp_servers_dir/filesystem.json"
"filesystem": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "__HOME__"]
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/fetch.json"
"fetch": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-fetch"]
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/memory.json"
"memory": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"],
  "env": {
    "MEMORY_FILE_PATH": "__HOME__/.config/mcp/memory.jsonl"
  }
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/github.json"
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"]
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/git.json"
"git": {
  "command": "uvx",
  "args": ["mcp-server-git"]
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/sequential-thinking.json"
"sequential-thinking": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/playwright.json"
"playwright": {
  "command": "npx",
  "args": ["-y", "@playwright/mcp@latest"]
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/jupyter.json"
"jupyter": {
  "command": "uvx",
  "args": ["mcp-server-jupyter", "stdio"]
}
MCP_EOF
cat <<'MCP_EOF' > "$mcp_servers_dir/context7.json"
"context7": {
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp@latest"]
}
MCP_EOF
build_mcp_config() {
  printf "{\n  \"mcpServers\": {\n" > "$mcp_config"
  first=1
  for server_file in "$mcp_servers_dir"/*.json; do
    [ -f "$server_file" ] || continue
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
link_mcp_config "$HOME/.cursor/mcp.json"
link_mcp_config "$HOME/.config/codex/mcp.json"
link_mcp_config "$HOME/.config/antigravity/mcp.json"

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
ensure_zshrc_line 'export PATH="$HOME/.local/bin:$PATH"'
ensure_zshrc_line 'export NVM_DIR="$HOME/.nvm"'
ensure_zshrc_line '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
ensure_zshrc_line '[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'
EOF
