// Board context at session start: the owner's Now threads and open asks from the Vault board
// (Vault AGENTS.md → Board), so every session under C:\GSADUs starts knowing what is in flight.
// Shared by Claude Code and Codex, installed per machine by install.mjs. Node.js 18+, no
// dependencies. Silent outside the workspace and when nothing is open; never blocks a session.
//   node board.mjs hook   # SessionStart: reads the hook JSON on stdin, prints hook JSON
//   node board.mjs        # the same lines, for a person
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const WORKSPACE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
const VAULT = path.join(WORKSPACE, 'Vault');
const REVIEW_DAYS = 7;

const unquote = (s) => s.trim().replace(/^(["'])(.*)\1$/, '$2');

// The subset the board uses: `key: value` scalars and `  - item` lists.
export function frontmatter(text) {
  const out = {};
  const m = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(text);
  if (!m) return out;
  let listKey = null;
  for (const line of m[1].split(/\r?\n/)) {
    const item = /^\s+-\s+(.*)$/.exec(line);
    if (item && listKey) { out[listKey].push(unquote(item[1])); continue; }
    const kv = /^([A-Za-z_][\w-]*):\s*(.*?)\s*$/.exec(line);
    if (!kv) continue;
    listKey = null;
    if (kv[2] === '' || kv[2] === '[]') { out[kv[1]] = []; if (kv[2] === '') listKey = kv[1]; }
    else out[kv[1]] = unquote(kv[2]);
  }
  return out;
}

export function readThreads(dir = path.join(VAULT, 'board', 'threads')) {
  let names;
  try { names = fs.readdirSync(dir).filter((n) => n.endsWith('.md')); } catch { return []; }
  return names.map((n) => ({ ...frontmatter(fs.readFileSync(path.join(dir, n), 'utf8')), name: n.slice(0, -3) }));
}

// The owner's last weekly review: the latest Vault commit titled `board: weekly review` (the
// orchestrate skill makes it, empty when nothing changed). '' when there is none.
export function lastReview(vault = VAULT) {
  try {
    return execFileSync('git', ['-C', vault, 'log', '-1', '--format=%cs', '--grep=^board: weekly review'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 5000 }).trim();
  } catch { return ''; }
}

const text = (v) => (Array.isArray(v) ? '' : String(v ?? '').trim());
const items = (v) => (Array.isArray(v) ? v : text(v) ? [text(v)] : []);
const clip = (s, n) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);

// The repo a cwd belongs to, named as threads name projects: WebApp, PNGTools, Workspace.
export function projectOf(cwd, workspace = WORKSPACE) {
  const rel = path.relative(workspace.toLowerCase(), path.resolve(cwd).toLowerCase());
  if (rel.startsWith('..') || path.isAbsolute(rel)) return null;
  const real = path.relative(workspace, path.resolve(cwd)).split(/[\\/]/).filter(Boolean);
  if (!real.length || real[0] === '.claude') return 'Workspace';
  return real[0] === 'PostProcess' && real[1] ? real[1] : real[0];
}

export function summary(threads, { reviewed, project, today = new Date() } = {}) {
  const open = threads.filter((t) => t.state !== 'done');
  const mark = (t) => (project && t.project === project ? ' (this repo)' : '');
  const now = open.filter((t) => t.state === 'now')
    .sort((a, b) => (Number(a.rank) || 99) - (Number(b.rank) || 99) || a.name.localeCompare(b.name));
  // Parked threads keep their asks for the weekly review; only Now and Next ones wait on the owner.
  // A repo session gets its own repo's asks and a count of the rest; the workspace root gets all.
  const asking = open.filter((t) => t.state === 'now' || t.state === 'next')
    .sort((a, b) => (a.state === 'now' ? 0 : 1) - (b.state === 'now' ? 0 : 1)
      || (Number(a.rank) || 99) - (Number(b.rank) || 99) || a.name.localeCompare(b.name));
  const shown = (t) => !project || project === 'Workspace' || t.project === project;
  const asks = asking.filter(shown)
    .flatMap((t) => items(t.asks).map((a) => `- ${t.name}${mark(t)}: ${clip(a, 140)}`));
  const elsewhere = asking.filter((t) => !shown(t)).reduce((n, t) => n + items(t.asks).length, 0);
  const lines = [];
  if (now.length) {
    lines.push('Now:');
    for (const t of now) {
      const next = text(t.next) && ` — next: ${clip(text(t.next), 110)}`;
      const blocked = text(t.blocker) && ` — blocked: ${clip(text(t.blocker), 80)}`;
      lines.push(`- ${t.name}${mark(t)}${next}${blocked}`);
    }
  }
  if (asks.length) lines.push('Waiting on the owner:', ...asks);
  if (elsewhere) lines.push(`Also waiting on the owner: ${elsewhere} ask${elsewhere === 1 ? '' : 's'} on other repos' threads (Board.md).`);
  const days = reviewed ? Math.floor((today - new Date(`${reviewed}T00:00:00`)) / 86400000) : NaN;
  const due = Number.isFinite(days) && days > REVIEW_DAYS;
  if (!lines.length && !due) return '';
  if (due) lines.push(`Board review due: last reviewed ${reviewed}.`);
  return [
    'Board (C:\\GSADUs\\Vault\\Board.md; threads in Vault\\board\\threads\\, schema in Vault\\AGENTS.md → Board):',
    ...lines,
    'If this session works on one of these threads, its /handoff updates that note. Only the owner opens new threads. ' +
      'Mention the owner\'s asks for this repo, or an overdue review, in one line when relevant.',
  ].join('\n');
}

function render(cwd) {
  const project = projectOf(cwd);
  if (!project) return '';
  return summary(readThreads(), { reviewed: lastReview(), project });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv[2] === 'hook') {
    let input = {};
    try { const raw = fs.readFileSync(0, 'utf8'); input = raw.trim() ? JSON.parse(raw) : {}; } catch { /* no input */ }
    let context;
    try { context = render(String(input.cwd ?? process.cwd())); } catch (e) { context = `Board unavailable (${clip(String(e?.message ?? e), 140)}).`; }
    if (context) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: { hookEventName: input.hook_event_name ?? 'SessionStart', additionalContext: context },
      }));
    }
  } else {
    console.log(render(process.cwd()) || 'Board: nothing open.');
  }
}
