# CLAUDE.md - Project Guidelines for AI Assistants

## Project Overview

This is a **system bootstrapping toolkit** that sets up development environments on new machines. It provides shell scripts for automated installation of development tools, CLI utilities, and configurations across multiple platforms.

## Repository Structure

```
setup/
├── install_local.sh          # Main local installation script (POSIX sh)
├── install_remote.sh         # Remote installation via SSH (POSIX sh)
├── install_nvidia_local.sh   # NVIDIA CUDA local installer
├── install_nvidia_remote.sh  # NVIDIA CUDA remote installer
├── config.json               # Installation configuration
├── autoinstall/              # Ubuntu autoinstall ISO creation
├── configs/                  # Pre-configured tool settings (codex, gh, opencode)
├── mcp/servers/              # MCP server configuration snippets
└── tests/                    # Automated testing suite
```

## Key Technologies

- **Shell Scripts**: All scripts use POSIX `sh` for maximum compatibility
- **Supported Platforms**: macOS (Homebrew), Ubuntu/Debian (apt), Fedora/RHEL (dnf/yum), Arch (pacman), Alpine (apk), OpenWrt (opkg)
- **Package Managers Installed**: fnm (Node.js), uv (Python), cargo (Rust), Homebrew (macOS)
- **Tools Installed**: zsh, zinit, fzf, eza, bat, fd, ripgrep, zoxide, delta, neovim, and 20+ CLI tools

## Coding Conventions

### Shell Script Standards
- Use POSIX `sh` syntax (`#!/bin/sh`) - NOT bash-specific features
- Use `printf` instead of `echo` for portability
- Quote all variable expansions: `"$variable"`
- Use `command -v` instead of `which` for command detection
- Handle all exit codes explicitly
- Support both interactive and non-interactive (`-y`) modes

### Configuration
- JSON format for configuration files (`config.json`)
- MCP server configs are JSON snippets in `mcp/servers/`
- TOML format for Codex config

### Testing
- Tests run via `tests/run_tests.sh`
- Docker-based testing for Ubuntu, Fedora, Arch, Alpine, OpenWrt
- Both local (`install_local.sh`) and remote (`install_remote.sh`) tests
- Set `KEEP_CONTAINERS=true` to preserve test containers for debugging

## Common Commands

```bash
# Run local installation (interactive)
./install_local.sh

# Run local installation (non-interactive with defaults)
./install_local.sh -y

# Run remote installation
./install_remote.sh -H hostname -u username -y

# Run all tests
cd tests && ./run_tests.sh

# Create Ubuntu autoinstall ISO
cd autoinstall && ./create-autoinstall-iso.sh ubuntu-24.04-live-server-amd64.iso
```

## Important Notes

1. **Cross-platform compatibility**: Scripts must work on all supported platforms
2. **Non-interactive mode**: All prompts must be skippable with `-y` flag
3. **Idempotency**: Scripts should be safe to run multiple times
4. **Error handling**: Use `set -e` and handle failures gracefully
5. **SSH key handling**: Supports generate, add, or skip modes for SSH keys

## Skills

### @shell-scripting
Writing and modifying POSIX-compliant shell scripts in this repository:
- Always use `sh` syntax, avoid bash-isms
- Use `printf` for output, not `echo`
- Quote all variables: `"$var"`
- Use `command -v cmd` to check for commands
- Add platform detection: check for `apt-get`, `dnf`, `pacman`, `apk`, `opkg`, `brew`
- Support both interactive and non-interactive modes

### @add-cli-tool
To add a new CLI tool to the installation scripts:
1. Add toggle to `config.json` under `cli_tools`
2. Add installation logic to both `install_local.sh` and `install_remote.sh`
3. Handle installation for each platform (apt, dnf, pacman, apk, brew, cargo)
4. Prefer `cargo install` for Rust tools when native packages unavailable

### @add-mcp-server
To add a new MCP server configuration:
1. Create JSON snippet in `mcp/servers/` (e.g., `myserver.json`)
2. Format: `"name": { "command": "npx", "args": [...], "env": {...} }`
3. Use `__HOME__` placeholder for home directory paths
4. Update `configs/codex/config.toml` with corresponding `[mcp_servers.name]` section

### @testing
Running and modifying tests:
- Tests in `tests/run_tests.sh` use Docker containers
- Verify installation results with `verify_results()` function
- Add new platform tests by adding `test_docker_platform()` calls
- Remote tests use SSH via `test_remote_ssh()` function
- Check logs in `tests/results/` for debugging

### @autoinstall
Creating Ubuntu autoinstall ISOs:
- Edit `autoinstall/user-data` for installation configuration
- Run `./create-autoinstall-iso.sh <source.iso>` to create bootable ISO
- Requires `xorriso` and `p7zip` installed
- Default credentials: username `ubuntu`, password `1`

