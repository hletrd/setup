<!-- OMC:START -->
<!-- OMC:VERSION:4.8.2 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<agent_catalog>
Prefix: `oh-my-claudecode:`. See `agents/*.md` for full prompts.

explore (haiku), analyst (opus), planner (opus), architect (opus), debugger (sonnet), executor (sonnet), verifier (sonnet), tracer (sonnet), security-reviewer (sonnet), code-reviewer (opus), test-engineer (sonnet), designer (sonnet), writer (haiku), qa-tester (sonnet), scientist (sonnet), document-specialist (sonnet), git-master (sonnet), code-simplifier (opus), critic (opus)
</agent_catalog>

<tools>
External AI: `/team N:executor "task"`, `omc team N:codex|gemini "..."`, `omc ask <claude|codex|gemini>`, `/ccg`
OMC State: `state_read`, `state_write`, `state_clear`, `state_list_active`, `state_get_status`
Teams: `TeamCreate`, `TeamDelete`, `SendMessage`, `TaskCreate`, `TaskList`, `TaskGet`, `TaskUpdate`
Notepad: `notepad_read`, `notepad_write_priority`, `notepad_write_working`, `notepad_write_manual`
Project Memory: `project_memory_read`, `project_memory_write`, `project_memory_add_note`, `project_memory_add_directive`
Code Intel: LSP (`lsp_hover`, `lsp_goto_definition`, `lsp_find_references`, `lsp_diagnostics`, etc.), AST (`ast_grep_search`, `ast_grep_replace`), `python_repl`
</tools>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.

Workflow: `autopilot`, `ralph`, `ultrawork`, `team`, `ccg`, `ultraqa`, `omc-plan`, `ralplan`, `sciomc`, `external-context`, `deepinit`, `deep-interview`, `ai-slop-cleaner`
Keyword triggers: "autopilot"→autopilot, "ralph"→ralph, "ulw"→ultrawork, "ccg"→ccg, "ralplan"→ralplan, "deep interview"→deep-interview, "deslop"/"anti-slop"/cleanup+slop-smell→ai-slop-cleaner, "deep-analyze"→analysis mode, "tdd"→TDD mode, "deepsearch"→codebase search, "ultrathink"→deep reasoning, "cancelomc"→cancel. Team orchestration is explicit via `/team`.
Utilities: `ask-codex`, `ask-gemini`, `cancel`, `note`, `learner`, `omc-setup`, `mcp-setup`, `hud`, `omc-doctor`, `omc-help`, `trace`, `release`, `project-session-manager`, `skill`, `writer-memory`, `ralph-init`, `configure-notifications`, `learn-about-omc` (`trace` is the evidence-driven tracing lane)
</skills>

<team_pipeline>
Stages: `team-plan` → `team-prd` → `team-exec` → `team-verify` → `team-fix` (loop).
Fix loop bounded by max attempts. `team ralph` links both modes.
</team_pipeline>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

<!-- OMC:END -->

<!-- User customizations -->
## Destructive Action Safety (CRITICAL)

- Before performing ANY destructive action, ALWAYS stop and explicitly ask the user for confirmation first.
- Destructive actions include but are not limited to:
  - **Filesystem**: Deleting files or directories (`rm`, `rmdir`, etc.), formatting/partitioning disks, overwriting files with unrelated content
  - **Services**: Removing or disabling existing service interfaces, endpoints, or configurations; stopping or killing running services/processes
  - **Database**: Dropping tables, truncating data, deleting records, modifying schemas destructively
  - **Git**: Force-pushing, resetting (`--hard`), rebasing published branches, deleting branches, discarding uncommitted changes
  - **DNS & Networking**: Modifying DNS records, changing IP/routing configurations, altering firewall rules or security groups — misconfiguration can cause total service outage or loss of remote access
  - **Authentication & Access**: Revoking or rotating API keys/tokens/certificates, modifying SSH keys, changing user permissions or access controls, disabling authentication mechanisms — can permanently lock out access
  - **Docker & Containers**: Removing containers, volumes, images, or networks; `docker system prune`; destroying persistent data volumes
  - **Deployment & Production**: Deploying to or modifying production environments, modifying CI/CD pipelines, publishing packages to registries
  - **Secrets & Credentials**: Using plaintext secrets/tokens shared in conversation (MUST warn user to rotate first), writing secrets to unencrypted files or logs
  - **External Communications**: Sending emails, Slack messages, or notifications to third parties; creating/commenting on public GitHub issues or PRs — these cannot be unsent
  - **System**: Removing packages, dependencies, or system components; modifying boot/system configurations; changing cron jobs or scheduled tasks
  - **Audit & Logs**: Truncating or deleting log files, audit trails, or monitoring data
  - **Encryption**: Changing or deleting encryption keys, certificates, or secure storage — can make encrypted data permanently unrecoverable
