---
name: agent-browser-query
version: 1.0.0
description: |
  Query page content: get text, HTML, attributes, element state, accessibility
  snapshots, and find elements by role, text, label, placeholder, or testid.
allowed-tools:
  - Bash
  - Read
---

# Agent Browser: Query & Find

Extract information from pages and locate elements.

## Get Element Content

```sh
agent-browser get text <sel>       # Get text content of element
agent-browser get html <sel>       # Get innerHTML
agent-browser get value <sel>      # Get input/textarea value
agent-browser get attr <sel> <attr>  # Get specific attribute value
```

## Get Page Info

```sh
agent-browser get title            # Get page title
agent-browser get url              # Get current URL
agent-browser get count <sel>      # Count matching elements
agent-browser get box <sel>        # Get bounding box {x, y, width, height}
agent-browser get styles <sel>     # Get computed CSS styles
```

## Element State Checks

```sh
agent-browser is visible <sel>     # Check if element is visible
agent-browser is enabled <sel>     # Check if element is enabled
agent-browser is checked <sel>     # Check if checkbox/radio is checked
```

## Accessibility Snapshot

```sh
agent-browser snapshot             # Full accessibility tree with refs
agent-browser snapshot -i          # Include invisible elements
agent-browser snapshot -C          # Compact output
agent-browser snapshot -c          # Include children details
agent-browser snapshot -d          # Include descriptions
agent-browser snapshot -s          # Include states
```

## Find Elements by Semantic Locators

All `find` commands take an `<action>` (click, fill, type, etc.) and optional `[value]`.

```sh
agent-browser find role <role> <action> [value]     # By ARIA role (--name, --exact)
agent-browser find text <text> <action>             # By visible text (--exact)
agent-browser find label <label> <action> [value]   # By associated label
agent-browser find placeholder <ph> <action> [value]  # By placeholder text
agent-browser find alt <text> <action>              # By alt text (images)
agent-browser find title <text> <action>            # By title attribute
agent-browser find testid <id> <action> [value]     # By data-testid attribute
```

## Positional Find

```sh
agent-browser find first <sel> <action> [value]   # First matching element
agent-browser find last <sel> <action> [value]    # Last matching element
agent-browser find nth <n> <sel> <action> [value] # Nth matching element (0-based)
```

## Examples

```sh
# Get the page title
agent-browser get title

# Check if login button is visible
agent-browser is visible "button.login"

# Click the submit button by role
agent-browser find role button click --name "Submit"

# Fill email field by label
agent-browser find label "Email" fill "user@example.com"

# Get accessibility tree for page understanding
agent-browser snapshot -C
```

## Guidelines

- Use `snapshot` to understand page structure before interacting
- Prefer semantic locators (`find role`, `find label`) over CSS selectors
- `--exact` flag enables exact text matching (default is substring)
- State checks return exit code 0 (true) or 1 (false) for scripting
