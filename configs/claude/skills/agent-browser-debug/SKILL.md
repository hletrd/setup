---
name: agent-browser-debug
version: 1.0.0
description: |
  Browser debugging: execute JavaScript, view console output and page errors,
  record traces, and run performance profiling.
allowed-tools:
  - Bash
  - Read
---

# Agent Browser: Debug & Evaluate

Run JavaScript, inspect console output, capture errors, and profile performance.

## Execute JavaScript

```sh
agent-browser eval "<js>"              # Run JavaScript in page context
agent-browser eval -b "<base64>"       # Run base64-encoded script
agent-browser eval --stdin             # Read script from stdin
```

## Console Messages

```sh
agent-browser console                  # View console messages (log, warn, info)
agent-browser console --clear          # Clear console message buffer
```

## Page Errors

```sh
agent-browser errors                   # View uncaught page errors
agent-browser errors --clear           # Clear error buffer
```

## Tracing (Timeline Recording)

```sh
agent-browser trace start [path]       # Start recording trace
agent-browser trace stop [path]        # Stop and save trace file
```

Trace files can be opened in Chrome DevTools (chrome://tracing).

## Performance Profiling

```sh
agent-browser profiler start           # Start CPU profiling
agent-browser profiler stop [path]     # Stop and save profile
```

## Examples

```sh
# Get the current user from app state
agent-browser eval "JSON.stringify(window.__STORE__.user)"

# Check for JavaScript errors on a page
agent-browser open https://example.com
agent-browser errors

# Monitor console output during interaction
agent-browser console

# Record a performance trace
agent-browser trace start /tmp/trace.json
# ... perform actions ...
agent-browser trace stop /tmp/trace.json

# Profile a slow operation
agent-browser profiler start
agent-browser click "#heavy-button"
agent-browser wait 5000
agent-browser profiler stop /tmp/profile.json

# Execute multi-line script via stdin
echo 'document.querySelectorAll("a").length' | agent-browser eval --stdin
```

## Guidelines

- Use `eval` for extracting app state or running custom assertions
- Check `errors` after page load to catch JavaScript issues
- Use `console` to monitor application logging during interactions
- Traces are useful for diagnosing slow page loads or animations
- Save trace/profile files to `/tmp/` for ephemeral debugging
