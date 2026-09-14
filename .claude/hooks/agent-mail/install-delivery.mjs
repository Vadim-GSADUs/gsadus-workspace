// Merge only Agent Mail handlers, preserving every unrelated hook and permission.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

export function mergeHooks(config, program, script) {
  const next = structuredClone(config);
  next.hooks ||= {};
  for (const [event, groups] of Object.entries(next.hooks)) {
    next.hooks[event] = groups.map(group => ({ ...group, hooks: group.hooks.filter(h =>
      !/agent-mail[\\/]+(?:SessionStart-AgentMail\.ps1|delivery\.mjs)/i.test(h.command || ''))
    })).filter(group => group.hooks.length);
  }
  for (const event of ['SessionStart', 'UserPromptSubmit', 'PostToolUse', 'Stop']) {
    const handler = { type: 'command', command: `node "${script}" hook ${program}`, timeout: 15 };
    // Codex commands on Windows use its default PowerShell; Claude can choose the shell explicitly.
    if (program === 'claude-code') handler.shell = 'powershell';
    else handler.statusMessage = 'Checking session Agent Mail';
    (next.hooks[event] ||= []).push({ ...(event === 'PostToolUse' ? { matcher: '.*' } : {}), hooks: [handler] });
  }
  return next;
}
export function install({ workspace = 'C:\\GSADUs', home = os.homedir(), apply = false, projectOnly = false, scriptRoot = workspace } = {}) {
  const script = path.join(scriptRoot, '.claude', 'hooks', 'agent-mail', 'delivery.mjs');
  const targets = [{ file: path.join(workspace, '.claude', 'settings.json'), program: 'claude-code' }];
  if (!projectOnly) targets.push(
    { file: path.join(home, '.claude', 'settings.json'), program: 'claude-code' },
    { file: path.join(home, '.codex', 'hooks.json'), program: 'codex-cli' });
  return targets.map(({ file, program }) => {
    const before = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '{}';
    const config = JSON.parse(before.replace(/^\uFEFF/, ''));
    const next = mergeHooks(config, program, script);
    const changed = JSON.stringify(config) !== JSON.stringify(next);
    if (apply && changed) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      // Timestamped backup allows an exact reversal, including unrelated settings.
      fs.writeFileSync(`${file}.agent-mail-backup-${Date.now()}`, before, { flag: 'wx' });
      const temp = `${file}.agent-mail.tmp`;
      fs.writeFileSync(temp, JSON.stringify(next, null, 2) + '\n');
      fs.renameSync(temp, file);
    }
    return { file, program, changed, applied: apply && changed, events: ['SessionStart', 'UserPromptSubmit', 'PostToolUse', 'Stop'], script };
  });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const val = flag => args.includes(flag) ? args[args.indexOf(flag) + 1] : undefined;
  console.log(JSON.stringify(install({ workspace: val('--workspace'), home: val('--home'), scriptRoot: val('--script-root'),
    projectOnly: args.includes('--project-only'), apply: args.includes('--apply') }), null, 2));
}
