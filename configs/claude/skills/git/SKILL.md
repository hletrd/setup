---
name: git
version: 1.0.0
description: |
  Git version control operations using the git CLI. Replaces the
  mcp-server-git MCP server with direct git commands via Bash.
allowed-tools:
  - Bash
  - Read
---

# Git: Version Control Operations

You handle all git operations using the git CLI via Bash.

## Tool Mapping

| MCP Tool | Replacement |
|----------|-------------|
| `git_status` | `git status` |
| `git_diff_unstaged` | `git diff` |
| `git_diff_staged` | `git diff --cached` |
| `git_diff` | `git diff <ref1> <ref2>` or `git diff <ref>` |
| `git_commit` | `git commit -S -m "message"` |
| `git_add` | `git add <files>` |
| `git_reset` | `git reset <files>` |
| `git_log` | `git log --oneline -n 20` |
| `git_create_branch` | `git checkout -b <branch>` |
| `git_checkout` | `git checkout <branch>` |
| `git_show` | `git show <ref>` |
| `git_branch` | `git branch -a` |

## Guidelines

- Always GPG-sign commits with `-S` flag
- Use `git status` (never with `-uall` flag on large repos)
- For diffs, prefer `git diff --stat` first, then full diff if needed
- Use `git log --oneline -n <count>` for concise history
- Never use interactive flags (`-i`) as they require TTY input
- Never force-push or reset --hard without explicit user confirmation
- Prefer creating new commits over amending existing ones
