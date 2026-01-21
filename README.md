# Basic setup scripts

Personal scripts to bootstrap a new system.

- `install_local.sh`: a local script to run on the target machine.
- `install_remote.sh`: a remote script to run from local machine over SSH.

## Basic configuration

- Update system packages using the available package manager.
- Install `openssh-server`, enable the SSH service, and open the SSH port in the firewall (UFW or iptables).
- Enable passwordless sudo for the current user.
- Install base tools: `zsh`, `figlet`, `screenfetch`, `git`, `curl`, `vim`.
- Configure MOTD with screenfetch and a figlet banner.
- Register an SSH public key (prompted; generates one if omitted).
- Install Oh My Zsh and enable `zsh-autosuggestions` and `zsh-syntax-highlighting`.
- Set the Oh My Zsh theme to `agnoster`.
- Install NVM and the latest Node.js LTS if Node is missing.
- Create a shared MCP server config and symlink it to supported clients.
- Append a few convenience settings to `~/.zshrc` (history, nvm sourcing, etc.).

## Download and run (GitHub)

Local install:

```bash
curl -fsSL https://raw.githubusercontent.com/hletrd/setup/main/install_local.sh | sh
```

Remote install:

```bash
curl -fsSL https://raw.githubusercontent.com/hletrd/setup/main/install_remote.sh | sh
```

## Notes

- Generated keys are stored in `./.secret.pem` and `./.pub` in the working directory.
- The scripts create `/etc/sudoers.d/$USER` to grant passwordless sudo for the current user.
