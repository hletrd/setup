#!/usr/bin/env node
/**
 * Test suite for codex-task.
 *   PART A — unit tests: import the module against a throwaway $HOME.
 *   PART B — integration: black-box the real CLI as a child process with a
 *            fake codex-loop queue laid out on disk (no network, no spawns).
 *
 * Run:  node codex-task.test.mjs [/path/to/codex-task]
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync, spawn } from 'node:child_process';
import {
  mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, existsSync, statSync, rmSync, utimesSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

const HERE = dirname(fileURLToPath(import.meta.url));
function firstExisting(...c) { for (const x of c) { try { statSync(x); return x; } catch { /* next */ } } return c[c.length - 1]; }
const TASK = process.argv[2] || firstExisting(join(HERE, 'codex-task'), join(HERE, '..', 'configs', 'codex', 'bin', 'codex-task'));
const NODE = process.execPath;

function tmp(p) { return mkdtempSync(join(tmpdir(), p)); }
function hash12(s) { return createHash('sha256').update(s).digest('hex').slice(0, 12); }
const spawned = [];
process.on('exit', () => { for (const p of spawned) { try { process.kill(p, 'SIGKILL'); } catch {} } });

function cli(home, args, extraEnv = {}) {
  const r = spawnSync(NODE, [TASK, ...args], { env: { ...process.env, HOME: home, ...extraEnv }, encoding: 'utf-8', timeout: 20_000 });
  return { code: r.status, out: `${r.stdout || ''}`, err: `${r.stderr || ''}`, all: `${r.stdout || ''}${r.stderr || ''}` };
}

// Lay out a registered general loop + its queue dirs under a throwaway HOME.
function setupLoop(home, { cwd = join(home, 'ws'), inbox = null, alivePid = null } = {}) {
  const base = join(home, '.codex-loop', hash12(cwd));
  mkdirSync(join(base, 'queue'), { recursive: true });
  mkdirSync(join(base, 'done'), { recursive: true });
  mkdirSync(join(base, 'log'), { recursive: true });
  if (inbox) mkdirSync(inbox, { recursive: true });
  mkdirSync(join(home, '.codex-loop'), { recursive: true });
  writeFileSync(join(home, '.codex-loop', 'watchdog.json'),
    JSON.stringify({ loops: [{ cwd, model: null, inbox }] }, null, 2));
  if (alivePid) writeFileSync(join(base, 'loop.pid'), String(alivePid));
  return { cwd, base, inbox };
}

// ── PART A: unit ────────────────────────────────────────────────────────────
const unitHome = tmp('ct-unit-');
process.env.HOME = unitHome;
const mod = await import(pathToFileURL(TASK).href);

test('makeId is time-sortable and unique', () => {
  const a = mod.makeId(); const b = mod.makeId();
  assert.match(a, /^\d{8}-\d{6}-[0-9a-f]{4}$/);
  assert.notEqual(a, b);
});

test('idFromName strips .task and any codex-loop seq prefix', () => {
  assert.equal(mod.idFromName('20260724-101010-ab12.task'), '20260724-101010-ab12');
  assert.equal(mod.idFromName('000042-20260724-101010-ab12.task'), '20260724-101010-ab12');
});

test('firstLine returns first non-empty trimmed line', () => {
  assert.equal(mod.firstLine('\n\n  hello world \nsecond'), 'hello world');
  assert.equal(mod.firstLine('   '), '');
});

test('fmtAge buckets seconds/minutes/hours/days', () => {
  assert.match(mod.fmtAge(Date.now() - 5_000), /^\d+s$/);
  assert.match(mod.fmtAge(Date.now() - 5 * 60_000), /^\d+m$/);
  assert.match(mod.fmtAge(Date.now() - 3 * 3600_000), /^\d+h\d\dm$/);
  assert.match(mod.fmtAge(Date.now() - 2 * 86400_000), /^\d+d\d\dh$/);
});

test('enumerate classifies queued/done and RUNNING (oldest + alive)', () => {
  const home = tmp('ct-enum-'); process.env.HOME = home;
  const sleeper = spawn('sleep', ['20']); spawned.push(sleeper.pid);
  const { base, cwd, inbox } = setupLoop(home, { cwd: join(home, 'ws'), inbox: join(home, 'ws', 'inbox'), alivePid: sleeper.pid });
  writeFileSync(join(base, 'queue', '20260724-100000-aaaa.task'), 'first task\n');
  writeFileSync(join(base, 'queue', '20260724-110000-bbbb.task'), 'second task\n');
  writeFileSync(join(base, 'done', '20260724-090000-cccc.task'), 'old done\n');
  writeFileSync(join(inbox, '20260724-120000-dddd.task'), 'pending\n');
  const rows = mod.enumerate({ base, cwd, inbox });
  const by = Object.fromEntries(rows.map((r) => [r.id, r.state]));
  assert.equal(by['20260724-100000-aaaa'], 'RUNNING'); // oldest queue + alive
  assert.equal(by['20260724-110000-bbbb'], 'QUEUED');
  assert.equal(by['20260724-090000-cccc'], 'DONE');
  assert.equal(by['20260724-120000-dddd'], 'PENDING');
  try { process.kill(sleeper.pid, 'SIGKILL'); } catch {}
});

