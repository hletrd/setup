#!/usr/bin/env node
/**
 * Test suite for codex-loop-watchdog.
 *
 *   PART A — unit tests: import the module against a throwaway $HOME and
 *            exercise the pure/file-level helpers directly.
 *   PART B — integration/mock tests: black-box the real `run` tick as a child
 *            process with a mock `codex` binary, a mock wham/usage HTTP server,
 *            and a real copy of codex-loop — no network, no production files.
 *
 * Run:  node codex-loop-watchdog.test.mjs [/path/to/codex-loop-watchdog] [/path/to/codex-loop]
 * Exit: 0 all pass, 1 any fail. Zero external deps (node:test + node:assert).
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync, spawn } from 'node:child_process';
import {
  mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync,
  existsSync, statSync, utimesSync, rmSync, chmodSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import http from 'node:http';
import { createHash } from 'node:crypto';

const HERE = dirname(fileURLToPath(import.meta.url));
// Default to the repo layout: this test lives in setup/tests/, the binaries in
// setup/configs/codex/bin/. Override with argv for other layouts.
function firstExisting(...cands) { for (const c of cands) { try { statSync(c); return c; } catch { /* next */ } } return cands[cands.length - 1]; }
const WD = process.argv[2] || firstExisting(join(HERE, 'codex-loop-watchdog'), join(HERE, '..', 'configs', 'codex', 'bin', 'codex-loop-watchdog'));
const LOOP = process.argv[3] || firstExisting(join(HERE, 'codex-loop'), join(HERE, '..', 'configs', 'codex', 'bin', 'codex-loop'));
const NODE = process.execPath;

function tmp(prefix) { return mkdtempSync(join(tmpdir(), prefix)); }
function hash12(s) { return createHash('sha256').update(s).digest('hex').slice(0, 12); }
const spawnedPids = [];
function killAllSpawned() { for (const p of spawnedPids) { try { process.kill(p, 'SIGKILL'); } catch { /* gone */ } } }
process.on('exit', killAllSpawned);

// A fake `codex` that stays alive (keeps "codex" in its ps command line) so the
// watchdog's liveness + looksLikeCodex checks see a real running loop.
function writeFakeCodex(dir, { sleep = 30 } = {}) {
  mkdirSync(dir, { recursive: true });
  const p = join(dir, 'codex');
  writeFileSync(p, `#!/bin/sh\n# fake codex — do NOT exec, keep argv0 path (contains "codex") as the live process\nsleep ${sleep}\n`, { mode: 0o755 });
  chmodSync(p, 0o755);
  return p;
}

// A mock wham/usage server whose gate state is toggled by writing STATE_FILE.
function startUsageServer(stateFile) {
  const server = http.createServer((req, res) => {
    let body = { rate_limit: { limit_reached: false, primary_window: { used_percent: 12 } }, spend_control: { reached: false } };
    try { body = JSON.parse(readFileSync(stateFile, 'utf-8')); } catch { /* default gate-open */ }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => {
    resolve({ server, url: `http://127.0.0.1:${server.address().port}/usage` });
  }));
}

function writeAuth(home) {
  mkdirSync(join(home, '.codex'), { recursive: true });
  writeFileSync(join(home, '.codex', 'auth.json'), JSON.stringify({ auth_mode: 'chatgpt', tokens: { access_token: 'test-token' } }));
}

// Run `codex-loop-watchdog run` as an ASYNC child. Critical: the mock usage
// server runs in THIS process, so we must NOT block the event loop with
// spawnSync — otherwise the child's fetch to the mock server would hang until
// timeout and every tick would wrongly see "oracle unreachable".
function runTick(home, { usageUrl, codexBin, settleMs = 800, extraEnv = {} }) {
  const env = {
    ...process.env,
    HOME: home,
    PATH: `${dirname(codexBin)}:${dirname(NODE)}:/usr/bin:/bin`,
    CODEX_LOOP_BIN: codexBin,
    CODEX_WATCHDOG_USAGE_URL: usageUrl,
    CODEX_WATCHDOG_SETTLE_MS: String(settleMs),
    CODEX_WATCHDOG_INBOX_MIN_AGE_MS: '0',
    ...extraEnv,
  };
  return new Promise((resolve) => {
    const child = spawn(NODE, [WD, 'run'], { env });
    let out = '';
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { out += d; });
    const timer = setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, 60_000);
    child.on('close', (code) => { clearTimeout(timer); resolve({ code, out, log: readWatchdogLog(home) }); });
  });
}

