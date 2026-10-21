#!/usr/bin/env node
// PostToolUse hook (Bash|PowerShell, asyncRewake): after a push of `main` in WebApp or PM,
// run the workspace's deployment waiter and wake the agent with the outcome.
//
// The waiting itself is Tools/Vercel/Wait-Deployment.ps1 (the one implementation, tested
// with a CLI double; see its README). It follows every Vercel project the repo deploys:
// WebApp's App and Site, PM. This file only decides WHEN to run it, so no agent has to
// remember: exit 0 at once for every other command (no wake), otherwise wait in the
// background and exit 2 with the result on stderr, which wakes the agent (deployed or not).
// Installed per machine by install.mjs, in exec form so Claude Code sees that exit 2 (README).
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { nativePath, pushedRepo } from './pushed-repo.mjs';

const WAITER = 'C:/GSADUs/Tools/Vercel/Wait-Deployment.ps1';
const PROJECTS = { webapp: 'WebApp', pm: 'PM' }; // repo folder → the waiter's -Project
const BRANCH = 'main';

const git = (args, cwd) => { try { return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); } catch { return null; } };

let payload;
try { payload = JSON.parse(fs.readFileSync(0, 'utf8') || '{}'); } catch { process.exit(0); }
if (!['Bash', 'PowerShell'].includes(payload.tool_name)) process.exit(0);
const push = pushedRepo(String(payload.tool_input?.command ?? ''), nativePath(payload.cwd || process.cwd()), BRANCH);
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
// Only a push that landed: origin/main is now this checkout's HEAD. A rejected push, or one
// still running in the background, leaves it on an older commit that is already deployed.
if (git(['rev-parse', 'HEAD'], top) !== sha) process.exit(0);

// One watcher per commit, however many sessions or settings files fire this hook. Locks
// older than a week are swept, so the temp dir does not keep one per push.
const tmp = os.tmpdir();
for (const name of fs.readdirSync(tmp).filter((n) => /^vercel-deploy-watch-.+\.lock$/.test(n))) {
  try { if (Date.now() - fs.statSync(path.join(tmp, name)).mtimeMs > 7 * 86_400_000) fs.rmSync(path.join(tmp, name), { force: true }); } catch { /* raced */ }
}
const lock = path.join(tmp, `vercel-deploy-watch-${project}-${sha.slice(0, 12)}.lock`);
try { if (Date.now() - fs.statSync(lock).mtimeMs < 30 * 60_000) process.exit(0); fs.rmSync(lock, { force: true }); } catch { /* no lock yet */ }
// The lock is also this watcher's record, so a lost wake can be told apart afterwards: no lock,
// it never ran; no `exit`, it was killed first; `exit` 2 and no wake in the session's
// transcript, Claude Code dropped it (README → Known limits).
const record = { pid: process.pid, session: payload.session_id ?? null, started: new Date().toISOString() };
try { fs.writeFileSync(lock, JSON.stringify(record), { flag: 'wx' }); } catch { process.exit(0); }

const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', WAITER, '-Project', project, '-Commit', sha], { encoding: 'utf8' });
let report;
try { report = JSON.parse(run.stdout.slice(run.stdout.indexOf('{'))); } catch { /* it failed before it had results */ }
// READY is live; CANCELED was not built (its ignoreCommand skipped the push, or someone
// canceled it), which is fine; any other end state failed (the waiter exits 1).
const said = (d) => d.state === 'READY' ? `${d.project} READY ${d.url} (${d.deploymentId})`
  : d.state === 'CANCELED' ? `${d.project} not built (CANCELED: skipped by its ignore step or canceled; production keeps its previous build)`
  : `${d.project} FAILED (${d.state}) ${d.url}, build logs: vercel inspect ${d.url} --logs`;
const summary = report?.deployments
  ? `${run.status === 0 ? 'deployed' : 'FAILED'} ${project} ${sha.slice(0, 7)} after ${report.elapsedSeconds}s: ${report.deployments.map(said).join('; ')}`
  : `NOT READY ${project} ${sha.slice(0, 7)}: ${(run.stderr || run.error?.message || `waiter exit ${run.status}`).trim().split('\n').slice(-2).join(' | ')}`;
process.stderr.write(`Vercel production deploy (hook): ${summary}\n`);
try { fs.writeFileSync(lock, JSON.stringify({ ...record, ended: new Date().toISOString(), waiter: run.status, exit: 2, summary })); } catch { /* the wake matters more */ }
process.exit(2); // wake the agent with the outcome, deployed or not
