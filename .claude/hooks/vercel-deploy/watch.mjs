#!/usr/bin/env node
// PostToolUse hook (Bash|PowerShell, asyncRewake): after a push of `main` in WebApp or PM,
// run the workspace's deployment waiter and wake the agent with the outcome.
//
// The waiting itself is Tools/Vercel/Wait-Deployment.ps1 (the one implementation, tested
// with a CLI double; see its README). This file only decides WHEN to run it, so no agent
// has to remember: exit 0 at once for every other command (no wake), otherwise wait in the
// background and exit 2 with the result on stderr, which wakes the agent (Ready or not).
// Installed per machine by install.mjs into the user-level settings (2026-09-23).
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const WAITER = 'C:/GSADUs/Tools/Vercel/Wait-Deployment.ps1';
const PROJECTS = { webapp: 'WebApp', pm: 'PM' }; // repo folder → the waiter's -Project
const BRANCH = 'main';

const git = (args, cwd) => { try { return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); } catch { return null; } };
// Git Bash hands out /c/... paths; node on Windows needs C:/...
const nativePath = (p) => p.replace(/^["']|["']$/g, '').replace(/^\/([a-zA-Z])\//, '$1:/');

/** The repo a pushing command acted on (the last `cd` / `Set-Location` / `git -C` before
 *  `git push`, else the session cwd), or null when the command did not push. */
export function pushedRepo(command, cwd) {
  const at = command.search(/\bgit\s+(?:-C\s+\S+\s+)?push\b/);
  if (at < 0 || /\bpush\b[^\n;&|]*--dry-run/.test(command)) return null;
  const dirs = [...command.slice(0, at + 40).matchAll(/(?:\bcd|\bSet-Location|\bgit\s+-C)\s+("[^"]+"|'[^']+'|[^\s;&|]+)/g)].map((m) => nativePath(m[1]));
  return {
    dir: dirs.length ? path.resolve(cwd, dirs[dirs.length - 1]) : cwd,
    namesMain: new RegExp(`\\bpush\\b[^\\n;&|]*(?:\\s|:)${BRANCH}\\b`).test(command),
  };
}

let payload;
try { payload = JSON.parse(fs.readFileSync(0, 'utf8') || '{}'); } catch { process.exit(0); }
if (!['Bash', 'PowerShell'].includes(payload.tool_name)) process.exit(0);
const push = pushedRepo(String(payload.tool_input?.command ?? ''), nativePath(payload.cwd || process.cwd()));
if (!push) process.exit(0);
const top = git(['rev-parse', '--show-toplevel'], push.dir);
if (!top) process.exit(0);
// A worktree's common dir is the main checkout's .git, so worktree pushes map too.
const common = git(['rev-parse', '--path-format=absolute', '--git-common-dir'], top);
const project = PROJECTS[path.basename(path.dirname(common ?? top)).toLowerCase()] ?? PROJECTS[path.basename(top).toLowerCase()];
if (!project) process.exit(0);
if (!push.namesMain && git(['rev-parse', '--abbrev-ref', 'HEAD'], top) !== BRANCH) process.exit(0);
const sha = git(['rev-parse', `origin/${BRANCH}`], top);
if (!sha) process.exit(0);

// One watcher per commit, however many sessions or settings files fire this hook.
const lock = path.join(os.tmpdir(), `vercel-deploy-watch-${project}-${sha.slice(0, 12)}.lock`);
try { if (Date.now() - fs.statSync(lock).mtimeMs < 30 * 60_000) process.exit(0); fs.rmSync(lock, { force: true }); } catch { /* no lock yet */ }
try { fs.writeFileSync(lock, String(process.pid), { flag: 'wx' }); } catch { process.exit(0); }

const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', WAITER, '-Project', project, '-Commit', sha], { encoding: 'utf8' });
let summary;
try {
  const r = JSON.parse(run.stdout.slice(run.stdout.indexOf('{')));
  summary = `READY ${project} ${sha.slice(0, 7)} — ${r.url} (${r.deploymentId}), waited ${r.elapsedSeconds}s`;
} catch {
  summary = `NOT READY ${project} ${sha.slice(0, 7)} — ${(run.stderr || run.error?.message || `waiter exit ${run.status}`).trim().split('\n').slice(-2).join(' | ')}`;
}
process.stderr.write(`Vercel production deploy (hook): ${summary}\n`);
process.exit(2); // wake the agent with the outcome, Ready or not
