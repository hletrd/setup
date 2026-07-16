---
name: review-plan-fix
version: 1.0.0
description: |
  Iteratively review the current repository, plan fixes from the reviews, and
  implement the plans. Runs three prompts in strict order
  (deep review → plan from reviews → implement with ralph) and repeats the
  full three-prompt cycle up to N times (default 100). Context is cleaned
  between iterations by spawning each full cycle in a fresh subagent.
---

# review-plan-fix — repeat 3 prompts, cleaned context between cycles

Run three fixed prompts, in order, as one cycle. Repeat the full cycle up
to `N` times (default `100`). Each cycle runs in a fresh subagent so its
context is isolated from previous cycles.

## Parameters

- `N` — optional positive integer from the user's invocation args.
  - If the user typed e.g. `/review-plan-fix 25`, set `N = 25`.
  - If no integer is given, set `N = 100`.
  - Clamp: `1 ≤ N ≤ 100`. Reject anything else and ask the user.

## Pre-loop setup (ONCE, before cycle 1)

Before spawning any cycle, the orchestrator must do a one-time setup pass in
the main session. The results drive every subsequent cycle and the optional
end-only deploy pass.

### 1. Detect deployment targets

Enumerate deployment targets present in the repo. Consider all of:

- Container / build: `Dockerfile`, `docker-compose.yml`, `docker-bake.hcl`
- Orchestrators: `k8s/**`, `**/charts/**`, `helmfile.yaml`, `skaffold.yaml`, `kustomization.yaml`
- PaaS: `fly.toml`, `render.yaml`, `railway.json`, `vercel.json`, `netlify.toml`, `Procfile`, `app.yaml`, `app.json`
- Serverless / IaC: `serverless.yml`, `sam.yaml`, `samconfig.toml`, `template.yaml`, `cdk.json`, `terraform/**`, `*.tf`, `pulumi/**`
- CI-as-deploy: `.github/workflows/deploy*.{yml,yaml}`, `.gitlab-ci.yml` deploy stages, `.circleci/config.yml` deploy jobs, `.buildkite/**` deploy steps
- Scripts: `package.json` scripts matching `deploy|release|publish|ship`, `Makefile` targets matching `deploy|release|publish|ship`, top-level `deploy.sh` / `release.sh` / `publish.sh`
- Registries / publishing: `pyproject.toml` publish config, `Cargo.toml` crate publish config (for library repos), `.npmignore` + `"private": false` in `package.json`

Record the set of detected targets. If the set is empty, set
`DEPLOY_MODE = none`, `DEPLOY_CMD = ""` silently and skip section 2.

### 2. Ask the user which deployment mode and command to use (only if targets were detected)

If at least one deployment target was detected, the orchestrator MUST call
`AskUserQuestion` **once** — before cycle 1 — presenting the detected
targets and these three options (single-select):

1. **Every iteration** — deploy after every cycle that produced commits and has all quality gates green. Map to `DEPLOY_MODE = per-cycle`.
2. **After all iterations finish (recommended)** — skip deploy mid-loop; the orchestrator runs one deploy pass after the final cycle iff any cycle committed. Map to `DEPLOY_MODE = end-only`.
3. **Do not deploy** — never run deploy during this invocation. Map to `DEPLOY_MODE = none`.

If the user picks `per-cycle` or `end-only`, immediately ask a second
`AskUserQuestion` showing the detected targets as options (plus an
"Other" escape hatch) to pin down the exact `DEPLOY_CMD` string that
should run. Store it. Do NOT ask this second question if the user picked
`none` or if no targets were detected.

Announce the chosen `DEPLOY_MODE` and `DEPLOY_CMD` to the user before
starting cycle 1.

### 3. Detect quality-gate tooling

Enumerate repo-configured quality gates (informational — every cycle then
runs them):

- Linters / formatters: `eslint`, `biome`, `prettier`, `ruff`, `black`, `mypy`, `pyright`, `clippy`, `shellcheck`, `shfmt`, `golangci-lint`, `stylelint`, `rubocop`, `credo`, etc. Detect via config files and `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod`.
- Build / compile: `npm build`, `pnpm build`, `cargo build`, `go build`, `tsc --noEmit`, `make`, `gradle`, `mvn`, `poetry build`, `uv build`, `xcodebuild`, `swift build`, `zig build`, any `CMakeLists.txt` / `Makefile` implying a build.
- Tests: `npm test`, `pnpm test`, `cargo test`, `go test`, `pytest`, `jest`, `vitest`, `playwright`, `rspec`, `go vet`, `detekt`, etc.

