# Basic setup scripts

An assortment of scripts to bootstrap a new system.

- `install_local.sh`: a local script to run on the target machine.
- `install_remote.sh`: a remote script to run from local machine over SSH.
- `config.json`: optional configuration file to pre-configure installation behavior.

## Features

### System Configuration
- Update system packages using the available package manager
- Install `openssh-server`, enable the SSH service, and open the SSH port in the firewall (UFW or iptables)
- Enable passwordless sudo for the current user
- Install base tools: `zsh`, `figlet`, `screenfetch`, `git`, `curl`, `vim`
- Configure MOTD with screenfetch and a figlet banner
- Register an SSH public key (prompted; generates one if omitted)

### Shell Setup (Zinit + Powerlevel10k)
- Install [zinit](https://github.com/zdharma-continuum/zinit) plugin manager
- Set [Powerlevel10k](https://github.com/romkatv/powerlevel10k) as default theme
- Enable `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins via zinit
- Configure Powerlevel10k instant prompt for fast shell startup

### Package Managers
- **nvm**: Node Version Manager with latest LTS Node.js
- **uv**: Fast Python package manager by Astral
- **cargo**: Rust toolchain via rustup

### Python Tools (via uv)
- **ruff**: Fast Python linter and formatter
- **ty**: Python type checker

### Modern CLI Tools
All tools are configurable via `config.json`. Aliases replace original commands:

| Tool | Replaces | Alias |
|------|----------|-------|
| eza | ls | `ls`, `ll`, `la` |
| bat | cat | `cat` |
| dust | du | `du` |
| duf | df | `df` |
| fd | find | `find` |
| ripgrep | grep | `grep` |
| sd | sed | `sed` |
| choose | cut/awk | `cut` |
| bottom | top/htop | `top` |
| procs | ps | `ps` |
| gping | ping | `ping` |
| zoxide | cd | `cd` → `z` |
| mcfly | Ctrl+R | Enhanced history search |
| fzf | - | Fuzzy finder |
| delta | git diff | Git pager |
| hishtory | history | Enhanced shell history |
| cheat | - | Command cheat sheets |
| lsd | ls | Alternative ls replacement |

### MCP (Model Context Protocol) Servers
Configurable MCP servers for AI-assisted development:
- agentic-tools, auggie-context, claude-context, context7
- fetch, filesystem, git, github, graphiti
- jupyter, memory, playwright, sequential-thinking

### Editor Integration
MCP configuration is symlinked to supported editors:
- Cursor, Codex, OpenCode, Antigravity, Claude Desktop

## Configuration

Create a `config.json` file to pre-configure installation options:

```json
{
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
    "eza": true,
    "bat": true,
    "fzf": true,
    "zoxide": true
  },
  "mcp_servers": {
    "github": true,
    "filesystem": true
  },
  "editors": {
    "cursor": true,
    "claude_desktop": true
  }
}
```

Set any value to `false` to skip that component.

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

# Local install with custom SSH port
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

## Notes

- Generated keys are stored in `./.secret.pem` and `./.pub` in the working directory.
- The scripts create `/etc/sudoers.d/$USER` to grant passwordless sudo for the current user.
- After first run, execute `p10k configure` to customize your Powerlevel10k prompt.
