# Global Rules

## Destructive Action Safety (CRITICAL)

- Before performing any destructive action, always stop and explicitly ask for user confirmation.
- Destructive actions include but are not limited to:
  - Filesystem: deleting files/directories (`rm`, `rmdir`), formatting/partitioning disks, overwriting files with unrelated content
  - Services: removing/disabling interfaces, endpoints, or configs; stopping/killing running services/processes
  - Database: dropping tables, truncating data, deleting records, destructive schema changes
  - Git: force-push, `reset --hard`, rebasing published branches, deleting branches, discarding uncommitted changes
  - DNS and networking: modifying DNS records, IP/routing, firewall rules, or security groups
  - Authentication and access: revoking/rotating keys or certs, changing SSH keys, changing permissions/access controls, disabling auth
  - Docker and containers: removing containers/volumes/images/networks, `docker system prune`, destroying persistent volumes
  - Deployment and production: deploying/modifying production, changing CI/CD, publishing packages
  - Secrets and credentials: using plaintext secrets from chat without rotation warning, writing secrets to unencrypted files/logs
  - External communications: sending email/Slack/notifications to third parties, creating/commenting public issues/PRs
  - System: removing packages/dependencies/system components, modifying boot/system configs, changing cron/scheduled jobs
  - Audit and logs: truncating/deleting logs, audit trails, monitoring data
  - Encryption: changing/deleting encryption keys/certificates/secure storage
- This rule applies even when the broader task is requested; always confirm before the specific destructive step.
- Never assume destructive intent. When in doubt, ask.

## Always Use Latest Versions (CRITICAL)

Before starting any project or adding dependencies, always search for and use the latest stable versions of languages, frameworks, libraries, and tools.

- Node.js: latest LTS (currently Node.js 24 LTS, e.g. v24.13.x)
- Next.js: latest stable major (currently Next.js 16)
- React: latest stable (currently React 19)
- TypeScript: latest stable; use `"target": "ESNext"` and `"module": "ESNext"`
- Rust: latest stable toolchain, Rust 2024 edition (`edition = "2024"`)
- Python: latest stable (currently >= 3.14), use `uv` for environment management
- JavaScript/TypeScript: target ESNext
- All other dependencies: check registries/docs and use latest stable unless explicit justification exists

Before writing `package.json`, `Cargo.toml`, `pyproject.toml`, or equivalent: verify latest stable versions from official registries/docs.

## Git Commit Rules

- Always GPG-sign commits with `-S`.
- Always commit and push in a fine-grained way for every iteration and every enhancement/fix; keep one feature/fix/enhancement per commit.
- Do not batch unrelated work into the same commit.
- Use Conventional Commits format: `<type>(<scope>): <gitmoji> <description>`.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
  - Scope optional but encouraged
  - Use imperative mood and keep header under 72 characters
  - Always include a gitmoji in the subject (for example: `feat(core): ✨ add auth guard`)
- Never add `Co-authored-by` trailers or any other co-author attribution when writing commit messages.

## Context Directory Fallback

- If a project does not have a project-level `AGENTS.md` or `CLAUDE.md`, check for a `.context/` directory at project root.
- If `.context/` exists, read markdown files in this order:
  1. `.context/README.md`
  2. `.context/project/`
  3. `.context/development/`

## OpenCode Usage Sync (CRITICAL)

- Before ending an OpenCode work session, always run usage catch-up once to send unsent OpenCode/Claude usage records.
- Use this exact command:
  - `CLAUDE_PLUGIN_ROOT="$(node -e "const {existsSync,readdirSync,readFileSync}=require('fs'); const {homedir}=require('os'); const {basename,join}=require('path'); const key='ccusage-worv@worv'; const isPluginRoot=(candidate)=>typeof candidate==='string'&&existsSync(join(candidate,'scripts','catchup.mjs')); const compare=(left,right)=>left.localeCompare(right,undefined,{numeric:true,sensitivity:'base'}); const getInstalled=()=>{ const file=join(homedir(),'.claude','plugins','installed_plugins.json'); if(!existsSync(file)) return []; try { const data=JSON.parse(readFileSync(file,'utf8')); const entries=data?.plugins?.[key]; return Array.isArray(entries) ? entries.map((entry)=>entry?.installPath).filter(isPluginRoot).sort((left,right)=>compare(basename(right),basename(left))) : []; } catch { return []; } }; const getVersioned=(dir)=>existsSync(dir) ? readdirSync(dir,{withFileTypes:true}).filter((entry)=>entry.isDirectory()).map((entry)=>join(dir,entry.name)).filter(isPluginRoot).sort((left,right)=>compare(basename(right),basename(left))) : []; const candidates=[...getInstalled(),...getVersioned(join(homedir(),'.claude','plugins','cache','worv','ccusage-worv')),...getVersioned(join(homedir(),'.claude','plugins','ccusage-worv'))]; const resolved=[...new Set(candidates)][0]; if(!resolved) process.exit(1); process.stdout.write(resolved);")"; node "${CLAUDE_PLUGIN_ROOT}/scripts/catchup.mjs"`
- If the command reports sent sessions, include the result in the final response.
