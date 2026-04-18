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
   c. Print one short status line: `Cycle <i>/<N> complete — <subagent's one-line summary>`.
   d. Evaluate **Stop conditions** below. If any fires, break.
4. After the loop ends (either `i == N` or a stop condition), print a final summary: cycles run, cycles that made commits, cycles that hit errors.

Do not perform the three prompts yourself in the main session. The whole point
of this skill is that each cycle runs in a fresh context. Your job is only to
loop and to spawn subagents.

Do not parallelize cycles. Each cycle must finish before the next begins.

Use `TaskCreate` / `TaskUpdate` to track cycle progress visibly. One task per
cycle is fine.

## Stop conditions

Break the loop early and report when any of these hold:

- Reached `N`.
- The user interrupts or tells you to stop.
- The subagent reports a hard error it could not recover from (push rejected
  after retry, GPG signing unavailable, missing credentials, etc.).
- Two consecutive cycles returned `no new findings AND no new plans AND no
  commits`. This means the repository has stabilized — further cycles would
  be wasted work.

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
PROMPT 1 — DEEP CODE REVIEW
=========================
Perform a comprehensive, deep code review of this repository. Your goal is to find as many real issues as possible without missing relevant files or important cross-file interactions. Be thorough, skeptical, and critical. Do not optimize for speed.
Requirements
- Review the entire repository and all relevant documentation.
- First build an inventory of review-relevant files, then make sure every relevant file is examined.
- Do not sample only a subset of files or stop after the first few findings.
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
- Do not assume tests or comments are correct. Validate behavior from the code.
- For each finding, cite the exact file and code region, explain why it is a problem, describe a concrete failure scenario, and suggest a fix.
- Clearly label confidence as High, Medium, or Low.
- Distinguish between confirmed issues, likely issues, and risks needing manual validation.
- After the main review, do one final sweep specifically for commonly missed issues and to confirm no relevant file was skipped.
Write the review to:
./.context/reviews
Do not finish until the review is comprehensive and the final review has been written to ./.context/reviews

=========================
PROMPT 2 — PLAN FROM REVIEWS
=========================
Please read all reviews and find any missing tasks to do, write plan under plan directory. Please write implementation plans to address critics in each reviews. Please do not implement yet. Archive plans which are fully implemented and done.

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
```

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
