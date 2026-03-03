# Codex global rules

* Always require explicit approval from user for destructive actions.
* If the project has no `AGENTS.md` or `CLAUDE.md` in the project root, read all documents in `./.context/` directory (starting with `./.context/README.md` if it exists) to understand project context, conventions, and plans before starting work.

## Always Use Latest Versions (CRITICAL)

Before starting any project or adding dependencies, **always search for and use the latest stable versions** of all languages, frameworks, libraries, and tools.

* **Node.js**: Always use the latest LTS release. Currently Node.js 24 LTS (e.g., v24.13.x). When a new LTS becomes available, switch to it.
* **Next.js**: Always use the latest stable major version. Currently Next.js 16 (e.g., v16.1.x+).
* **React**: Always use the latest stable version. Currently React 19.
* **TypeScript**: Always use the latest stable version. Use `"target": "ESNext"` and `"module": "ESNext"` in tsconfig.
* **Rust**: Always use the latest stable toolchain and the Rust 2024 edition (`edition = "2024"` in Cargo.toml). Currently Rust 1.93.x.
* **Python**: Always use the latest stable version. Currently Python >= 3.14. Always use `uv` for environment management.
* **ESNext**: Always target ESNext for JavaScript/TypeScript compilation and module resolution.
* **All other packages/libraries**: Always check for and use the latest stable version before installing or adding as a dependency. Never pin to outdated versions without explicit justification.

**Before writing any `package.json`, `Cargo.toml`, `pyproject.toml`, or similar**: search the web or check package registries to confirm the latest stable versions.

## Git Workflow Rules

* ALWAYS GPG sign all git commits using the `-S` flag (e.g., `git commit -S -m "message"`).
* Commit in a fine-grained way: create one commit per single feature, fix, or enhancement. Do not bundle unrelated changes into a single commit.
* ALWAYS commit and push immediately after every iteration, enhancement, or fix. Do not batch changes.
* ALWAYS use **semantic commit messages** with Conventional Commits format: `<type>(<scope>): <gitmoji> <description>`.
  * Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
  * Scope is optional but encouraged.
  * Use imperative mood, keep header under 72 characters.
* ALWAYS use **gitmoji** in commit messages. Place the gitmoji emoji after the colon and space.
  * Examples: `feat(auth): ✨ add OAuth2 login flow`, `fix(api): 🐛 resolve null pointer`, `docs: 📝 update instructions`
  * Common gitmoji: ✨ (new feature), 🐛 (bug fix), 📝 (docs), ♻️ (refactor), ⚡ (performance), ✅ (tests), 🔧 (config), ⬆️ (upgrade deps), 🔒 (security), 🎨 (style/format), 🚀 (deploy), 🔥 (remove code/files), 🚚 (move/rename), ➕ (add dep), ➖ (remove dep), 🙈 (gitignore)