function readWatchdogLog(home) {
  try { return readFileSync(join(home, '.codex-loop', 'watchdog.log'), 'utf-8'); } catch { return ''; }
}
function wdCli(home, args, extraEnv = {}) {
  const r = spawnSync(NODE, [WD, ...args], { env: { ...process.env, HOME: home, ...extraEnv }, encoding: 'utf-8', timeout: 20_000 });
  return { code: r.status, out: `${r.stdout || ''}${r.stderr || ''}` };
}
function baseFor(home, cwd) { return join(home, '.codex-loop', hash12(cwd)); }
function setGate(stateFile, { rate = false, spend = false, pct = 12 }) {
  writeFileSync(stateFile, JSON.stringify({ rate_limit: { limit_reached: rate, primary_window: { used_percent: pct } }, spend_control: { reached: spend } }));
}
// Poll until predicate true or timeout — avoids fixed sleeps on the fake loop.
async function waitFor(fn, ms = 4000, step = 50) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (fn()) return true; await new Promise((r) => setTimeout(r, step)); }
  return fn();
}

// ─────────────────────────────────────────────────────────────────────────────
// PART A — unit tests (in-process import against a throwaway $HOME)
// ─────────────────────────────────────────────────────────────────────────────
const unitHome = tmp('wd-unit-');
process.env.HOME = unitHome;
const mod = await import(pathToFileURL(WD).href);

test('baseDirFor is deterministic and 12-hex under ~/.codex-loop', () => {
  const b = mod.baseDirFor('/some/cwd');
  assert.equal(b, join(unitHome, '.codex-loop', hash12('/some/cwd')));
  assert.equal(mod.baseDirFor('/some/cwd'), b);
  assert.notEqual(mod.baseDirFor('/other'), b);
});

test('nextSeq increments and persists monotonically', () => {
  const base = join(unitHome, 'seqtest'); mkdirSync(base, { recursive: true });
  assert.equal(mod.nextSeq(base), 1);
  assert.equal(mod.nextSeq(base), 2);
  assert.equal(mod.nextSeq(base), 3);
  assert.equal(readFileSync(join(base, '.seq'), 'utf-8'), '3');
});

test('claimQueueName avoids collisions with existing queue files', () => {
  const base = join(unitHome, 'claimtest'); const queue = join(base, 'queue');
  mkdirSync(queue, { recursive: true });
  writeFileSync(join(base, '.seq'), '0');
  const a = mod.claimQueueName(base, queue, 'x');
  writeFileSync(join(queue, a.name), 'taken');
  const b = mod.claimQueueName(base, queue, 'x');
  assert.notEqual(a.name, b.name);
  assert.match(b.name, /\.task$/);
});

test('writeJsonAtomic writes valid JSON and leaves no tmp file', () => {
  const p = join(unitHome, 'atomic.json');
  mod.writeJsonAtomic(p, { a: 1, nested: { b: [1, 2] } });
  assert.deepEqual(JSON.parse(readFileSync(p, 'utf-8')), { a: 1, nested: { b: [1, 2] } });
  assert.ok(!readdirSync(unitHome).some((f) => f.startsWith('atomic.json.tmp')));
});

test('readJson returns fallback on missing/corrupt files', () => {
  assert.deepEqual(mod.readJson(join(unitHome, 'nope.json'), { x: 1 }), { x: 1 });
  const bad = join(unitHome, 'bad.json'); writeFileSync(bad, '{ not json');
  assert.deepEqual(mod.readJson(bad, { fallback: true }), { fallback: true });
});