Store the resulting list as `GATES`. Announce the detected gates to the
user. Even if some tools are missing, PROMPT 3 must still run and pass
every gate that IS configured in the repo.

## Orchestrator behavior (you, in the main session)

You are the orchestrator. Do exactly this, nothing more:

1. Parse `N` from args (default 100, clamp 1–100).
2. Run **Pre-loop setup** above: detect deployment targets, resolve
   `DEPLOY_MODE` (ask the user if any targets detected, else `none`),
   resolve `DEPLOY_CMD` when applicable, detect `GATES`.
3. Announce: `Starting review-plan-fix loop, up to N=<N> cycles. Each cycle runs in a fresh subagent. deploy=<DEPLOY_MODE> cmd=<DEPLOY_CMD or "-"> gates=<GATES summary>.`
4. For `i` from `1` to `N`:
   a. Spawn a subagent via the `Agent` tool with `subagent_type: "general-purpose"` and the exact prompt template in **Subagent prompt** below (with `<i>`, `<N>`, `<DEPLOY_MODE>`, `<DEPLOY_CMD>`, and `<GATES>` substituted).
   b. Wait for the subagent to return.
   c. Parse the END OF CYCLE REPORT and print a compact per-cycle report back to the user in THIS exact shape (one message, no extra commentary):

      ```
      Cycle <i>/<N> — <SUMMARY from report>
        findings: <NEW_FINDINGS>   plans: <NEW_PLANS>   commits: <COMMITS>   errors: <ERRORS>
        gate-fixes: <GATE_FIXES>   deploy: <DEPLOY>
        changes this cycle:
          • <CHANGES bullet 1>
          • <CHANGES bullet 2>
          • ...
      ```
      If `CHANGES` is empty or "(no changes this cycle)", print `  (no changes this cycle)` under `changes this cycle:`.
   d. Evaluate **Stop conditions** below. If any fires, break.
5. After the loop ends (either `i == N` or a stop condition), print a final summary: cycles run, cycles that made commits, cycles that hit errors, total gate-fixes.
6. **End-only deploy pass.** If `DEPLOY_MODE == "end-only"` AND at least
   one cycle reported `COMMITS > 0`, spawn one final subagent with the
   verbatim prompt in **End-only deploy subagent prompt** below. Wait for
   it to return; print its `DEPLOY:` result line. If the deploy fails and
   cannot be recovered, surface the error to the user rather than
   silently swallowing it. If no cycle committed, skip this step and
   announce `deploy skipped (no commits this run)`.

Do not perform the three prompts yourself in the main session. The whole point
of this skill is that each cycle runs in a fresh context. Your job is only to
loop and to spawn subagents.

Do not parallelize cycles. Each cycle must finish before the next begins.

Use `TaskCreate` / `TaskUpdate` to track cycle progress visibly. One task per
cycle is fine.

## Handling new TODOs injected mid-run

The user may send additional instructions, TODOs, or fix requests WHILE the
loop is running. Handle them like this:

