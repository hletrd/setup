---
name: agent-browser
version: 1.0.0
description: |
  Headless browser automation CLI for AI agents. Core navigation, session
  management, tabs, frames, and dialogs using the agent-browser CLI.
allowed-tools:
  - Bash
  - Read
---

# Agent Browser: Core Navigation & Session

You handle browser automation using the `agent-browser` CLI. This is a fast Rust CLI
with Node.js fallback for headless Chromium automation.

## Setup

```sh
# Install globally (one-time)
npm install -g agent-browser
agent-browser install          # Downloads Chromium
agent-browser install --with-deps  # Linux: also install system deps
```

## Navigation

```sh
agent-browser open <url>       # Navigate to URL (aliases: goto, navigate)
agent-browser back             # Go back in history
agent-browser forward          # Go forward in history
agent-browser reload           # Reload current page
```

## Tabs & Windows

```sh
agent-browser tab              # List open tabs
agent-browser tab new [url]    # Open new tab
agent-browser tab <n>          # Switch to tab N
agent-browser tab close [n]    # Close tab N (default: current)
agent-browser window new       # Open new window
```

## Frames

```sh
agent-browser frame <sel>      # Switch to iframe
agent-browser frame main       # Back to main frame
```

## Dialogs

```sh
agent-browser dialog accept [text]  # Accept alert/prompt (optional input text)
agent-browser dialog dismiss        # Dismiss dialog
```

## Session Management

```sh
agent-browser session          # Show current session info
agent-browser session list     # List active sessions
agent-browser connect <port>   # Connect to browser via CDP
agent-browser close            # Close browser (aliases: quit, exit)
```

## Guidelines

- Always run `agent-browser install` before first use to download Chromium
- The browser runs headless by default
- Use `agent-browser open <url>` as the starting point for any automation
- Sessions persist across commands until `agent-browser close`
- Prefer `agent-browser` over Playwright for simple, single-command automations
- Use the specialized agent-browser-* skills for specific task categories