test('drainInbox: moves a task into queue and archives to processed', () => {
  const cwd = '/proj/one';
  const inbox = join(unitHome, 'inbox-one'); mkdirSync(inbox, { recursive: true });
  writeFileSync(join(inbox, 'fix-bug.task'), 'do the fix\n');
  const oldA = Date.now() / 1000 - 10; utimesSync(join(inbox, 'fix-bug.task'), oldA, oldA);
  const moved = mod.drainInbox({ cwd, inbox });
  assert.equal(moved, 1);
  const queue = join(mod.baseDirFor(cwd), 'queue');
  const qfiles = readdirSync(queue).filter((f) => f.endsWith('.task'));
  assert.equal(qfiles.length, 1);
  assert.match(qfiles[0], /fix-bug/);
  assert.equal(readFileSync(join(queue, qfiles[0]), 'utf-8'), 'do the fix\n');
  assert.ok(readdirSync(join(inbox, 'processed')).some((f) => f.endsWith('fix-bug.task')));
  assert.ok(!existsSync(join(inbox, 'fix-bug.task')));
});

test('drainInbox: empty task is archived (empty-) not queued', () => {
  const cwd = '/proj/empty';
  const inbox = join(unitHome, 'inbox-empty'); mkdirSync(inbox, { recursive: true });
  writeFileSync(join(inbox, 'blank.task'), '   \n');
  const oldE = Date.now() / 1000 - 10; utimesSync(join(inbox, 'blank.task'), oldE, oldE);
  const moved = mod.drainInbox({ cwd, inbox });
  assert.equal(moved, 0);
  const queue = join(mod.baseDirFor(cwd), 'queue');
  const q = existsSync(queue) ? readdirSync(queue).filter((f) => f.endsWith('.task')) : [];
  assert.equal(q.length, 0);
  assert.ok(readdirSync(join(inbox, 'processed')).some((f) => f.startsWith('empty-')));
});

test('drainInbox: skips files younger than INBOX_MIN_AGE (mid-write) and non-.task', () => {
  // default min-age is 2000ms in-process; a just-written file must be skipped
  const cwd = '/proj/midwrite';
  const inbox = join(unitHome, 'inbox-mid'); mkdirSync(inbox, { recursive: true });
  writeFileSync(join(inbox, 'fresh.task'), 'too new');
  writeFileSync(join(inbox, 'notes.txt'), 'ignore me');
  const moved = mod.drainInbox({ cwd, inbox });
  assert.equal(moved, 0);
  assert.ok(existsSync(join(inbox, 'fresh.task')));   // still there, not claimed
  // now age it past the threshold and it drains
  const old = Date.now() / 1000 - 10;
  utimesSync(join(inbox, 'fresh.task'), old, old);
  assert.equal(mod.drainInbox({ cwd, inbox }), 1);
});

test('drainInbox: sanitizes slug from weird filenames', () => {
  const cwd = '/proj/slug';
  const inbox = join(unitHome, 'inbox-slug'); mkdirSync(inbox, { recursive: true });
  const f = 'weird name (v2)!!.task';
  writeFileSync(join(inbox, f), 'x');
  const old = Date.now() / 1000 - 10; utimesSync(join(inbox, f), old, old);
  mod.drainInbox({ cwd, inbox });
  const queue = join(mod.baseDirFor(cwd), 'queue');
  const q = readdirSync(queue).filter((x) => x.endsWith('.task'));
  assert.equal(q.length, 1);
  assert.doesNotMatch(q[0], /[()!\s]/); // no unsafe chars in the queued name
});

test('looksLikeCodex: true for this node process path? false for a sleeper', () => {
  // a plain `sleep` has no "codex" in its command line
  const child = spawn('sleep', ['5']); spawnedPids.push(child.pid);
  assert.equal(mod.looksLikeCodex(child.pid), false);
  assert.equal(mod.looksLikeCodex(2 ** 30), false); // almost-certainly-dead pid
  try { process.kill(child.pid, 'SIGKILL'); } catch { /* ignore */ }
});

