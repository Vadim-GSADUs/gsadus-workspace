// Register the board as a SessionStart hook for Claude Code (user settings) and Codex (user
// hooks.json) on this machine. Every session under C:\GSADUs, including sub-repos and worktrees,
// then opens with the owner's Now threads and asks (board.mjs). Only this handler is touched;
// every unrelated hook and setting is kept.
//   node C:\GSADUs\.claude\hooks\board\install.mjs          # show the plan
//   node C:\GSADUs\.claude\hooks\board\install.mjs --apply  # write it (timestamped backups first)
// Codex also needs the new definition trusted once in its /hooks review.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT = path.join(path.dirname(fileURLToPath(import.meta.url)), 'board.mjs');
const OURS = /hooks[\\/]+board[\\/]+board\.mjs/i;

export function mergeHook(config, program, script = SCRIPT) {
  const next = structuredClone(config);
  next.hooks ||= {};
  for (const [event, groups] of Object.entries(next.hooks)) {
    next.hooks[event] = groups.map((group) => ({ ...group, hooks: group.hooks.filter((h) => !OURS.test(h.command || '')) }))
      .filter((group) => group.hooks.length);
  }
  const handler = { type: 'command', command: `node "${script}" hook`, timeout: 10 };
  // Codex commands on Windows use its default PowerShell; Claude can choose the shell explicitly.
  if (program === 'claude') handler.shell = 'powershell';
  else handler.statusMessage = 'Reading the board';
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
    fs.writeFileSync(`${file}.board-backup-${Date.now()}`, before, { flag: 'wx' });
    const temp = `${file}.board.tmp`;
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
  console.log(JSON.stringify({ script: SCRIPT, results }, null, 2));
  if (apply && results.some((r) => r.program === 'codex' && r.applied)) {
    console.log('Codex: trust the new SessionStart hook once in /hooks before it runs.');
  }
}
