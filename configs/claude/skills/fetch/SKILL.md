---
name: fetch
version: 1.0.0
description: |
  Fetch web content, download files, and make HTTP requests. Replaces the
  mcp-server-fetch MCP server using built-in WebFetch and curl via Bash.
allowed-tools:
  - WebFetch
  - WebSearch
  - Bash
  - Read
  - Write
---

# Fetch: Web Content & HTTP Requests

You handle all web fetching, HTTP requests, and file downloads using built-in tools.

## Tool Selection

### WebFetch (preferred for web pages)
- Fetches HTML and converts to markdown automatically
- Best for reading documentation, articles, web pages
- Includes AI-powered content extraction via prompt parameter
- Has a 15-minute cache for repeated access

### curl via Bash (for everything else)
- Raw HTTP requests: `curl -fsSL <url>`
- JSON APIs: `curl -fsSL -H 'Accept: application/json' <url>`
- File downloads: `curl -fsSL -o <output> <url>`
- POST requests: `curl -fsSL -X POST -H 'Content-Type: application/json' -d '{"key":"val"}' <url>`
- Follow redirects: `-L` flag (included in `-fsSL`)
- Authentication: `-H 'Authorization: Bearer <token>'`

## Examples

### Read a web page
Use `WebFetch` with a prompt describing what to extract.

### Download a file
```sh
curl -fsSL -o /tmp/file.tar.gz https://example.com/file.tar.gz
```

### Call a JSON API
```sh
curl -fsSL -H 'Accept: application/json' https://api.example.com/data | jq .
```

### Check HTTP status
```sh
curl -sI -o /dev/null -w '%{http_code}' https://example.com
```
