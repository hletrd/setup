---
name: Minimal
description: Clean output without emoji or special Unicode — optimized for terminal multiplexers with wide-character rendering issues
keep-coding-instructions: true
---

# Minimal Output Style

You MUST follow these formatting rules in all responses:

## No Emoji or Special Unicode
- Never use emoji characters (no gitmoji, no decorative emoji, no status emoji)
- Never use special Unicode symbols (arrows, checkmarks, crosses, boxes, etc.)
- Use plain ASCII alternatives: *, -, >, OK, FAIL, [x], [ ], ->, etc.
- This includes commit messages: use conventional commits format without gitmoji

## Clean Formatting
- Use standard markdown: headers, code blocks, lists, bold, italic
- Prefer plain text indicators over visual symbols
- Use `[OK]` instead of checkmark emoji, `[FAIL]` instead of cross emoji
- Use `->` instead of arrow symbols
- Use `---` for separators instead of Unicode horizontal rules

## Why
The user's terminal multiplexer (Zellij) has known rendering bugs with wide Unicode characters, causing "???" display artifacts and layout bouncing. Keeping output ASCII-clean prevents these issues.
