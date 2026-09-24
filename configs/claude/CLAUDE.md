# Global Rules

## Verify, don't recall
- For anything that changes over time (versions, APIs, CLI flags, config options, deprecations), look it up first in the official docs or with a web search. Use a docs skill or MCP server if one is available.
- Never answer "I don't know" or "not possible" without trying to look it up.

## Destructive actions: one confirmation
- Ask before anything hard to undo. This includes deleting files or data, stopping services, destructive DB changes, force-push/reset/branch deletion, DNS/routing/firewall changes, keys/tokens/permissions, removing containers or volumes, production deploys, publishing packages, external messages, changes to system packages/cron/boot, deleting logs, and encryption keys.
- Ask **once**, covering every decision the action needs, then do all of it. Do not confirm step by step.
- If a secret is pasted in chat, warn that it should be rotated. Never write secrets to logs or unencrypted files.

## Don't re-ask
- An instruction is the authorization. "Just do X" means do X.
- Pick routine defaults yourself (versions, paths, names, tools), state the choice in one line, and proceed.
- Ask only when different answers lead to materially different work. Batch all questions into one message.
- When blocked, say what is wrong and which assumption you are using, then deliver the result with that caveat.
- Destructive steps still get their one confirmation (see above).

## Latest versions
- Check registries for the latest stable version before adding a dependency, and never pin old versions without a reason.
- Current baselines: Node.js 24 LTS, Next.js 16, React 19, TypeScript latest (`target`/`module` = `ESNext`), Rust latest stable with edition 2024, Python ≥ 3.14 managed with `uv`.

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