- This rule applies even when the user has requested the broader task — always double-check before the specific destructive step.
- Never assume destructive intent. When in doubt, ask.
- Violating this rule is strictly prohibited.

## Always Use Latest Versions (CRITICAL)

Before starting any project or adding dependencies, **always search for and use the latest stable versions** of all languages, frameworks, libraries, and tools. This rule applies globally to all projects.

- **Node.js**: Always use the latest LTS release. Currently Node.js 24 LTS (e.g., v24.13.x). When a new LTS becomes available, switch to it.
- **Next.js**: Always use the latest stable major version. Currently Next.js 16 (e.g., v16.1.x+). Upgrade when new stable majors release.
- **React**: Always use the latest stable version. Currently React 19.
- **TypeScript**: Always use the latest stable version. Use `"target": "ESNext"` and `"module": "ESNext"` in tsconfig.
- **Rust**: Always use the latest stable toolchain and the Rust 2024 edition (`edition = "2024"` in Cargo.toml). Currently Rust 1.93.x.
- **Python**: Always use the latest stable version. Currently Python >= 3.14. Always use `uv` for environment management.
- **ESNext**: Always target ESNext for JavaScript/TypeScript compilation and module resolution.
- **All other packages/libraries**: Always check for and use the latest stable version before installing or adding as a dependency. Never pin to outdated versions without explicit justification.

**Before writing any `package.json`, `Cargo.toml`, `pyproject.toml`, or similar**: search the web or check package registries to confirm the latest stable versions. Do not guess or rely on cached knowledge — versions change frequently.

## Git Commit Rules

- Do NOT add `Co-Authored-By` lines to commit messages. Never attribute Claude as author or co-author in any commit.
- ALWAYS GPG sign all git commits using the `-S` flag (e.g., `git commit -S -m "message"`).
- Commit in a fine-grained way: create one commit per single feature, fix, or enhancement. Do not bundle unrelated changes into a single commit.
- ALWAYS commit and push immediately after every iteration, enhancement, or fix. Do not batch changes.
- ALWAYS `git pull --rebase` before `git push`. This prevents push rejections due to remote changes. If the pull fails due to conflicts, resolve them before pushing.
- ALWAYS use **semantic commit messages** with [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <gitmoji> <description>`.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
  - Scope is optional but encouraged.
  - Use imperative mood, keep header under 72 characters.
  - Examples: `feat(auth): ✨ add OAuth2 login flow`, `fix(api): 🐛 resolve null pointer in response handler`, `docs(readme): 📝 update installation instructions`
- ALWAYS use gitmoji in commit messages. Place the gitmoji after scope and before description.

## Context Directory Fallback

- When a project does NOT have a project-level `CLAUDE.md`, check for a `.context/` directory at the project root.
- If `.context/` exists, read its markdown files for project context. Priority order:
  1. `.context/README.md` — understand the context structure
  2. `.context/project/` — project overview, architecture, tech stack
  3. `.context/development/` — conventions, code style, guidelines
- Read these files at the start of a session before doing any work, as they serve the same purpose as `CLAUDE.md` for providing project-specific instructions and context.

## Infrastructure Reference

- For all infrastructure-related work (NAS, Proxmox, VMs, networking, Docker services, SSL, monitoring, Mac minis, etc.), refer to the **`~/git/nas-ops`** repository.
- That repo contains `CLAUDE.md`, `AGENTS.md`, and a `docs/knowledge-graph/` directory with comprehensive modular documentation covering:
  - Network topology, VM specs, service catalog
  - SSH access, security rules, trust boundaries
  - Grafana/Prometheus monitoring
  - SSL/TLS certificates, NGINX configuration
  - ZFS/NFS storage, hardware sensors, UPS
  - Mac mini #0 (172.30.61.1) and Mac mini #1 (172.30.62.1) setup
- When working on infra tasks outside that repo, read `~/git/nas-ops/CLAUDE.md` first for context.
