---
name: agent-browser-interact
version: 1.0.0
description: |
  Browser interaction commands: clicking, typing, filling forms, selecting
  options, scrolling, dragging, file uploads, and raw mouse/keyboard input.
allowed-tools:
  - Bash
  - Read
---

# Agent Browser: Interaction

Click, type, fill forms, scroll, drag, and control mouse/keyboard.

## Click & Focus

```sh
agent-browser click <sel>          # Click element
agent-browser click <sel> --new-tab  # Click, open in new tab
agent-browser dblclick <sel>       # Double-click element
agent-browser focus <sel>          # Focus element
agent-browser hover <sel>          # Hover over element
```

## Text Input

```sh
agent-browser type <sel> <text>    # Type into focused element
agent-browser fill <sel> <text>    # Clear field then fill with text
agent-browser keyboard type <text>       # Type with real keystrokes
agent-browser keyboard inserttext <text> # Insert text without key events
```

## Key Presses

```sh
agent-browser press <key>          # Press key combo (alias: key)
agent-browser keydown <key>        # Hold key down
agent-browser keyup <key>          # Release key
```

Key names: `Enter`, `Tab`, `Escape`, `ArrowDown`, `Control+a`, `Meta+c`, etc.

## Form Controls

```sh
agent-browser select <sel> <val>   # Select dropdown option by value
agent-browser check <sel>          # Check a checkbox
agent-browser uncheck <sel>        # Uncheck a checkbox
```

## Scrolling

```sh
agent-browser scroll <dir> [px]    # Scroll: up, down, left, right
agent-browser scrollintoview <sel> # Scroll element into viewport (alias: scrollinto)
```

## Drag & Drop

```sh
agent-browser drag <src> <tgt>     # Drag from source to target selector
```

## File Upload

```sh
agent-browser upload <sel> <files> # Upload file(s) to input element
```

## Raw Mouse Control

```sh
agent-browser mouse move <x> <y>   # Move cursor to coordinates
agent-browser mouse down [button]   # Press mouse button (left/right/middle)
agent-browser mouse up [button]     # Release mouse button
agent-browser mouse wheel <dy> [dx] # Scroll wheel
```

## Guidelines

- Use `fill` to replace input content; use `type` to append
- Selectors can be CSS selectors or text-based (see agent-browser-query find commands)
- For complex key combos, use `press` with modifier notation: `Control+Shift+k`
- Mouse coordinates are relative to the viewport