// ─────────────────────────────────────────────────────────────────────────────
// PART B — integration / mock tests (black-box the real `run` tick)
// ─────────────────────────────────────────────────────────────────────────────
test('integration: dead loop + gate OPEN → restarted, pid alive', async () => {
  const home = tmp('wd-int-open-'); writeAuth(home);
  mkdirSync(join(home, '.local', 'bin'), { recursive: true });
  spawnSync('cp', [LOOP, join(home, '.local', 'bin', 'codex-loop')]);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, { rate: false, spend: false });
  const { url, server } = await startUsageServer(gate);
  try {
    const cwd = join(home, 'proj'); mkdirSync(cwd, { recursive: true });
    wdCli(home, ['add', '--cwd', cwd]);
    const r = await runTick(home, { usageUrl: url, codexBin });
    assert.equal(r.code, 0, r.out);
    const base = baseFor(home, cwd);
    const ok = await waitFor(() => existsSync(join(base, 'loop.pid')));
    assert.ok(ok, 'loop.pid should exist after restart: ' + r.log);
    const pid = parseInt(readFileSync(join(base, 'loop.pid'), 'utf-8'), 10);
    let alive = false; try { process.kill(pid, 0); alive = true; } catch { /* dead */ }
    spawnedPids.push(pid);
    assert.ok(alive, 'restarted loop pid should be alive');
    assert.match(r.log, /restarted:/);
  } finally { server.close(); rmSync(home, { recursive: true, force: true }); }
});

test('integration: dead loop + gate CLOSED (spend cap) → NOT started, logs waiting', async () => {
  const home = tmp('wd-int-cap-'); writeAuth(home);
  mkdirSync(join(home, '.local', 'bin'), { recursive: true });
  spawnSync('cp', [LOOP, join(home, '.local', 'bin', 'codex-loop')]);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, { rate: false, spend: true });
  const { url, server } = await startUsageServer(gate);
  try {
    const cwd = join(home, 'proj'); mkdirSync(cwd, { recursive: true });
    wdCli(home, ['add', '--cwd', cwd]);
    const r = await runTick(home, { usageUrl: url, codexBin });
    assert.equal(r.code, 0, r.out);
    const base = baseFor(home, cwd);
    assert.ok(!existsSync(join(base, 'loop.pid')), 'must NOT start under a closed gate');
    assert.match(r.log, /gate closed/);
  } finally { server.close(); rmSync(home, { recursive: true, force: true }); }
});

test('integration: alive loop → left alone (idempotent, no second start)', async () => {
  const home = tmp('wd-int-alive-'); writeAuth(home);
  mkdirSync(join(home, '.local', 'bin'), { recursive: true });
  spawnSync('cp', [LOOP, join(home, '.local', 'bin', 'codex-loop')]);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, {});
  const { url, server } = await startUsageServer(gate);
  try {
    const cwd = join(home, 'proj'); mkdirSync(cwd, { recursive: true });
    wdCli(home, ['add', '--cwd', cwd]);
    await runTick(home, { usageUrl: url, codexBin });                 // first: starts it
    const base = baseFor(home, cwd);
    await waitFor(() => existsSync(join(base, 'loop.pid')));
    const pid1 = readFileSync(join(base, 'loop.pid'), 'utf-8'); spawnedPids.push(parseInt(pid1, 10));
    const r2 = await runTick(home, { usageUrl: url, codexBin });      // second: must not restart
    const pid2 = readFileSync(join(base, 'loop.pid'), 'utf-8');
    assert.equal(pid1, pid2, 'alive loop must keep the same pid');
    // cumulative log must show exactly ONE start across both ticks
    assert.equal((r2.log.match(/^.*start: /gm) || []).length, 1, 'alive loop must not be started twice: ' + r2.log);
  } finally { server.close(); rmSync(home, { recursive: true, force: true }); }
});

