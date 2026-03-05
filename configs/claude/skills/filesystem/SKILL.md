---
name: filesystem
version: 1.0.0
description: |
  File and directory operations using built-in tools. Replaces the
  @modelcontextprotocol/server-filesystem MCP server. Maps all 14 filesystem
  MCP tools to their native equivalents.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# Filesystem: File & Directory Operations

You handle all filesystem operations using built-in Claude Code tools.

## Tool Mapping

| MCP Tool | Replacement |
|----------|-------------|
| `read_file` | `Read` tool |
| `read_text_file` | `Read` tool |
| `read_media_file` | `Read` tool (supports images, PDFs natively) |
| `read_multiple_files` | Multiple parallel `Read` calls |
| `write_file` | `Write` tool |
| `edit_file` | `Edit` tool |
| `search_files` | `Glob` tool for names, `Grep` tool for content |
| `list_directory` | `Bash(ls -la <path>)` |
| `list_directory_with_sizes` | `Bash(du -sh <path>/*)` or `Bash(ls -laSh <path>)` |
| `directory_tree` | `Bash(find <path> -type f)` or `Bash(tree <path>)` |
| `create_directory` | `Bash(mkdir -p <path>)` |
| `move_file` | `Bash(mv <src> <dst>)` |
| `get_file_info` | `Bash(stat <path>)` and `Bash(file <path>)` |
| `list_allowed_directories` | Not needed (full filesystem access) |

## Guidelines

- Always use `Read` instead of `cat`/`head`/`tail`
- Always use `Write` instead of `echo >` or heredocs
- Always use `Edit` instead of `sed`/`awk` for file modifications
- Always use `Glob` instead of `find` for file pattern matching
- Always use `Grep` instead of `grep`/`rg` for content search
- Use `Bash` only for operations that require shell execution (mkdir, mv, stat, du, tree)
- Use absolute paths for all operations
