# Setup Scripts

A comprehensive collection of scripts to bootstrap and configure new systems with modern development tools.

## Scripts Overview

| Script | Description |
|--------|-------------|
| `install_local.sh` | Local machine setup script |
| `install_remote.sh` | Remote machine setup via SSH |
| `install_nvidia_local.sh` | NVIDIA CUDA Toolkit and driver (local) |
| `install_nvidia_remote.sh` | NVIDIA CUDA Toolkit and driver (remote) |
| `config.json` | Configuration file for installation options |

### Additional Directories

| Directory | Description |
|-----------|-------------|
| `autoinstall/` | Ubuntu autoinstall ISO creation tools |
| `configs/` | Pre-configured settings for codex, gh, opencode |
| `mcp/servers/` | MCP server configuration files |

## Supported Platforms

The scripts are compatible with all major POSIX-derived operating systems:

| Platform | Package Manager | Status |
|----------|-----------------|--------|
| **macOS** | Homebrew | ✅ Fully supported |
| **Ubuntu/Debian** | apt | ✅ Fully supported |
| **Fedora/RHEL** | dnf/yum | ✅ Fully supported |
| **Arch Linux** | pacman | ✅ Fully supported |
| **Alpine Linux** | apk | ✅ Supported (Node.js requires glibc) |

## Features

### System Configuration
- Update system packages using the detected package manager
- Install `openssh-server`, enable the SSH service, and open the SSH port in the firewall (UFW, iptables, or firewalld)
- Enable passwordless sudo for the current user
- Install base tools: `zsh`, `figlet`, `neofetch`/`screenfetch`, `git`, `curl`, `vim`
- Install build tools (gcc, make) for compiling Rust packages
- Configure MOTD with system info and a figlet banner
- Register an SSH public key (prompted; generates one if omitted)

