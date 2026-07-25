---
name: queue-submit
description: |
  Inject a task into the queue-loop worker's queue so a running Codex resident
  worker picks it up on its next poll (~5 min). Use when the user says
  "queue-submit", "큐에 작업 넣어", "task 주입해", "이거 워커한테 넘겨",
  "submit a task to the codex worker", "enqueue this for queue-loop", or wants
  to hand a job off to the always-on worker instead of doing it inline. It only
  writes a *.task file into the watched queue directory (default ~/codex-queue)
  — it does NOT run the task in this session. Do not use when the user wants the
  work done right now in the current session.
---

# queue-submit — hand a task to the always-on queue-loop worker

Append a task file to the directory a running `/queue-loop` Codex worker
watches, so the resident worker runs it autonomously on its next poll. This
skill **only enqueues** — it does NOT execute the task in the current session.

## Parameters (from the invocation / request)

- **Task text** — the instruction to enqueue, taken from the invocation args or
  the user's current request.
- `--repo PATH` (optional) — the repository/directory the task should operate
  in. It is prepended as a `Work in repository: PATH` line so the general
  worker (which runs from a neutral workspace) knows where to work.
- `--dir QUEUE_DIR` (optional) — the queue directory to submit into. Default
  `$HOME/codex-queue` (queue-loop's default). It MUST match the directory the
  `/queue-loop` worker was started with, or the worker won't see the task.

## Steps

1. **Resolve the queue dir** and make sure it exists:
   ```bash
   QUEUE_DIR="${QUEUE_DIR:-$HOME/codex-queue}"
   mkdir -p "$QUEUE_DIR"
   ```
2. **Generate a time-sortable id** (keeps the worker's oldest-first FIFO order):
   ```bash
   ID="$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 2 2>/dev/null || printf '%04x' $RANDOM)"
   echo "$ID"
   ```
3. **Compose the task content.** If `--repo PATH` was given, the FIRST line must
   be `Work in repository: PATH`, then a blank line, then the instruction text.
   Otherwise the content is just the instruction text.
4. **Write the content** to `"$QUEUE_DIR/$ID.task"` using your file-writing tool
   (NOT `echo`/heredoc — the task text may contain quotes or newlines, and a
   fragile shell escape could corrupt it). The filename MUST end in `.task`.
5. **Confirm.** Print the id, the full path, and the current queue depth:
   ```bash
   echo "queued: $QUEUE_DIR/$ID.task"
   find "$QUEUE_DIR" -maxdepth 1 -type f \( -name '*.task' -o -name '*.md' \) | wc -l
   ```
   Tell the user: the worker picks it up within one poll interval (~5 min) **if
   `/queue-loop` is running**; if no worker is running, the file simply waits in
   the queue until one is started.

## Rules

- **Only enqueue.** Do not start doing the task yourself in this session.
- **One file per task.** The id is unique; if a file with that name somehow
  already exists, regenerate the id rather than overwriting.
- **Never write into `done/` or `log/`** under QUEUE_DIR — those are the
  worker's archive and output; new tasks go in the top level only.
- **Echo back what you enqueued** (id + the first line of the task) so the user
  can track it. To check status later, list `QUEUE_DIR` (pending), `done/`
  (finished), and `log/*.out` (output).
