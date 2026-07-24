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
├── configs/                  # Pre-configured tool settings and backups (claude, codex, git, gh, opencode, zellij, zsh)
├── mcp/servers/              # MCP server configuration snippets
└── tests/                    # Automated testing suite
```

## Key Technologies

- **Shell Scripts**: All scripts use POSIX `sh` for maximum compatibility
- **Supported Platforms**: macOS (Homebrew), Ubuntu/Debian (apt), Fedora/RHEL (dnf/yum), Arch (pacman), Alpine (apk), OpenWrt (opkg)
- **Package Managers Installed**: fnm (Node.js), pnpm (via corepack), uv (Python), cargo (Rust), Homebrew (macOS)
- **Tools Installed**: zsh, zinit, fzf, eza, bat, fd, ripgrep, zoxide, delta, neovim, and 20+ CLI tools

## Knowledge Base (Current Defaults)

- **AI CLI stack**: `@anthropic-ai/claude-code`, `opencode-ai`, `@openai/codex`, `agent-browser`
- **AI bootstrap hooks**: run `agent-browser install` when available
- **Moshi (iOS remote control)**: `moshi-hook` from the `rjyo/moshi` Homebrew tap installs the bidirectional approval daemon (covers Claude Code, Codex, OpenCode hooks in one). `rjyo/moshi-skill` via `npx skills add rjyo/moshi-skill -y -g` adds the `moshi-best-practices` and `play-developer-console` skills to `~/.agents/skills/` with symlinks into `~/.claude/skills/`. Pairing: prefer `moshi-hook pair --token <T> --store file --name <short>` — Keychain is unavailable over SSH and the explicit short name avoids the iOS app collapsing long hostnames to a duplicate label
- **Moshi prerequisites**: `mosh` + `tmux` installed; `brew shellenv` must be loaded in `~/.zshenv` (not only `~/.zprofile`) so non-interactive `zsh -c` launched by SSH/Mosh resolves `mosh-server` and `tmux`. macOS App Firewall must whitelist `/opt/homebrew/bin/mosh-server` (`sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add` then `--unblockapp`) — without this, SSH works but the Mosh UDP handshake silently fails. Headless hosts without a console login can't use `brew services start` (`gui/<uid>` domain missing); load the agent into `user/<uid>` via `launchctl bootstrap user/$(id -u) ~/Library/LaunchAgents/homebrew.mxcl.moshi-hook.plist` instead
- **Claude Code plugins (enabled in `configs/claude/settings.json`)**: `codex@openai-codex`, plus `frontend-design`, `code-simplifier`, `superpowers`, `skill-creator`, `feature-dev`, `ralph-loop`, `code-review`, `security-guidance` from `claude-plugins-official`
- **Default external MCP servers**: none; an optional `agent-browser` snippet remains under `mcp/servers/`
- **Skills (replacing MCP servers)**: `agent-browser` (9 subskills: core, config, debug, interact, network, query, state, visual, wait), `fetch`, `filesystem`, `git`, `github`, `korean-naturalizer`, `playwright`, `review-plan-fix`, `writing-fixer` (17 skills total; sourced from `configs/claude/skills/` and installed into both `~/.claude/skills/` and `~/.codex/skills/`)
- **User backup restore policy**: restore `~/.gitconfig`, `~/.config/git/ignore`, `~/.claude/{settings.json,settings.local.json,statusline-command.sh}`, `~/.codex/{config.toml,instructions.md,rules/default.rules}`, `~/.config/opencode/{oh-my-openagent.json,opencode.json}`, `~/.config/zellij/{config.kdl,layouts/custom-compact.kdl}`, and `~/.{profile,zprofile,zshenv,zshrc,p10k.zsh}` from `configs/` only when target files are missing
- **Secret handling policy**: do not back up credential/token-bearing local files (for example auth stores and token-bearing YAML/JSON files)
- **zsh alias policy**: add `alias codex="codex --dangerously-bypass-approvals-and-sandbox"`; do not alias `cat`, `grep`, `sed`, or `ping`
- **Codex helper scripts** (`configs/codex/bin/`, installed to `~/.local/bin/` by both installers; self-contained Node, no deps): `codex-loop` — keeps ONE Codex `exec` turn alive forever as a resident worker fed by a per-cwd file queue (`~/.codex-loop/<sha256(cwd)[:12]>/queue/*.task`; subcommands `start|add|status|stop|tail`), so queued work rides across 5h usage-limit windows — the workspace spend-cap gate is only enforced when a NEW top-level turn starts (measured 2026-07-16), so start the loop while the window has headroom; `codex-keepgoing` — runs a single Codex task across rate-limit windows by polling the ChatGPT `wham/usage` endpoint (token read from `~/.codex/auth.json`) and `codex exec resume`-ing after each 5h reset (`--resume <id>` carrier mode drives an existing session past an active owner spend cap — resume is not gated by it; also `--last`, `--check`, `--once`; defaults `--max-resumes 12`, `--max-hours 24`); `codex-loop-watchdog` — the 24/365 supervisor: a launchd tick (`configs/codex/launchd/com.user.codex-loop-watchdog.plist`, StartInterval 60, RunAtLoad, installed **not loaded**) that (1) restarts any dead `codex-loop` **only when the usage oracle says the gate is open** (so it never spams doomed starts under a closed cap/window — the loop dies silently on account-switch 401s, reboots, crashes, codex upgrades) and (2) drains a drop-in **inbox** dir into each loop's queue (`add --cwd DIR [--inbox DIR] [--model M]` / `remove` / `list` / `pause` / `resume`; config `~/.codex-loop/watchdog.json`). Hardened: single-flight tick lock with age-based orphan recovery, atomic state writes, pid-recycling guard (`ps` command check), fnm-node resolution under launchd, loop.log + processed/ rotation/pruning, survives a corrupt config. **Opt-in**: register a loop then `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.codex-loop-watchdog.plist`. Tests: `tests/codex-loop-watchdog.test.mjs` (20 cases, `node --test`, mock codex + mock wham server, zero deps). None of the three bypass the 5h/weekly windows — they wait for resets instead of hard-failing. `codex-task` — the task/queue management front-end for a **general** loop (the loop runs from a neutral empty workspace, e.g. `~/flash-shared/codex-workspaces/<host>/`; each task carries its own repo context via `--repo PATH` or inline text, so one worker serves any repo). Resolves the target loop from `~/.codex-loop/watchdog.json` (single registered loop, or `--cwd`). Subcommands `submit`/`ls`/`show`/`log`/`rm`/`stats`/`purge`/`where`; task ids are time-sortable (`YYYYMMDD-HHMMSS-hex`, stable across queue→done, keeps codex-loop's FIFO); state (PENDING/QUEUED/RUNNING/DONE) is inferred from file location (RUNNING = oldest queue file while the loop pid is alive) with **no codex-loop changes**. Writes directly to the loop's queue so it works with or without the watchdog. Tests: `tests/codex-task.test.mjs` (18 cases, `node --test`, zero deps)
- **Claude Code keychain prompt after updates (macOS)**: each native-installer update drops a new binary at `~/.local/share/claude/versions/<ver>`, and the login-keychain item `Claude Code-credentials` has its ACL bound to the previous binary — so the first launch after every update re-prompts for keychain access. Fix: recreate the item with an any-app ACL — read the secret (`security find-generic-password -s "Claude Code-credentials" -a "$USER" -w`), delete the item, then re-add via `printf 'add-generic-password -a "%s" -s "Claude Code-credentials" -A -X %s\n' "$USER" "$(printf '%s' "$CREDS" | xxd -p | tr -d '\n')" | security -i`. If one more prompt still appears (partition list), run `security set-generic-password-partition-list -S "apple-tool:,apple:,teamid:Q6L2SF6YDW" -s "Claude Code-credentials" -a "$USER"` once (asks for the login password) to whitelist Anthropic's signing team permanently

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
2. Format: `"name": { "command": "...", "args": [...], "env": {...} }`
3. Use `__HOME__` placeholder for home directory paths in JSON snippets
4. Add `cfg_mcp_<name>` toggle variable in both `install_local.sh` and `install_remote.sh`:
   - Default value (e.g., `cfg_mcp_myserver="true"`)
   - Config loading via `set_if_present cfg_mcp_myserver "$(json_get_bool "myserver" "$config_file")"`
   - Case entry in `is_server_enabled()` function
5. In `install_remote.sh`, also add: config passthrough variable and inline `write_server_config` heredoc
6. Update `configs/codex/config.toml` with corresponding `[mcp_servers.name]` section

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
