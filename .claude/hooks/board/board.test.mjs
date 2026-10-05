// node --test C:\GSADUs\.claude\hooks\board\board.test.mjs
import assert from 'node:assert/strict';
import test from 'node:test';
import { frontmatter, projectOf, summary } from './board.mjs';
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
  ];
  const out = summary(threads, { reviewed: '2026-09-20', project: 'WebApp', today: new Date('2026-10-05T12:00:00') });
  const lines = out.split('\n');
  assert.equal(lines[2], '- PM · b — next: b next');
  assert.equal(lines[3], '- WebApp · a (this repo) — next: ship the switch');
  assert.ok(out.includes('- WebApp · a (this repo): decide · the cutover date'));
  assert.ok(out.includes('- Tools · parked: live · check'));
  assert.ok(!out.includes('old'));
  assert.ok(out.includes('Board review due: last reviewed 2026-09-20.'));
});

test('summary is silent when nothing is open and the review is fresh', () => {
  assert.equal(summary([], { reviewed: '2026-10-05', today: new Date('2026-10-06T09:00:00') }), '');
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