test('enumerate: oldest queue is QUEUED (not RUNNING) when loop is dead', () => {
  const home = tmp('ct-dead-'); process.env.HOME = home;
  const { base, cwd, inbox } = setupLoop(home, { cwd: join(home, 'ws') }); // no alivePid
  writeFileSync(join(base, 'queue', '20260724-100000-aaaa.task'), 'x\n');
  const rows = mod.enumerate({ base, cwd, inbox });
  assert.equal(rows[0].state, 'QUEUED');
});

test('findTask resolves by full id and by contained substring', () => {
  const home = tmp('ct-find-'); process.env.HOME = home;
  const { base, cwd, inbox } = setupLoop(home, { cwd: join(home, 'ws') });
  writeFileSync(join(base, 'done', '20260724-100000-aaaa.task'), 'done one\n');
  const loop = { base, cwd, inbox };
  assert.equal(mod.findTask(loop, '20260724-100000-aaaa').state, 'DONE');
  assert.equal(mod.findTask(loop, 'aaaa').id, '20260724-100000-aaaa');
  assert.equal(mod.findTask(loop, 'nope'), null);
});

// ── PART B: integration (black-box CLI) ─────────────────────────────────────
test('submit writes a queue file and prints an id; ls shows it QUEUED', () => {
  const home = tmp('ct-i-submit-');
  const { base } = setupLoop(home, { cwd: join(home, 'ws') });
  const r = cli(home, ['submit', 'do the thing']);
  assert.equal(r.code, 0, r.all);
  const id = r.out.trim().split(/\s+/)[0];
  assert.match(id, /^\d{8}-\d{6}-[0-9a-f]{4}$/);
  assert.ok(existsSync(join(base, 'queue', `${id}.task`)), 'queue file should exist');
  assert.equal(readFileSync(join(base, 'queue', `${id}.task`), 'utf-8'), 'do the thing\n');
  const ls = cli(home, ['ls']);
  assert.match(ls.out, new RegExp(id));
  assert.match(ls.out, /QUEUED/);
  rmSync(home, { recursive: true, force: true });
});

test('submit --repo prepends the repo context line', () => {
  const home = tmp('ct-i-repo-');
  const { base } = setupLoop(home, { cwd: join(home, 'ws') });
  const r = cli(home, ['submit', '--repo', '/Users/x/git/foo', 'fix the bug']);
  const id = r.out.trim().split(/\s+/)[0];
  const text = readFileSync(join(base, 'queue', `${id}.task`), 'utf-8');
  assert.match(text, /^Work in repository: \/Users\/x\/git\/foo\n\nfix the bug/);
  rmSync(home, { recursive: true, force: true });
});

test('submit --file reads task text from a file', () => {
  const home = tmp('ct-i-file-');
  const { base } = setupLoop(home, { cwd: join(home, 'ws') });
  const f = join(home, 'task.txt'); writeFileSync(f, 'multi\nline\ntask\n');
  const r = cli(home, ['submit', '--file', f]);
  const id = r.out.trim().split(/\s+/)[0];
  assert.match(readFileSync(join(base, 'queue', `${id}.task`), 'utf-8'), /multi\nline\ntask/);
  rmSync(home, { recursive: true, force: true });
});

test('submit with no loop registered fails with guidance', () => {
  const home = tmp('ct-i-noloop-');
  mkdirSync(join(home, '.codex-loop'), { recursive: true });
  writeFileSync(join(home, '.codex-loop', 'watchdog.json'), JSON.stringify({ loops: [] }));
  const r = cli(home, ['submit', 'x']);
  assert.notEqual(r.code, 0);
  assert.match(r.all, /no codex-loop is registered/);
  rmSync(home, { recursive: true, force: true });
});

test('multiple loops without --cwd fails; --cwd disambiguates', () => {
  const home = tmp('ct-i-multi-');
  const a = join(home, 'wsA'); const b = join(home, 'wsB');
  setupLoop(home, { cwd: a });
  // add a second loop to the config
  const cfgP = join(home, '.codex-loop', 'watchdog.json');
  const cfg = JSON.parse(readFileSync(cfgP, 'utf-8'));
  cfg.loops.push({ cwd: b, inbox: null }); writeFileSync(cfgP, JSON.stringify(cfg));
  mkdirSync(join(home, '.codex-loop', hash12(b), 'queue'), { recursive: true });
  assert.match(cli(home, ['stats']).all, /multiple loops registered/);
  assert.match(cli(home, ['stats', '--cwd', b]).out, /"total":0/);
  rmSync(home, { recursive: true, force: true });
});