### Shell Setup (Zinit + Powerlevel10k)
- Install [zinit](https://github.com/zdharma-continuum/zinit) plugin manager
- Set [Powerlevel10k](https://github.com/romkatv/powerlevel10k) as default theme
- Enable `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins via zinit
- Configure Powerlevel10k instant prompt for fast shell startup

### Package Managers
| Package | Description |
|---------|-------------|
| **nvm** | Node Version Manager with latest LTS Node.js |
| **uv** | Fast Python package manager by Astral |
| **cargo** | Rust toolchain via rustup |

### Python Tools (via uv tool install)
| Tool | Description |
|------|-------------|
| **ruff** | Fast Python linter and formatter |
| **ty** | Python type checker |

### Modern CLI Tools
All tools are configurable via `config.json`. Installed via cargo for cross-platform compatibility:

| Tool | Replaces | Alias | Description |
|------|----------|-------|-------------|
| eza | ls | `ls`, `ll`, `la` | Modern ls replacement |
| bat | cat | `cat` | Cat with syntax highlighting |
| dust | du | `du` | Intuitive disk usage |
| duf | df | `df` | Better disk free utility |
| fd | find | `find` | Fast and user-friendly find |
| ripgrep | grep | `grep` | Ultra-fast grep |
| sd | sed | `sed` | Intuitive find & replace |
| choose | cut/awk | `cut` | Human-friendly cut |
| bottom | top/htop | `top` | Graphical process viewer |
| procs | ps | `ps` | Modern process viewer |
| gping | ping | `ping` | Ping with graph |
| zoxide | cd | `z` | Smarter cd command |
| mcfly | Ctrl+R | - | Intelligent history search |
| fzf | - | - | Fuzzy finder |
| delta | git diff | - | Beautiful git diffs |
| hishtory | history | - | Better shell history |
| cheat | - | - | Command cheat sheets |
| lsd | ls | - | Alternative ls with icons |

### MCP (Model Context Protocol) Servers
Pre-configured MCP servers for AI-assisted development:

| Server | Purpose |
|--------|---------|
| auggie-context | Augment context engine |
| context7 | Library documentation |
| fetch | URL fetching |
| filesystem | File operations |
| git | Git operations |
| github | GitHub API integration |
| jupyter | Jupyter notebook integration |
| memory | Persistent memory |
| playwright | Browser automation |
| sequential-thinking | Reasoning chains |

### Editor Integration
MCP configuration is automatically symlinked to supported editors:
- **Cursor** (`~/.cursor/mcp.json`)
- **Codex** (`~/.codex/`)
- **OpenCode** (`~/.opencode/`)
- **Antigravity** (`~/.antigravity/`)
- **Claude Desktop** (`~/Library/Application Support/Claude/`)

## Configuration

Create a `config.json` file to pre-configure installation options:

```json
{
  "prompts": {
    "prompt_for_confirmation": true,
    "ssh_port": "22",
    "server_address": "localhost",
    "ssh_user": "admin",
    "ssh_key_action": "generate"
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
    "ruff": true,
    "ty": true
  },
  "cli_tools": {
    "fzf": true,
    "eza": true,
    "bat": true,
    "fd": true,
    "ripgrep": true,
    "zoxide": true,
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
  },
  "mcp_servers": {
    "github": true,
    "filesystem": true,
    "git": true,
    "fetch": true
  },
  "editors": {
    "cursor": true,
    "codex": true,
    "opencode": true,
    "claude_desktop": true
  }
}
```

**Configuration Priority:** Command line options > config.json > interactive prompts > defaults

## Usage

### Command Line Options

Both scripts support command line options for non-interactive use:

**install_local.sh:**
```bash
./install_local.sh [OPTIONS]

Options:
  -p, --port PORT          SSH port (default: 22)
  -n, --name NAME          Server name for MOTD (default: hostname)
  -k, --key-action ACTION  SSH key action: generate, add, skip
  --pubkey KEY             Public key to install (if --key-action=add)
  -y, --yes                Non-interactive mode, use defaults
  -c, --config FILE        Path to config file
  -h, --help               Show help message
```

**install_remote.sh:**
```bash
./install_remote.sh [OPTIONS]

Options:
  -H, --host HOST          Server address/hostname
  -p, --port PORT          SSH port (default: 22)
  -u, --user USER          SSH username
  -n, --name NAME          Server name for MOTD
  -k, --key-action ACTION  SSH key action: generate, add, skip
  --pubkey KEY             Public key to install (if --key-action=add)
  -y, --yes                Non-interactive mode, use defaults
  -c, --config FILE        Path to config file
  -h, --help               Show help message
```

### Examples

```bash
# Local install with defaults (non-interactive)
./install_local.sh -y

# Local install with custom SSH port and server name
./install_local.sh -p 2222 -n myserver -y

# Remote install to a server
./install_remote.sh -H myserver.com -u admin -y

# Remote install with custom port, skip SSH key setup
./install_remote.sh -H 192.168.1.100 -p 2222 -u root --key-action skip -y

# Use custom config file
./install_local.sh -c /path/to/config.json -y
```

### Download and Run (GitHub)

Local install (interactive):
```bash
curl -fsSL https://raw.githubusercontent.com/hletrd/setup/main/install_local.sh | sh
```

Remote install (interactive):
```bash
curl -fsSL https://raw.githubusercontent.com/hletrd/setup/main/install_remote.sh | sh
```

## NVIDIA CUDA Installation

For systems with NVIDIA GPUs, use the dedicated NVIDIA scripts:

```bash
# Local installation (requires sudo)
sudo ./install_nvidia_local.sh

# Remote installation
./install_nvidia_remote.sh -H myserver.com -u admin
```

**Installed components:**
- CUDA Toolkit (latest version from NVIDIA repository)
- nvidia-driver-open (open-source kernel driver)
- nvidia-utils (nvidia-smi and utilities)

**Supported distributions:** Ubuntu, Debian, RHEL, Fedora

## Ubuntu Autoinstall ISO

Create automated Ubuntu Server installation media:

```bash
cd autoinstall/

# Create autoinstall ISO
./create-autoinstall-iso.sh ubuntu-24.04-live-server-amd64.iso

# Outputs: ubuntu-autoinstall.iso
```

**Requirements:** `xorriso`, `p7zip`

**Configuration files:**
- `user-data`: Cloud-init autoinstall configuration
- `meta-data`: Instance metadata

## Directory Structure

```
setup/
├── install_local.sh          # Main local installation script
├── install_remote.sh         # Main remote installation script
├── install_nvidia_local.sh   # NVIDIA CUDA local installer
├── install_nvidia_remote.sh  # NVIDIA CUDA remote installer
├── config.json               # Installation configuration
├── autoinstall/              # Ubuntu autoinstall tools
│   ├── create-autoinstall-iso.sh
│   ├── user-data
│   └── meta-data
├── configs/                  # Pre-configured tool settings
│   ├── codex/
│   ├── gh/
│   └── opencode/
└── mcp/                      # MCP server configurations
    └── servers/
        ├── auggie-context.json
        ├── context7.json
        ├── fetch.json
        ├── filesystem.json
        ├── git.json
        ├── github.json
        ├── jupyter.json
        ├── memory.json
        ├── playwright.json
        └── sequential-thinking.json
```

## Notes

- Generated SSH keys are stored in `./.secret.pem` and `./.pub` in the working directory
- The scripts create `/etc/sudoers.d/$USER` to grant passwordless sudo for the current user
- After first run, execute `p10k configure` to customize your Powerlevel10k prompt
- On macOS, the default shell change requires manual execution: `chsh -s /bin/zsh`
- Alpine Linux uses musl libc, so pre-built Node.js binaries are not available (nvm installs but Node.js build may fail)
