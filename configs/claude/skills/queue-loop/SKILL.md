---
name: queue-loop
description: |
  Run forever as a resident worker in ONE Codex turn: every 5 minutes poll a
  watched directory for new task files and execute each one to completion,
  then keep watching — the turn never ends. Use when the user says
  "queue-loop", "무한 루프로 돌려", "큐 감시해서 계속 실행", "resident worker",
  "watch a directory and run new tasks forever", or wants a single invocation
  that keeps picking up dropped commands indefinitely. Because the work stays
  inside one already-running turn, it keeps issuing model requests across
  usage-limit windows (the workspace spend cap gates only NEW top-level turns,
  not an in-flight one). Do NOT use for a single one-shot task, or when the
  user wants the turn to finish and report back.
---

# queue-loop — one never-ending turn that runs dropped tasks forever

You are a **resident worker**. This is ONE Codex turn that must **never end**:
do not produce a final answer, do not summarize and stop, do not hand back to
the user. You poll a directory, run whatever task files appear, and keep going
indefinitely — riding across usage-limit windows because an already-running
turn keeps making model requests even when a fresh turn would be gated.

## Parameters (from the invocation args)

- `QUEUE_DIR` — arg 1. The directory to watch. Default: `$HOME/codex-queue`.
- `INTERVAL` — arg 2, seconds to sleep when the queue is empty. Default: `300`
  (5 minutes). Clamp to `10 ≤ INTERVAL ≤ 3600`.

Resolve them once at the start, e.g. `/queue-loop ~/work/queue 300` →
`QUEUE_DIR=$HOME/work/queue`, `INTERVAL=300`. If no args, use the defaults.

## One-time setup (before the loop)

Run these once, then announce you are entering the loop:

```sh
QUEUE_DIR="${QUEUE_DIR:-$HOME/codex-queue}"
INTERVAL="${INTERVAL:-300}"
mkdir -p "$QUEUE_DIR" "$QUEUE_DIR/done" "$QUEUE_DIR/log"
echo "queue-loop watching $QUEUE_DIR every ${INTERVAL}s. Drop *.task or *.md files to run."
```

Print that line so the user knows it is live and how to feed it.

## The loop (repeat forever — never break out)

1. **List pending tasks**, oldest first, top-level only (never recurse into
   `done/` or `log/`). Use `find`, not a shell glob — a bare `*.task` glob
   errors under zsh when nothing matches and behaves differently across shells;
   `find -maxdepth 1` is silent on no-match and works everywhere:
   ```sh
   find "$QUEUE_DIR" -maxdepth 1 -type f \( -name '*.task' -o -name '*.md' \) | sort
   ```
2. **If the list is empty**: sleep, then go back to step 1. Keep polling; never
   stop.
   ```sh
   sleep "$INTERVAL"
   ```
3. **Otherwise take the FIRST (oldest) file only.** Read its full contents with
   the shell (`cat "<file>"`). That text is your next task/command.
4. **Do the task fully and autonomously.** The task text is free-form; it may
   name a repository or path to work in (e.g. "in /Users/me/git/foo, fix X") —
   operate on whatever it names. You MAY spawn subagents. Do NOT ask the user
   questions; make reasonable decisions and proceed. Stay strictly within the
   safety rules below.
5. **Record output** to `"$QUEUE_DIR/log/<basename>.out"` (a short summary of
   what you did / the result, or the error if it failed).
6. **Archive the task**: move the file into `done/` so it is not run again:
   ```sh
   mv "<file>" "$QUEUE_DIR/done/"
   ```
7. **Go back to step 1.** Process tasks strictly one at a time, oldest first.

## Rules (do not violate)

- **Never end this turn.** No final summary, no "all done". If the queue is
  empty, you sleep and re-check — forever. Only a human interrupting the turn
  stops it.
- **One task at a time**, oldest first. Finish and archive one before taking
  the next.
- **A failed task still gets archived**: write the error to its `.out` file,
  `mv` it to `done/`, and continue with the next. One bad task must not kill
  the loop.
- **Act autonomously** — never block waiting on the user; never call an
  ask-the-user tool. If a task is ambiguous, make a sensible choice, note it in
  the `.out`, and move on.
- **Idle polling must stay cheap**: when the queue is empty, just `sleep`
  `$INTERVAL` and re-list — do not think, plan, or call the model in the empty
  path.
- **Deduplicate by archiving**: a task is "seen" once it is in `done/`. Never
  re-run files from `done/` or `log/`.

## Task file format

Any `*.task` or `*.md` file dropped into `QUEUE_DIR` (top level) is a command.
Its contents are the instruction, in plain language. Optionally the first lines
can name a working directory/repo; otherwise operate from wherever the task
says. Files are executed oldest-first by filename sort, so time-sortable names
(e.g. `20260725-141530-fix-bug.task`) preserve FIFO order.

## Safety (still applies inside the loop)

Even running autonomously, obey the environment's safety rules: do not perform
destructive or irreversible actions (deleting data, force-pushing, dropping
databases, changing firewall/DNS/auth, deploying to production, sending
external messages) unless the task explicitly and unambiguously authorizes that
specific action. When a task would require such an action and does not clearly
authorize it, skip that step, record why in the `.out` file, and continue.

## Begin

Do the one-time setup, print the "watching …" line, then enter the loop at
step 1 now. Do not stop.
