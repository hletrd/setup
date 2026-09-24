# Global Rules

## Verify, don't recall
- For anything that changes over time (versions, APIs, CLI flags, config options, deprecations), look it up first in the official docs or with a web search. Use a docs skill or MCP server if one is available.
- Never answer "I don't know" or "not possible" without trying to look it up.

## Latest versions
- Check registries for the latest stable version before adding a dependency, and never pin old versions without a reason.
- Baselines (checked 2026-09-24): Node.js latest LTS (24 now, 26 from 2026-10-28), Next.js 16, React 19, TypeScript 7.0 (`target`/`module` = `ESNext`), Rust latest stable (1.98) with edition 2024, Python ≥ 3.14 managed with `uv` (3.15 is due 2026-10-01).

## Git
- Commit messages: `<type>(<scope>): <gitmoji> <description>` (Conventional Commits), imperative mood, header under 72 characters.
  Example: `fix(api): 🐛 handle null response`.
- Always sign commits (`git commit -S`). Never add `Co-Authored-By` or any AI attribution.
- One commit per change. Commit and push right after each change, with `git pull --rebase` before `git push`.

## Project context
- If a project has no `CLAUDE.md`, read `.context/` (`README.md`, then `project/`, then `development/`) before working.

## Infrastructure
- Infrastructure work (NAS, Proxmox, VMs, network, Docker, TLS, monitoring, Macs) follows the `nas-ops` repo (`CLAUDE.md` and `docs/knowledge-graph/`).
- SSH: `mac0` (172.30.61.1), `mac1` (172.30.62.1), `mac3` (Tailscale 100.115.57.92), `m5` (Tailscale 100.119.186.85). User `hletrd`, key `~/.ssh/hletrd-mac`.
