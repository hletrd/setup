---
name: agent-browser-network
version: 1.0.0
description: |
  Network interception, request monitoring, cookie management, localStorage
  and sessionStorage operations, HTTP headers, and credentials.
allowed-tools:
  - Bash
---

# Agent Browser: Network & Storage

Intercept requests, manage cookies, and access browser storage.

## Network Interception

```sh
agent-browser network route <url>              # Intercept matching requests
agent-browser network route <url> --abort      # Block matching requests
agent-browser network route <url> --body <json>  # Mock response with JSON body
agent-browser network unroute [url]            # Remove route (all if no URL)
```

## Request Monitoring

```sh
agent-browser network requests                 # View all tracked requests
agent-browser network requests --filter <api>  # Filter by URL pattern
```

## Cookies

```sh
agent-browser cookies                          # Get all cookies
agent-browser cookies set <name> <value>       # Set a cookie
agent-browser cookies clear                    # Clear all cookies
```

## localStorage

```sh
agent-browser storage local                    # Get all localStorage entries
agent-browser storage local <key>              # Get specific key
agent-browser storage local set <key> <value>  # Set key-value pair
agent-browser storage local clear              # Clear all localStorage
```

## sessionStorage

```sh
agent-browser storage session                    # Get all sessionStorage entries
agent-browser storage session <key>              # Get specific key
agent-browser storage session set <key> <value>  # Set key-value pair
agent-browser storage session clear              # Clear all sessionStorage
```

## HTTP Headers & Auth

```sh
agent-browser set headers '{"X-Custom": "value"}'  # Set extra HTTP headers
agent-browser set credentials <user> <pass>         # HTTP basic auth credentials
```

## Examples

```sh
# Block analytics requests
agent-browser network route "*analytics*" --abort

# Mock an API response
agent-browser network route "*/api/user" --body '{"name":"Test","role":"admin"}'

# Monitor API calls
agent-browser network requests --filter "/api/"

# Set auth cookie
agent-browser cookies set "session" "abc123"

# Read a localStorage token
agent-browser storage local "authToken"
```

## Guidelines

- Route patterns support glob matching (`*` wildcards)
- Use `--abort` to block ads, tracking, or external resources during testing
- Use `--body` to mock API responses for testing without a backend
- Cookie/storage operations work on the current page's domain
