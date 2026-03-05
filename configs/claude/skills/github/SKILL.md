---
name: github
version: 1.0.0
description: |
  GitHub platform operations using the gh CLI. Replaces the GitHub MCP server
  (Docker-based ghcr.io/github/github-mcp-server) with native gh commands.
allowed-tools:
  - Bash
  - Read
  - Write
---

# GitHub: Platform Operations via gh CLI

You handle all GitHub operations using the `gh` CLI via Bash.

## Tool Mapping

### Issues
| MCP Tool | Replacement |
|----------|-------------|
| `list_issues` | `gh issue list` |
| `issue_read` | `gh issue view <number>` |
| `issue_write` (create) | `gh issue create --title "..." --body "..."` |
| `issue_write` (update) | `gh issue edit <number> --title/--body/--add-label` |
| `issue_write` (close) | `gh issue close <number> --reason <reason>` |
| `add_issue_comment` | `gh issue comment <number> --body "..."` |
| `search_issues` | `gh search issues "<query>"` |

### Pull Requests
| MCP Tool | Replacement |
|----------|-------------|
| `list_pull_requests` | `gh pr list` |
| `pull_request_read` | `gh pr view <number>` |
| `create_pull_request` | `gh pr create --title "..." --body "..."` |
| `update_pull_request` | `gh pr edit <number>` |
| `merge_pull_request` | `gh pr merge <number>` |
| `pull_request_review_write` | `gh pr review <number> --approve/--comment/--request-changes` |
| `search_pull_requests` | `gh search prs "<query>"` |

### Repositories
| MCP Tool | Replacement |
|----------|-------------|
| `create_repository` | `gh repo create <name>` |
| `fork_repository` | `gh repo fork <owner/repo>` |
| `search_repositories` | `gh search repos "<query>"` |
| `get_file_contents` | `gh api repos/{owner}/{repo}/contents/{path}` |
| `create_or_update_file` | `gh api -X PUT repos/{owner}/{repo}/contents/{path}` |

### Releases & Tags
| MCP Tool | Replacement |
|----------|-------------|
| `list_releases` | `gh release list` |
| `get_latest_release` | `gh release view --json tagName,name,body` |
| `list_tags` | `gh api repos/{owner}/{repo}/tags` |
| `list_branches` | `gh api repos/{owner}/{repo}/branches` |

### Code Search
| MCP Tool | Replacement |
|----------|-------------|
| `search_code` | `gh search code "<query>"` |
| `search_users` | `gh search users "<query>"` |

### API Fallback
For any operation not covered by `gh` subcommands:
```sh
gh api <endpoint> [--method GET|POST|PUT|DELETE] [-f key=value]
```

### Viewing PR Comments
```sh
gh api repos/{owner}/{repo}/pulls/{number}/comments
```

## Guidelines

- Always use `gh` CLI instead of raw API calls when a subcommand exists
- Use `--json <fields>` for machine-readable output
- Use `--jq <expression>` to filter JSON output
- For cross-repo operations, specify `-R owner/repo`
- Use heredocs for multi-line PR/issue bodies
- Never create/comment on public issues/PRs without user confirmation
