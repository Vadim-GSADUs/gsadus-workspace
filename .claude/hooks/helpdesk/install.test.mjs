import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mergeHook } from './install.mjs';

const CLI = 'C:\\GSADUs\\Tools\\Helpdesk\\helpdesk.mjs';
const unrelated = {
  model: 'x',
  hooks: {
    SessionStart: [{ hooks: [{ type: 'command', command: 'node "C:\\GSADUs\\.claude\\hooks\\agent-mail\\delivery.mjs" hook claude-code' }] }],
    PostToolUse: [{ matcher: 'Bash', hooks: [{ type: 'command', command: 'node watch.mjs hook' }] }],
  },
};

test('adds one SessionStart handler per harness and keeps everything else', () => {
  const claude = mergeHook(unrelated, 'claude', CLI);
  assert.equal(claude.model, 'x');
  assert.deepEqual(claude.hooks.PostToolUse, unrelated.hooks.PostToolUse);
  assert.equal(claude.hooks.SessionStart.length, 2);
  assert.deepEqual(claude.hooks.SessionStart[1].hooks[0],
    { type: 'command', command: `node "${CLI}" status --hook claude`, timeout: 20, shell: 'powershell' });
  const codex = mergeHook(unrelated, 'codex', CLI);
  assert.equal(codex.hooks.SessionStart[1].hooks[0].command, `node "${CLI}" status --hook codex`);
  assert.equal(codex.hooks.SessionStart[1].hooks[0].shell, undefined);
});

test('re-running is idempotent and replaces an older definition', () => {
  const once = mergeHook(unrelated, 'claude', CLI);
  assert.deepEqual(mergeHook(once, 'claude', CLI), once);
  const moved = mergeHook(once, 'claude', 'D:\\Elsewhere\\Tools\\Helpdesk\\helpdesk.mjs');
  assert.equal(moved.hooks.SessionStart.length, 2);
  assert.match(moved.hooks.SessionStart[1].hooks[0].command, /D:\\Elsewhere/);
});
