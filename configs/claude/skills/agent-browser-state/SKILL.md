---
name: agent-browser-state
version: 1.0.0
description: |
  Browser authentication state management: save and restore login sessions,
  cookies, and storage across automation runs.
allowed-tools:
  - Bash
  - Read
---

# Agent Browser: Auth State Management

Save and restore browser authentication state (cookies, localStorage, sessionStorage)
across sessions.

## Save State

```sh
agent-browser state save <path>        # Save current auth state to file
```

Captures cookies, localStorage, and sessionStorage for the current context.

## Load State

```sh
agent-browser state load <path>        # Restore auth state from file
```

Load before navigating to apply saved authentication.

## List Saved States

```sh
agent-browser state list               # List all saved state files
```

## Inspect State

```sh
agent-browser state show <file>        # Show summary of saved state
```

## Rename State

```sh
agent-browser state rename <old> <new> # Rename a saved state file
```

## Clear State

```sh
agent-browser state clear [name]       # Clear specific state file
agent-browser state clear --all        # Clear all saved states
```

## Clean Old States

```sh
agent-browser state clean --older-than <days>  # Delete states older than N days
```

## Examples

```sh
# Login once and save the session
agent-browser open https://app.example.com/login
agent-browser fill "#email" "user@example.com"
agent-browser fill "#password" "secret"
agent-browser click "button[type=submit]"
agent-browser wait --url "/dashboard"
agent-browser state save auth-prod.json

# Reuse saved session in a later run
agent-browser state load auth-prod.json
agent-browser open https://app.example.com/dashboard

# Manage saved states
agent-browser state list
agent-browser state show auth-prod.json
agent-browser state clean --older-than 30
```

## Guidelines

- Save state after successful login to avoid re-authenticating
- State files contain sensitive session data - do not commit to git
- Load state before `open` to ensure cookies are set before navigation
- Use descriptive filenames: `auth-staging.json`, `auth-admin.json`
- Periodically clean old states to avoid stale sessions
