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

## Orchestrator behavior (you, in the main session)

You are the orchestrator. Do exactly this, nothing more:

1. Parse `N` from args (default 100, clamp 1–100).
2. Announce: `Starting review-plan-fix loop, up to N=<N> cycles. Each cycle runs in a fresh subagent.`
3. For `i` from `1` to `N`:
   a. Spawn a subagent via the `Agent` tool with `subagent_type: "general-purpose"` and the exact prompt template in **Subagent prompt** below (with `<i>` and `<N>` substituted).
   b. Wait for the subagent to return.
   c. Parse the END OF CYCLE REPORT and print a compact per-cycle report back to the user in THIS exact shape (one message, no extra commentary):

      ```
      Cycle <i>/<N> — <SUMMARY from report>
        findings: <NEW_FINDINGS>   plans: <NEW_PLANS>   commits: <COMMITS>   errors: <ERRORS>
        changes this cycle:
          • <CHANGES bullet 1>
          • <CHANGES bullet 2>
          • ...
      ```
      If `CHANGES` is empty or "(no changes this cycle)", print `  (no changes this cycle)` under `changes this cycle:`.
   d. Evaluate **Stop conditions** below. If any fires, break.
4. After the loop ends (either `i == N` or a stop condition), print a final summary: cycles run, cycles that made commits, cycles that hit errors.

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

=========================
END OF CYCLE REPORT
=========================
When all three prompts are fully complete, reply with ONLY these fields on
separate lines, nothing else:

CYCLE: <i>/<N>
NEW_FINDINGS: <integer, review findings produced this cycle>
NEW_PLANS: <integer, plan docs created or materially updated this cycle>
COMMITS: <integer, git commits pushed this cycle>
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

## Invocation examples

```
/review-plan-fix           # runs up to 100 cycles
/review-plan-fix 10        # runs up to 10 cycles
/review-plan-fix 1         # runs a single cycle (useful for testing)
```
