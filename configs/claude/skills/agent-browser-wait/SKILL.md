---
name: agent-browser-wait
version: 1.0.0
description: |
  Wait for elements, timeouts, text appearance, URL patterns, page load
  states, and custom JavaScript conditions.
allowed-tools:
  - Bash
---

# Agent Browser: Wait

Pause execution until conditions are met.

## Wait for Element

```sh
agent-browser wait <selector>      # Wait until element is visible
```

## Wait for Time

```sh
agent-browser wait <ms>            # Wait for N milliseconds
```

## Wait for Text

```sh
agent-browser wait --text "text"   # Wait until text appears on page
```

## Wait for URL

```sh
agent-browser wait --url "pattern" # Wait until URL matches pattern
```

## Wait for Load State

```sh
agent-browser wait --load load           # DOM content loaded
agent-browser wait --load domcontentloaded  # DOM ready
agent-browser wait --load networkidle    # No network activity for 500ms
```

## Wait for JavaScript Condition

```sh
agent-browser wait --fn "document.querySelector('.done') !== null"
agent-browser wait --fn "window.appReady === true"
```

## Examples

```sh
# Wait for login form to appear
agent-browser wait "#login-form"

# Wait 2 seconds for animation
agent-browser wait 2000

# Wait for success message
agent-browser wait --text "Successfully saved"

# Wait for redirect to dashboard
agent-browser wait --url "/dashboard"

# Wait for SPA to fully load
agent-browser wait --load networkidle

# Wait for custom app state
agent-browser wait --fn "window.__APP_STATE__ === 'ready'"
```

## Guidelines

- Use element waits before interacting with dynamically loaded content
- Prefer `--load networkidle` for SPAs that load data after initial render
- Use `--fn` for complex application-specific conditions
- Combine with other commands: wait first, then interact
