// Register the helpdesk status line as a SessionStart hook for Claude Code (user settings) and
// Codex (user hooks.json) on this machine. Every session under C:\GSADUs, including sub-repos
// and worktrees, then opens with e.g. "Helpdesk: 2 new (1 blocking) · 1 to approve". The
// handler stays silent when nothing is open or when the session is outside the workspace.
// Only this handler is touched; every unrelated hook and setting is kept.
//   node C:\GSADUs\.claude\hooks\helpdesk\install.mjs          # show the plan
//   node C:\GSADUs\.claude\hooks\helpdesk\install.mjs --apply  # write it (timestamped backups first)
// Codex also needs the new definition trusted once in its /hooks review.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const CLI = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..', 'Tools', 'Helpdesk', 'helpdesk.mjs');
const OURS = /Helpdesk[\\/]+helpdesk\.mjs"?\s+status\s+--hook/i;

export function mergeHook(config, program, cli = CLI) {
  const next = structuredClone(config);
  next.hooks ||= {};
  for (const [event, groups] of Object.entries(next.hooks)) {
    next.hooks[event] = groups.map((group) => ({ ...group, hooks: group.hooks.filter((h) => !OURS.test(h.command || '')) }))
      .filter((group) => group.hooks.length);
  }
  const handler = { type: 'command', command: `node "${cli}" status --hook ${program}`, timeout: 20 };
  // Codex commands on Windows use its default PowerShell; Claude can choose the shell explicitly.
  if (program === 'claude') handler.shell = 'powershell';
  else handler.statusMessage = 'Checking the helpdesk';
  (next.hooks.SessionStart ||= []).push({ hooks: [handler] });
  return next;
}

function plan(file, program, apply) {
  const before = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '{}';
  const config = JSON.parse(before.replace(/^\uFEFF/, ''));
  const next = mergeHook(config, program);
  const changed = JSON.stringify(config) !== JSON.stringify(next);
  if (apply && changed) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(`${file}.helpdesk-backup-${Date.now()}`, before, { flag: 'wx' });
    const temp = `${file}.helpdesk.tmp`;
    fs.writeFileSync(temp, JSON.stringify(next, null, 2) + '\n');
    fs.renameSync(temp, file);
  }
  return { file, program, changed, applied: apply && changed };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const apply = process.argv.includes('--apply');
  const home = os.homedir();
  const results = [
    plan(path.join(home, '.claude', 'settings.json'), 'claude', apply),
    plan(path.join(home, '.codex', 'hooks.json'), 'codex', apply),
  ];
  console.log(JSON.stringify({ cli: CLI, results }, null, 2));
  if (apply && results.some((r) => r.program === 'codex' && r.applied)) {
    console.log('Codex: trust the new SessionStart hook once in /hooks before it runs.');
  }
}
