// Register the Vercel deploy watcher in the user-level Claude Code settings, so every
// session on this machine (WebApp, PM, the workspace, any worktree) is woken when a push
// to main is live. Merges only this handler; every unrelated hook and setting is kept.
//   node C:\GSADUs\.claude\hooks\vercel-deploy\install.mjs          # show the plan
//   node C:\GSADUs\.claude\hooks\vercel-deploy\install.mjs --apply  # write it (backup first)
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = path.join(path.dirname(fileURLToPath(import.meta.url)), 'watch.mjs');
const OURS = /vercel-deploy[\\/]+watch\.mjs/i;

export function mergeHook(config, script = SCRIPT) {
  const next = structuredClone(config);
  next.hooks ||= {};
  for (const [event, groups] of Object.entries(next.hooks)) {
    next.hooks[event] = groups.map((group) => ({ ...group, hooks: group.hooks.filter((h) => !OURS.test(h.command || '')) }))
      .filter((group) => group.hooks.length);
  }
  // asyncRewake: runs in the background and wakes the agent on exit 2 (the outcome).
  (next.hooks.PostToolUse ||= []).push({ matcher: 'Bash|PowerShell', hooks: [{
    type: 'command', command: `node "${script}" hook`, shell: 'powershell', asyncRewake: true, timeout: 1200,
  }] });
  return next;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const apply = process.argv.includes('--apply');
  const file = path.join(os.homedir(), '.claude', 'settings.json');
  const before = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '{}';
  const config = JSON.parse(before.replace(/^\uFEFF/, ''));
  const next = mergeHook(config);
  const changed = JSON.stringify(config) !== JSON.stringify(next);
  if (apply && changed) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(`${file}.vercel-deploy-backup-${Date.now()}`, before, { flag: 'wx' });
    const temp = `${file}.vercel-deploy.tmp`;
    fs.writeFileSync(temp, JSON.stringify(next, null, 2) + '\n');
    fs.renameSync(temp, file);
  }
  console.log(JSON.stringify({ file, script: SCRIPT, changed, applied: apply && changed }, null, 2));
}
