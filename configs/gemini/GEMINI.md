# GEMINI.md - Global Project Guidelines for AI Assistants

## Destructive Action Safety (CRITICAL)

- Before performing ANY destructive action, ALWAYS stop and explicitly ask the user for confirmation first.
- Destructive actions include but are not limited to:
  - **Filesystem**: Deleting files or directories (rm, rmdir, etc.), formatting/partitioning disks, overwriting files with unrelated content
  - **Services**: Removing or disabling existing service interfaces, endpoints, or configurations; stopping or killing running services/processes
  - **Database**: Dropping tables, truncating data, deleting records, modifying schemas destructively
  - **Git**: Force-pushing, resetting (--hard), rebasing published branches, deleting branches, discarding uncommitted changes
  - **DNS & Networking**: Modifying DNS records, changing IP/routing configurations, altering firewall rules or security groups — misconfiguration can cause total service outage or loss of remote access
  - **Authentication & Access**: Revoking or rotating API keys/tokens/certificates, modifying SSH keys, changing user permissions or access controls, disabling authentication mechanisms — can permanently lock out access
  - **Docker & Containers**: Removing containers, volumes, images, or networks; docker system prune; destroying persistent data volumes
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
- **TypeScript**: Always use the latest stable version. Use "target": "ESNext" and "module": "ESNext" in tsconfig.
- **Rust**: Always use the latest stable toolchain and the Rust 2024 edition (edition = "2024" in Cargo.toml). Currently Rust 1.93.x.
- **Python**: Always use the latest stable version. Currently Python >= 3.14. Always use uv for environment management.
- **ESNext**: Always target ESNext for JavaScript/TypeScript compilation and module resolution.
- **All other packages/libraries**: Always check for and use the latest stable version before installing or adding as a dependency. Never pin to outdated versions without explicit justification.

**Before writing any package.json, Cargo.toml, pyproject.toml, or similar**: search the web or check package registries to confirm the latest stable versions. Do not guess or rely on cached knowledge — versions change frequently.

## Git Commit Rules

- Do NOT add Co-Authored-By lines to commit messages. Never attribute Gemini as author or co-author in any commit.
- ALWAYS GPG sign all git commits using the -S flag (e.g., git commit -S -m "message").
- Commit in a fine-grained way: create one commit per single feature, fix, or enhancement. Do not bundle unrelated changes into a single commit.
- ALWAYS commit and push immediately after every iteration, enhancement, or fix. Do not batch changes.
- ALWAYS git pull --rebase before git push. This prevents push rejections due to remote changes. If the pull fails due to conflicts, resolve them before pushing.
- ALWAYS use **semantic commit messages** with [Conventional Commits](https://www.conventionalcommits.org/) format: <type>(<scope>): <gitmoji> <description>.
  - Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
  - Scope is optional but encouraged.
  - Use imperative mood, keep header under 72 characters.
  - Examples: feat(auth): ✨ add OAuth2 login flow, fix(api): 🐛 resolve null pointer in response handler, docs(readme): 📝 update installation instructions
- ALWAYS use gitmoji in commit messages. Place the gitmoji after scope and before description.

## Context Directory Fallback

- When a project does NOT have a project-level GEMINI.md, check for a .context/ directory at the project root.
- If .context/ exists, read its markdown files for project context. Priority order:
  1. .context/README.md — understand the context structure
  2. .context/project/ — project overview, architecture, tech stack
  3. .context/development/ — conventions, code style, guidelines
- Read these files at the start of a session before doing any work, as they serve the same purpose as GEMINI.md for providing project-specific instructions and context.

## Infrastructure Reference

- For all infrastructure-related work (NAS, Proxmox, VMs, networking, Docker services, SSL, monitoring, Mac minis, etc.), refer to the **~/git/nas-ops** repository.
- That repo contains GEMINI.md, AGENTS.md, and a docs/knowledge-graph/ directory with comprehensive modular documentation covering:
  - Network topology, VM specs, service catalog
  - SSH access, security rules, trust boundaries
  - Grafana/Prometheus monitoring
  - SSL/TLS certificates, NGINX configuration
  - ZFS/NFS storage, hardware sensors, UPS
  - Mac mini #0 (172.30.61.1) and Mac mini #1 (172.30.62.1) setup
- When working on infra tasks outside that repo, read ~/git/nas-ops/GEMINI.md first for context.