1. **Never drop a user-injected TODO.** Capture it via `TaskCreate`
   immediately (with the user's wording) so it cannot be forgotten across
   cycle boundaries.
2. **Route by timing:**
   - If PROMPT 3 (implement-with-ralph) of the current cycle has NOT yet
     started, pass the new TODO into the current cycle by appending it to
     the plan directory as an explicit "user-injected TODO" plan entry
     before PROMPT 2 finalizes. The current cycle will then pick it up in
     PROMPT 3.
   - If PROMPT 3 of the current cycle is already running, do NOT interrupt
     it. Queue the TODO for the NEXT cycle by recording it in the plan
     directory under `user-injected/pending-next-cycle.md` (create if
     missing), and make sure the next cycle's PROMPT 2 ingests that file
     alongside the reviews.
   - If the current cycle has already finished and the next one has not yet
     spawned, inject it into the next cycle's PROMPT 2 input the same way.
3. **Propagate to the subagent prompt.** When spawning the next cycle,
   append a short "User-injected TODOs to honor this cycle" block to the
   subagent prompt listing the queued items verbatim, with instruction that
   PROMPT 2 must turn them into plan entries and PROMPT 3 must implement
   them alongside the normal plan work.
4. **Still obey the deferred-fix rules above.** A user-injected TODO may be
   deferred only under the same strict rules (explicit record, repo rules
   honored, severity preserved).
5. **Do not let injected TODOs skip review.** They still flow through the
   plan step so the repo has a durable record; they do not bypass PROMPT 2
   into PROMPT 3 directly.

## Stop conditions

Break the loop early and report when any of these hold:

- Reached `N`.
- The user interrupts or tells you to stop.
- The subagent reports a hard error it could not recover from (push rejected
  after retry, GPG signing unavailable, missing credentials, etc.).
- `DEPLOY_MODE == "per-cycle"` and the cycle reported `DEPLOY: per-cycle-failed:*`
  (the deploy pass ran and failed non-recoverably). Stop and surface the
  failure rather than cycling on a known-broken deploy.
- **Convergence (strict, single-cycle):** the cycle returned
  `NEW_FINDINGS == 0 AND COMMITS == 0`. That is, the review produced no new
  items AND the fix step made no changes. This means the repository has
  stabilized — stop immediately. Do not wait for a second confirming cycle.
  - `NEW_PLANS` is ignored for this check: plan docs can be re-touched
    cosmetically without representing real new work.
  - If the END OF CYCLE REPORT is malformed so these counts cannot be parsed,
    do not treat it as convergence. Keep going unless the malformed report
    recurs (then stop on the `ERRORS` clause above).

## Repo-wide rules for deferred fixes (STRICT)

Findings that the plan step chooses NOT to implement this cycle ("deferred",
"won't fix", "out of scope", "follow-up", "wontfix", "later") MUST strictly
follow the repository's own rules. This applies to every cycle, and the
orchestrator must reinforce it in the subagent prompt (see PROMPT 2 below).

Mandatory rules for deferred items:

1. **Obey repo instructions first.** Read and follow, in this precedence:
   `CLAUDE.md`, `AGENTS.md`, `.context/**`, `.cursorrules`, `CONTRIBUTING.md`,
   and any `docs/` style/policy files that exist in the repo. Repo rules
   override this skill's defaults.
2. **No silent drops.** A finding may only be deferred if it is explicitly
   recorded in the plan directory with: file+line citation, the original
   severity/confidence, the concrete reason for deferral, and the exit
   criterion that would re-open it. A finding that is not fixed and not
   recorded is a bug — fail the cycle.
3. **Do not downgrade severity to justify deferral.** High/Medium findings
   stay High/Medium in the deferred record. The reason for deferral is
   separate from the severity.
4. **Security, correctness, and data-loss findings are not deferrable** by
   default. They may only be deferred if the repo's own rules explicitly
   permit it, and the deferral record must quote the specific repo rule that
   allows it.
5. **Deferral must not violate repo policy.** If repo rules require e.g.
   GPG-signed commits, conventional commit messages, no `--no-verify`, no
   force-push to protected branches, specific file-layout, specific language
   versions, etc., deferred work is still bound by those rules when it is
   eventually picked up. The deferral note must not contradict them.
6. **No new scope under the "deferred" label.** Deferral is for existing
   findings only. New refactors, rewrites, or feature ideas do not belong in
   the deferred list — they belong in their own plan, or nowhere.

If any of these rules is violated, the orchestrator treats the cycle as
`ERRORS != none` for stop-condition purposes.

## Subagent prompt (run per cycle, verbatim structure)

When spawning a cycle, pass this prompt to the subagent. Keep the three
internal prompts verbatim — do not paraphrase or shorten them.

```
You are cycle <i> of <N> in the review-plan-fix loop running in repo:
  <absolute path to current working directory>

RUN CONTEXT (set by the orchestrator, read-only for this cycle):
  DEPLOY_MODE: <DEPLOY_MODE>   # one of: per-cycle | end-only | none
  DEPLOY_CMD:  <DEPLOY_CMD>    # exact shell command chosen for deploy, or "" if unused this cycle
  GATES:       <GATES>         # comma-separated list, e.g. "eslint, tsc --noEmit, vitest"

Execute the following three prompts, strictly in order. Wait for each to fully
finish before starting the next. Do not merge them. Do not skip any. Treat
each prompt as authoritative for its own step.

=========================
PROMPT 1 — DEEP CODE REVIEW (MULTI-AGENT FAN-OUT)
=========================
Perform a comprehensive, deep code review of this repository. Your goal is to find as many real issues as possible without missing relevant files or important cross-file interactions. Be thorough, skeptical, and critical. Do not optimize for speed.

Fan out the review across ALL available review agents in a single batch of parallel Agent tool calls. At minimum, spawn these subagents concurrently (skip any that are not registered in this environment, but never silently drop one that IS available):
- code-reviewer (code quality, logic, SOLID, maintainability)
- perf-reviewer (performance, concurrency, CPU/memory/UI responsiveness)
- security-reviewer (OWASP top 10, secrets, unsafe patterns, auth/authz)
- critic (multi-perspective critique of the whole change surface)
- verifier (evidence-based correctness check against stated behavior)
- test-engineer (test coverage gaps, flaky tests, TDD opportunities)
- tracer (causal tracing of suspicious flows, competing hypotheses)
- architect (architectural/design risks, coupling, layering)
- debugger (latent bug surface, failure modes, regressions)
- document-specialist (doc/code mismatches against authoritative sources)
- designer (UI/UX review — ONLY if the repo actually contains UI/UX: web frontend, mobile UI, desktop UI, CLI UX, design tokens, CSS, component libraries, design-system docs. Skip entirely for pure-backend/infra/library repos.)
- any other reviewer-style agent registered for this repo (e.g. project-specific linters, kf-reviewer, custom `.claude/agents/*-reviewer*`). Enumerate available agents before fan-out and include every reviewer you find.

UI/UX review specifics:
- Detect UI/UX presence by scanning for web assets (HTML/CSS/JSX/TSX/Vue/Svelte, `public/`, `static/`, common frontend framework markers), mobile UI (SwiftUI/UIKit, Jetpack Compose, Flutter), desktop UI toolkits, CLI UX code, or design-system docs. Skip the UI/UX reviewer if none are present.
- For web projects, the designer agent MUST use the `agent-browser` skills (core, interact, query, wait, network, visual, debug, state, config) to actually load the app and interact with it when feasible. Start a local dev server or use an existing build per the repo's README/CONTRIBUTING.
- Multimodal caveat: some models cannot see images. When the review model is not multimodal, DO NOT rely on raw screenshots. Instead use `agent-browser-query` for accessibility snapshots, DOM structure, computed styles, element state, and ARIA roles; use `agent-browser-visual` accessibility-snapshot diffs and structural comparisons; and describe visual findings textually with precise selectors, colors (hex), box metrics, and z-order. Screenshots MAY be captured as attachments for the human reader even when the model cannot inspect them, but all findings must be backed by text-extractable evidence.
- Cover: information architecture, affordances, focus/keyboard navigation, WCAG 2.2 accessibility (contrast, ARIA, focus traps, reduced motion), responsive breakpoints, loading/empty/error states, form validation UX, dark/light mode, i18n/RTL, and perceived performance (LCP, CLS, INP).

Each spawned subagent must:
- Review the entire repository and all relevant documentation from its own specialist angle.
- First build an inventory of review-relevant files, then make sure every relevant file is examined.
- Not sample only a subset of files or stop after the first few findings.
- Analyze both individual files and how they interact across the system.
- Pay close attention to correctness, edge cases, failure modes, and maintainability risks.
- Look systematically for common issue types such as:
  - logic bugs
  - missed edge cases
  - race conditions and shared-state hazards
  - error-handling problems
  - invalid assumptions and invariant violations
  - data-flow or state-consistency issues
  - security weaknesses
  - performance problems
  - test gaps
  - documentation-code mismatches
- Not assume tests or comments are correct. Validate behavior from the code.
- For each finding, cite the exact file and code region, explain why it is a problem, describe a concrete failure scenario, and suggest a fix.
- Clearly label confidence as High, Medium, or Low.
- Distinguish between confirmed issues, likely issues, and risks needing manual validation.
- After the main review, do one final sweep specifically for commonly missed issues and to confirm no relevant file was skipped.
- Write its own review to `./.context/reviews/<agent-name>.md` (one file per agent).

After every fanned-out review returns, do a final aggregation pass yourself: dedupe overlapping findings across agents, preserving the highest severity/confidence of any duplicate; note cross-agent agreement (a finding flagged by multiple agents is higher signal); and write the merged result to `./.context/reviews/_aggregate.md`. Keep the per-agent files as-is for provenance.

Do not finish PROMPT 1 until every available review agent has returned AND the aggregate has been written to `./.context/reviews/_aggregate.md`. If a spawned agent fails, retry once; if it still fails, record the failure in the aggregate under an `AGENT FAILURES` section and continue.

=========================
PROMPT 2 — PLAN FROM REVIEWS
=========================
Please read all reviews and find any missing tasks to do, write plan under plan directory. Please write implementation plans to address critics in each reviews. Please do not implement yet. Archive plans which are fully implemented and done.

Deferred-fix rules (STRICT — must be obeyed):
- Every finding from the reviews must be either (a) scheduled for implementation in a plan, or (b) explicitly recorded in the plan directory as a deferred item. No finding may be silently dropped.
- Before deferring anything, read the repo's own rules in this order and strictly follow them: CLAUDE.md, AGENTS.md, .context/**, .cursorrules, CONTRIBUTING.md, and docs/ style/policy files. Repo rules override any default behavior.
- Each deferred finding must record: file+line citation, original severity/confidence (do NOT downgrade to justify deferral), concrete reason for deferral, and the exit criterion that would re-open it.
- Security, correctness, and data-loss findings are NOT deferrable unless the repo's own rules explicitly allow it; if deferred, quote the specific repo rule that permits it.
- Deferred work remains bound by repo policy when it is eventually picked up (e.g. GPG-signed commits, conventional commit + gitmoji, no `--no-verify`, no force-push to protected branches, required language/toolchain versions). The deferral note must not contradict those rules.
- The "deferred" list is only for existing review findings. Do not introduce new refactors, rewrites, or feature ideas under the "deferred" label.

=========================
PROMPT 3 — IMPLEMENT WITH RALPH
=========================
Please work with all new plans. Fix every issues mentioned in each plan. Please update the progress in plan documents. Always commit and push, in fine grained way for every iteration and every enhancement of fixes. Always use semantic git messages, and gitmoji for commit. Always properly GPG sign the commits. Use ralph skill to complete your work.

QUALITY-GATE FIX REQUIREMENT (must be honored alongside the plan work):
- As part of this cycle's work, run every gate listed in `GATES` above (linters, formatters, type checkers, compilers, builds, tests). Run them against the whole repo, not just the files you touched.
- Errors are blocking. All lint errors, type errors, build/compile errors, and test failures must be fixed before you commit+push. No suppressions (`eslint-disable`, `#[allow(...)]`, `# type: ignore`, `--skip`, pytest `xfail` on a passing assertion, `@ts-ignore`, etc.) unless the repo's own rules (CLAUDE.md / AGENTS.md / CONTRIBUTING.md / .context/**) explicitly authorize that suppression — if so, quote the rule in the commit body.
- Warnings are best-effort. Prefer fixing lint warnings, compiler warnings, deprecation warnings, and test warnings. If a warning cannot be fixed cleanly in this cycle (genuine tradeoff, out of scope, repo-policy exception), record it in the plan directory as a deferred finding under the skill's existing deferred-fix rules (severity preserved, exit criterion stated). Do NOT silently ignore warnings.
- Root-cause, don't mask. Fix the underlying issue rather than rewriting the test, lowering the lint threshold, or widening a type to `any`. If a gate is genuinely broken (false positive), fix the gate config in the same commit and explain why in the message body.
- Track gate work in `GATE_FIXES` for the report (count of error-level gate issues fixed + warnings fixed this cycle).

DEPLOYMENT BEHAVIOR (driven by DEPLOY_MODE):
- If `DEPLOY_MODE == "per-cycle"`: after all plan work is committed+pushed AND every configured gate is green, run the exact `DEPLOY_CMD` once. If it succeeds, record `DEPLOY: per-cycle-success`. If it fails, attempt one reasonable recovery (e.g. re-run idempotent commands, pull+rebase, re-auth if the tool asks interactively — but do not bypass destructive-action rules). If still failing, record `DEPLOY: per-cycle-failed:<short reason>` and stop further deploy attempts this cycle. Do not revert commits just because deploy failed.
- If `DEPLOY_MODE == "end-only"`: do NOT deploy this cycle. Record `DEPLOY: end-only-deferred`.
- If `DEPLOY_MODE == "none"`: do NOT deploy this cycle. Record `DEPLOY: none`.

=========================
END OF CYCLE REPORT
=========================
When all three prompts are fully complete, reply with ONLY these fields on
separate lines, nothing else:

CYCLE: <i>/<N>
NEW_FINDINGS: <integer, review findings produced this cycle>
NEW_PLANS: <integer, plan docs created or materially updated this cycle>
COMMITS: <integer, git commits pushed this cycle>
GATE_FIXES: <integer, lint/build/compile/test issues fixed this cycle — errors + warnings>
DEPLOY: <one of: per-cycle-success | per-cycle-failed:<reason> | end-only-deferred | none>
ERRORS: <short string, or "none">
SUMMARY: <one sentence>
CHANGES:
- <one-line description of enhancement/fix/change #1 — include file path and the kind of change: feat/fix/perf/refactor/test/docs>
- <one-line description of enhancement/fix/change #2>
- <...one bullet per concrete change made this cycle; if zero changes, write "- (no changes this cycle)">
```

The `CHANGES:` block is REQUIRED every cycle, even when `COMMITS: 0`. Each bullet must be user-facing and specific ("fix auth: prevent null deref in src/auth/verify.ts:42" beats "fixed a bug"). Do not include every commit SHA — bundle related commits into one bullet when appropriate. Cap the list at the 10 most significant changes; if there were more, add a final bullet "- plus N more minor fixes (see git log)".

## Notes for the orchestrator

- The subagent has full tool access; let it use whatever it needs (Bash, Edit,
  Write, Grep, Glob, slash commands like `/oh-my-claudecode:ralph`).
- Parse the subagent's END OF CYCLE REPORT to drive the stop conditions. If the
  report is malformed, treat that cycle as `ERRORS != none` for stop-condition
  purposes but keep going unless it recurs twice in a row.
- Never rewrite or shorten the three prompts. They are specified verbatim
  above and must be sent to the subagent exactly as written.
- You are not expected to GPG-sign commits or touch git yourself. Prompt 3
  instructs the subagent to do that.

## End-only deploy subagent prompt

Only used when `DEPLOY_MODE == "end-only"` AND at least one cycle of the
loop reported `COMMITS > 0`. Spawn a single subagent after the loop ends
and pass this prompt verbatim:

```
You are the end-only deploy pass of a review-plan-fix run in repo:
  <absolute path to current working directory>

The loop has finished. At least one cycle committed changes. The user
chose deploy timing = end-only with the exact command:

  DEPLOY_CMD: <DEPLOY_CMD>
  GATES:      <GATES>

Do this, in order:

1. Run every gate in `GATES` one more time against the current HEAD.
   All gates at error-level must be green. If any error-level gate is
   red, STOP and report `DEPLOY: end-only-blocked:<short reason>` —
   do not run the deploy command.
2. If all gates pass, run `DEPLOY_CMD` exactly once. Treat its exit
   status as authoritative. Do not second-guess the repo's deploy
   script.
3. If deploy succeeds, report `DEPLOY: end-only-success`. If deploy
   fails, attempt one reasonable recovery (idempotent re-run, pull +
   rebase, re-auth if the tool asks interactively — obey destructive-
   action rules). If still failing, report
   `DEPLOY: end-only-failed:<short reason>`.
4. Do NOT create new commits, open new plans, or modify source files
   as part of this pass. You are a deploy-only executor.

Reply with ONLY two lines, nothing else:

DEPLOY: <per the four possible values above>
SUMMARY: <one short sentence describing what actually happened>
```

## Invocation examples

```
/review-plan-fix           # runs up to 100 cycles
/review-plan-fix 10        # runs up to 10 cycles
/review-plan-fix 1         # runs a single cycle (useful for testing)
```
