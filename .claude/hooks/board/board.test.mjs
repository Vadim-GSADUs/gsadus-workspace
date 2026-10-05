// node --test C:\GSADUs\.claude\hooks\board\board.test.mjs
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { frontmatter, lastReview, projectOf, summary } from './board.mjs';
import { mergeHook } from './install.mjs';

const note = [
  '---', 'project: WebApp', 'state: now', 'rank: 2', 'next: "ship the switch"', 'blocker:',
  'asks:', '  - "decide · the cutover date"', '  - admin · rotate the key', 'sources:',
  '  - repo: ../WebApp/docs/HANDOFF.md', 'touched: 2026-10-05', '---', 'body',
].join('\r\n');

test('frontmatter reads scalars, quoted values, lists and empty keys', () => {
  const fm = frontmatter(note);
  assert.equal(fm.next, 'ship the switch');
  assert.deepEqual(fm.blocker, []);
  assert.deepEqual(fm.asks, ['decide · the cutover date', 'admin · rotate the key']);
  assert.deepEqual(fm.sources, ['repo: ../WebApp/docs/HANDOFF.md']);
  assert.deepEqual(frontmatter('no frontmatter'), {});
  assert.deepEqual(frontmatter('---\nasks: []\n---\n').asks, []);
});

test('projectOf names the repo a session runs in', () => {
  const ws = 'C:\\GSADUs';
  assert.equal(projectOf('C:\\GSADUs', ws), 'Workspace');
  assert.equal(projectOf('c:\\gsadus\\WebApp\\app', ws), 'WebApp');
  assert.equal(projectOf('C:\\GSADUs\\PostProcess\\PNGTools\\.claude\\worktrees\\x', ws), 'PNGTools');
  assert.equal(projectOf('C:\\GSADUs\\.claude\\worktrees\\y', ws), 'Workspace');
  assert.equal(projectOf('C:\\AGENTS\\Steps', ws), null);
});

test('summary lists Now by rank, open asks, and an overdue review', () => {
  const threads = [
    { name: 'PM · b', project: 'PM', state: 'now', rank: '1', next: 'b next' },
    { name: 'WebApp · a', ...frontmatter(note) },
    { name: 'WebApp · done', project: 'WebApp', state: 'done', asks: ['decide · old'] },
    { name: 'Tools · parked', project: 'Tools', state: 'parked', asks: ['live · check'] },
    { name: 'PM · c', project: 'PM', state: 'next', rank: '1', asks: ['admin · console step'] },
  ];
  const out = summary(threads, { reviewed: '2026-09-20', project: 'WebApp', today: new Date('2026-10-05T12:00:00') });
  const lines = out.split('\n');
  assert.equal(lines[2], '- PM · b — next: b next');
  assert.equal(lines[3], '- WebApp · a (this repo) — next: ship the switch');
  assert.ok(out.includes('- WebApp · a (this repo): decide · the cutover date'));
  assert.ok(!out.includes('live · check'), 'a parked thread\'s asks wait for the weekly review');
  assert.ok(!out.includes('old'));
  assert.ok(!out.includes('console step'), 'another repo\'s asks are only counted');
  assert.ok(out.includes('Also waiting on the owner: 1 ask on other repos\' threads (Board.md).'));
  assert.ok(out.includes('Board review due: last reviewed 2026-09-20.'));
  const root = summary(threads, { reviewed: '2026-10-05', project: 'Workspace', today: new Date('2026-10-05T12:00:00') });
  assert.ok(root.indexOf('WebApp · a: decide') < root.indexOf('PM · c: admin'), 'the root sees every ask, Now first');
  assert.ok(!root.includes('Also waiting'));
});

test('summary is silent when nothing is open and the review is fresh', () => {
  assert.equal(summary([], { reviewed: '2026-10-05', today: new Date('2026-10-06T09:00:00') }), '');
});

test('lastReview dates the latest weekly-review commit', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'board-'));
  const git = (args, date) => execFileSync('git', ['-C', dir, '-c', 'user.name=t', '-c', 'user.email=t@t', ...args],
    { stdio: 'ignore', env: date ? { ...process.env, GIT_AUTHOR_DATE: date, GIT_COMMITTER_DATE: date } : process.env });
  try {
    git(['init', '-q']);
    assert.equal(lastReview(dir), '');
    git(['commit', '-q', '--allow-empty', '-m', 'board: weekly review'], '2026-09-28T10:00:00');
    git(['commit', '-q', '--allow-empty', '-m', 'board: PM · b — next step'], '2026-10-01T10:00:00');
    assert.equal(lastReview(dir), '2026-09-28');
    assert.equal(lastReview(path.join(dir, 'missing')), '');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('mergeHook replaces only its own handler', () => {
  const config = { hooks: { SessionStart: [{ hooks: [{ type: 'command', command: 'node "C:\\x\\helpdesk.ts" status --hook claude' }] },
    { hooks: [{ type: 'command', command: 'node "C:\\old\\hooks\\board\\board.mjs" hook' }] }] } };
  const next = mergeHook(config, 'codex', 'C:\\GSADUs\\.claude\\hooks\\board\\board.mjs');
  assert.equal(next.hooks.SessionStart.length, 2);
  assert.match(next.hooks.SessionStart[0].hooks[0].command, /helpdesk/);
  assert.equal(next.hooks.SessionStart[1].hooks[0].statusMessage, 'Reading the board');
  assert.deepEqual(mergeHook(next, 'codex', 'C:\\GSADUs\\.claude\\hooks\\board\\board.mjs'), next);
});