test('rm drops a QUEUED task but refuses a RUNNING one', () => {
  const home = tmp('ct-i-rm-');
  const sleeper = spawn('sleep', ['20']); spawned.push(sleeper.pid);
  const { base } = setupLoop(home, { cwd: join(home, 'ws'), alivePid: sleeper.pid });
  writeFileSync(join(base, 'queue', '20260724-100000-aaaa.task'), 'running one\n');   // oldest → RUNNING
  writeFileSync(join(base, 'queue', '20260724-110000-bbbb.task'), 'queued one\n');    // → QUEUED
  const rmRun = cli(home, ['rm', '20260724-100000-aaaa']);
  assert.notEqual(rmRun.code, 0);
  assert.match(rmRun.all, /RUNNING/);
  assert.ok(existsSync(join(base, 'queue', '20260724-100000-aaaa.task')));
  const rmQ = cli(home, ['rm', 'bbbb']);
  assert.equal(rmQ.code, 0, rmQ.all);
  assert.ok(!existsSync(join(base, 'queue', '20260724-110000-bbbb.task')));
  try { process.kill(sleeper.pid, 'SIGKILL'); } catch {}
  rmSync(home, { recursive: true, force: true });
});

test('show prints task text and its output log', () => {
  const home = tmp('ct-i-show-');
  const { base } = setupLoop(home, { cwd: join(home, 'ws') });
  writeFileSync(join(base, 'done', '20260724-100000-aaaa.task'), 'the task body\n');
  writeFileSync(join(base, 'log', '20260724-100000-aaaa.task.out'), 'RESULT: ok\n');
  const r = cli(home, ['show', 'aaaa']);
  assert.equal(r.code, 0, r.all);
  assert.match(r.out, /state: DONE/);
  assert.match(r.out, /the task body/);
  assert.match(r.out, /RESULT: ok/);
  rmSync(home, { recursive: true, force: true });
});

test('stats reports counts by state', () => {
  const home = tmp('ct-i-stats-');
  const sleeper = spawn('sleep', ['20']); spawned.push(sleeper.pid);
  const { base } = setupLoop(home, { cwd: join(home, 'ws'), inbox: join(home, 'ws', 'inbox'), alivePid: sleeper.pid });
  writeFileSync(join(base, 'queue', '20260724-100000-a.task'), 'r\n');
  writeFileSync(join(base, 'queue', '20260724-110000-b.task'), 'q\n');
  writeFileSync(join(base, 'done', '20260724-090000-c.task'), 'd\n');
  writeFileSync(join(home, 'ws', 'inbox', '20260724-120000-d.task'), 'p\n');
  const s = JSON.parse(cli(home, ['stats']).out);
  assert.equal(s.RUNNING, 1); assert.equal(s.QUEUED, 1); assert.equal(s.DONE, 1); assert.equal(s.PENDING, 1);
  assert.equal(s.total, 4); assert.equal(s.alive, true);
  try { process.kill(sleeper.pid, 'SIGKILL'); } catch {}
  rmSync(home, { recursive: true, force: true });
});

test('purge deletes only old DONE/log, needs --yes, never touches queue', () => {
  const home = tmp('ct-i-purge-');
  const { base } = setupLoop(home, { cwd: join(home, 'ws') });
  const old = new Date(Date.now() - 30 * 86400_000);
  const doneF = join(base, 'done', '20260624-100000-old.task'); writeFileSync(doneF, 'old\n');
  const logF = join(base, 'log', '20260624-100000-old.task.out'); writeFileSync(logF, 'log\n');
  const queueF = join(base, 'queue', '20260724-100000-new.task'); writeFileSync(queueF, 'keep\n');
  utimesSync(doneF, old, old); utimesSync(logF, old, old);
  // dry run
  const dry = cli(home, ['purge', '--older-than', '7']);
  assert.match(dry.out, /Re-run with --yes/);
  assert.ok(existsSync(doneF));
  // real
  const real = cli(home, ['purge', '--older-than', '7', '--yes']);
  assert.match(real.out, /purged 2 file/);
  assert.ok(!existsSync(doneF)); assert.ok(!existsSync(logF));
  assert.ok(existsSync(queueF), 'purge must never touch the queue');
  rmSync(home, { recursive: true, force: true });
});

test('ls --json emits structured rows; --state filters', () => {
  const home = tmp('ct-i-json-');
  const { base } = setupLoop(home, { cwd: join(home, 'ws') });
  writeFileSync(join(base, 'queue', '20260724-100000-a.task'), 'q\n');
  writeFileSync(join(base, 'done', '20260724-090000-b.task'), 'd\n');
  const rows = JSON.parse(cli(home, ['ls', '--json']).out);
  assert.equal(rows.length, 2);
  const done = JSON.parse(cli(home, ['ls', '--state', 'DONE', '--json']).out);
  assert.equal(done.length, 1); assert.equal(done[0].state, 'DONE');
  rmSync(home, { recursive: true, force: true });
});

test('where prints the resolved loop directories', () => {
  const home = tmp('ct-i-where-');
  const { base } = setupLoop(home, { cwd: join(home, 'ws'), inbox: join(home, 'ws', 'inbox') });
  const w = JSON.parse(cli(home, ['where']).out);
  assert.equal(w.base, base);
  assert.equal(w.queue, join(base, 'queue'));
  assert.match(w.inbox, /inbox$/);
  rmSync(home, { recursive: true, force: true });
});