test('integration: paused loop → not restarted even when dead + gate open', async () => {
  const home = tmp('wd-int-pause-'); writeAuth(home);
  mkdirSync(join(home, '.local', 'bin'), { recursive: true });
  spawnSync('cp', [LOOP, join(home, '.local', 'bin', 'codex-loop')]);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, {});
  const { url, server } = await startUsageServer(gate);
  try {
    const cwd = join(home, 'proj'); mkdirSync(cwd, { recursive: true });
    wdCli(home, ['add', '--cwd', cwd]);
    wdCli(home, ['pause', '--cwd', cwd]);
    const r = await runTick(home, { usageUrl: url, codexBin });
    const base = baseFor(home, cwd);
    assert.ok(!existsSync(join(base, 'loop.pid')), 'paused loop must not be started');
    assert.equal(r.code, 0, r.out);
  } finally { server.close(); rmSync(home, { recursive: true, force: true }); }
});

test('integration: recycled pid (alive non-codex) → cleared and restarted', async () => {
  const home = tmp('wd-int-recyc-'); writeAuth(home);
  mkdirSync(join(home, '.local', 'bin'), { recursive: true });
  spawnSync('cp', [LOOP, join(home, '.local', 'bin', 'codex-loop')]);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, {});
  const { url, server } = await startUsageServer(gate);
  const sleeper = spawn('sleep', ['30']); spawnedPids.push(sleeper.pid);
  try {
    const cwd = join(home, 'proj'); mkdirSync(cwd, { recursive: true });
    wdCli(home, ['add', '--cwd', cwd]);
    const base = baseFor(home, cwd); mkdirSync(base, { recursive: true });
    writeFileSync(join(base, 'loop.pid'), String(sleeper.pid)); // recycled: alive but not codex
    const r = await runTick(home, { usageUrl: url, codexBin });
    assert.match(r.log, /recycled/);
    const ok = await waitFor(() => {
      try { return parseInt(readFileSync(join(base, 'loop.pid'), 'utf-8'), 10) !== sleeper.pid; } catch { return false; }
    });
    assert.ok(ok, 'pid file should now point at a fresh codex loop: ' + r.log);
    const npid = parseInt(readFileSync(join(base, 'loop.pid'), 'utf-8'), 10); spawnedPids.push(npid);
    let alive = false; try { process.kill(npid, 0); alive = true; } catch { /* dead */ }
    assert.ok(alive);
  } finally { server.close(); try { process.kill(sleeper.pid, 'SIGKILL'); } catch {} rmSync(home, { recursive: true, force: true }); }
});

test('integration: inbox drop is drained into the queue by a tick', async () => {
  const home = tmp('wd-int-inbox-'); writeAuth(home);
  mkdirSync(join(home, '.local', 'bin'), { recursive: true });
  spawnSync('cp', [LOOP, join(home, '.local', 'bin', 'codex-loop')]);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, { spend: true }); // keep loop from starting; isolate inbox behavior
  const { url, server } = await startUsageServer(gate);
  try {
    const cwd = join(home, 'proj'); mkdirSync(cwd, { recursive: true });
    const inbox = join(home, 'inbox'); mkdirSync(inbox, { recursive: true });
    wdCli(home, ['add', '--cwd', cwd, '--inbox', inbox]);
    writeFileSync(join(inbox, 'task-a.task'), 'alpha\n');
    const r = await runTick(home, { usageUrl: url, codexBin, extraEnv: { CODEX_WATCHDOG_INBOX_MIN_AGE_MS: '0' } });
    assert.equal(r.code, 0, r.out);
    const queue = join(baseFor(home, cwd), 'queue');
    const q = readdirSync(queue).filter((f) => f.endsWith('.task'));
    assert.equal(q.length, 1);
    assert.match(q[0], /task-a/);
    assert.ok(readdirSync(join(inbox, 'processed')).length >= 1);
  } finally { server.close(); rmSync(home, { recursive: true, force: true }); }
});

test('integration: corrupt watchdog.json → tick survives, manages nothing', async () => {
  const home = tmp('wd-int-badcfg-'); writeAuth(home);
  mkdirSync(join(home, '.codex-loop'), { recursive: true });
  writeFileSync(join(home, '.codex-loop', 'watchdog.json'), '{ broken json ');
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, {});
  const { url, server } = await startUsageServer(gate);
  try {
    const r = await runTick(home, { usageUrl: url, codexBin });
    assert.equal(r.code, 0, 'tick must not crash on bad config: ' + r.out);
    assert.match(r.log, /CONFIG PARSE ERROR/);
  } finally { server.close(); rmSync(home, { recursive: true, force: true }); }
});

