---
name: agent-browser-visual
version: 1.0.0
description: |
  Visual capture and comparison: screenshots, PDFs, element highlighting,
  accessibility snapshot diffs, screenshot diffs, and URL comparisons.
allowed-tools:
  - Bash
  - Read
---

# Agent Browser: Visual Capture & Comparison

Take screenshots, generate PDFs, highlight elements, and compare visual states.

## Screenshots

```sh
agent-browser screenshot [path]            # Screenshot visible viewport
agent-browser screenshot [path] --full     # Full page screenshot
agent-browser screenshot [path] --annotate # Screenshot with element annotations
```

Default path: `./screenshot.png` if omitted.

## PDF Export

```sh
agent-browser pdf <path>                   # Save page as PDF
```

## Element Highlighting

```sh
agent-browser highlight <sel>              # Visually highlight element on page
```

## Snapshot Diffs (Accessibility Tree)

```sh
agent-browser diff snapshot                      # Compare current vs last snapshot
agent-browser diff snapshot --baseline <file>    # Compare current vs saved baseline
```

## Screenshot Diffs (Visual)

```sh
agent-browser diff screenshot --baseline <file>  # Visual diff vs baseline image
```

## URL Comparison

```sh
agent-browser diff url <url1> <url2>             # Compare two URLs side by side
```

## Examples

```sh
# Take a full-page screenshot
agent-browser screenshot /tmp/page.png --full

# Save page as PDF
agent-browser pdf /tmp/report.pdf

# Highlight an element for debugging
agent-browser highlight "#error-message"

# Save baseline snapshot, make changes, then diff
agent-browser snapshot > /tmp/baseline.txt
# ... perform actions ...
agent-browser diff snapshot --baseline /tmp/baseline.txt

# Compare staging vs production
agent-browser diff url "https://staging.example.com" "https://example.com"
```

## Guidelines

- Use `--full` for pages with scrollable content
- Use `--annotate` to add visual labels to interactive elements
- Screenshot diffs are useful for visual regression testing
- Snapshot diffs compare the accessibility tree structure, not pixels
- Save screenshots to `/tmp/` for ephemeral captures
