---
name: memory
version: 1.0.0
description: |
  Persistent memory system using markdown files at ~/memory/. Replaces the
  memora MCP server with a human-readable, grep-searchable knowledge base
  organized by topic with YAML frontmatter and cross-links.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# Memory: Markdown-Based Knowledge Base

You manage persistent memories as markdown files at `~/memory/`. This replaces the memora MCP server with a human-readable, version-controllable knowledge base.

## Directory Structure

```
~/memory/
├── index.md              # Master index with links to all categories
├── projects/             # Per-project memories
├── infrastructure/       # Infra knowledge
├── patterns/             # Reusable patterns & solutions
├── decisions/            # Architectural decisions (ADRs)
└── reference/            # Quick reference cards
```

## File Format

Every memory file uses YAML frontmatter:

```markdown
---
title: Short descriptive title
tags: [tag1, tag2, tag3]
created: 2026-03-03
updated: 2026-03-03
links:
  - ../category/related-file.md
---

# Title

Content here...
```

## Operations

### Create a memory
1. Choose the appropriate subdirectory
2. Create the file with frontmatter using `Write`
3. Update `~/memory/index.md` to include a link

### Read a memory
Use `Read` tool on `~/memory/<category>/<file>.md`

### Update a memory
Use `Edit` tool, update the `updated` date in frontmatter

### Search memories
- By filename: `Glob("~/memory/**/*.md")`
- By content: `Grep(pattern, path="~/memory/")`
- By tag: `Grep("tags:.*tagname", path="~/memory/")`

### List all memories
`Glob("~/memory/**/*.md")`

### Delete a memory
Ask user for confirmation, then `Bash(rm ~/memory/<path>)` and update index

### Cross-reference
Use relative markdown links: `[related topic](../category/file.md)`

## Guidelines

- Always create `~/memory/` and `~/memory/index.md` on first use if they don't exist
- Use descriptive filenames with hyphens: `nfd-nfc-unicode.md`
- Keep files focused on one topic
- Update the `updated` field when modifying
- Add cross-links between related memories
- Tag consistently for searchability
- Never store secrets or credentials in memory files