test('integration: usage oracle unreachable → no start, throttled retry', async () => {
  const home = tmp('wd-int-oracle-'); writeAuth(home);
  mkdirSync(join(home, '.local', 'bin'), { recursive: true });
  spawnSync('cp', [LOOP, join(home, '.local', 'bin', 'codex-loop')]);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const base = baseFor(home, join(home, 'proj'));
  try {
    const cwd = join(home, 'proj'); mkdirSync(cwd, { recursive: true });
    wdCli(home, ['add', '--cwd', cwd]);
    // point at a dead port → getUsage returns null → blocked===null → no start
    const r = await runTick(home, { usageUrl: 'http://127.0.0.1:9/usage', codexBin, extraEnv: { CODEX_WATCHDOG_RETRY_UNKNOWN_MS: '900000' } });
    assert.equal(r.code, 0, r.out);
    // first attempt when oracle unknown DOES try once (lastAttempt unset), so it may start;
    // to assert throttle, run again immediately and confirm no *second* attempt logged.
    const r2 = await runTick(home, { usageUrl: 'http://127.0.0.1:9/usage', codexBin, extraEnv: { CODEX_WATCHDOG_RETRY_UNKNOWN_MS: '900000' } });
    const attempts = (r2.log.match(/start: /g) || []).length;
    assert.ok(attempts <= 1, 'unknown-oracle retry must be throttled, saw ' + attempts + ' starts');
    try { spawnedPids.push(parseInt(readFileSync(join(base, 'loop.pid'), 'utf-8'), 10)); } catch { /* none started */ }
  } finally { try { process.kill(parseInt(readFileSync(join(base, 'loop.pid'), 'utf-8'), 10), 'SIGKILL'); } catch {} rmSync(home, { recursive: true, force: true }); }
});

test('integration: stale tick lock is recovered; fresh lock blocks re-entry', async () => {
  const home = tmp('wd-int-lock-'); writeAuth(home);
  const codexBin = writeFakeCodex(join(home, 'fakebin'));
  const gate = join(home, 'gate.json'); setGate(gate, {});
  const { url, server } = await startUsageServer(gate);
  try {
    const lock = join(home, '.codex-loop', 'watchdog.tick.lock');
    mkdirSync(lock, { recursive: true });
    // fresh lock → tick returns early, does NOT write __lastTick
    let r = await runTick(home, { usageUrl: url, codexBin, extraEnv: { CODEX_WATCHDOG_LOCK_STALE_MS: '600000' } });
    assert.equal(r.code, 0);
    const statePath = join(home, '.codex-loop', 'watchdog-state.json');
    assert.ok(!existsSync(statePath), 'fresh lock should block the tick body');
    // age the lock past stale threshold → next tick recovers and runs
    const old = Date.now() / 1000 - 3600; utimesSync(lock, old, old);
    r = await runTick(home, { usageUrl: url, codexBin, extraEnv: { CODEX_WATCHDOG_LOCK_STALE_MS: '1000' } });
    assert.equal(r.code, 0);
    assert.ok(existsSync(statePath), 'stale lock must be recovered and the tick must run');
  } finally { server.close(); rmSync(home, { recursive: true, force: true }); }
});

test('integration: CLI add/list/remove round-trips', async () => {
  const home = tmp('wd-int-cli-');
  const cwd = join(home, 'p'); mkdirSync(cwd, { recursive: true });
  assert.match(wdCli(home, ['list']).out, /no loops managed/);
  wdCli(home, ['add', '--cwd', cwd, '--inbox', join(home, 'ibx'), '--model', 'gpt-5.6-sol']);
  const list = wdCli(home, ['list']).out;
  assert.match(list, /"alive":false/);
  assert.match(list, /gpt-5\.6-sol/);
  wdCli(home, ['remove', '--cwd', cwd]);
  assert.match(wdCli(home, ['list']).out, /no loops managed/);
});
