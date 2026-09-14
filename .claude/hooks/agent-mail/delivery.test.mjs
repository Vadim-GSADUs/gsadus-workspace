import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { runHook, bindSession, stateFile, canonicalProject, rpc } from './delivery.mjs';
import { mergeHooks, install } from './install-delivery.mjs';

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mail-delivery-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  let inbox = [], count = 0, time = 100000;
  const calls = [];
  const call = async (name, args) => {
    calls.push({ name, args });
    if (name === 'ensure_project') return {};
    if (name === 'list_agents') return [];
    if (name === 'register_agent') return { name: `BlueBird${++count}`, registration_token: 'NEVER-ECHO-ME' };
    if (name === 'whois') return { name: args.agent_name, program: 'codex-cli' };
    if (name === 'fetch_inbox') return inbox;
    throw new Error(name);
  };
  const options = { root, workspace: root, project: () => root, call, now: () => time };
  const input = { session_id: 'session-1', cwd: root, hook_event_name: 'SessionStart' };
  return { root, input, options, calls, setInbox: value => { inbox = value; }, tick: () => { time += 6000; } };
}
const message = id => ({ id, from: 'RoseMoose', subject: `message ${id}`, body_md: 'peer request', ack_required: true });
test('auto-registration is isolated per session and never emits registration tokens', async t => {
  const f = fixture(t);
  const first = await runHook(f.input, 'codex-cli', f.options);
  assert.match(JSON.stringify(first), /BlueBird1/);
  assert.doesNotMatch(JSON.stringify(first), /NEVER-ECHO/);
  await runHook({ ...f.input, session_id: 'session-2' }, 'codex-cli', f.options);
  const one = JSON.parse(fs.readFileSync(stateFile('codex-cli', 'session-1', f.root)));
  const two = JSON.parse(fs.readFileSync(stateFile('codex-cli', 'session-2', f.root)));
  assert.notEqual(one.agent, two.agent);
  assert.doesNotMatch(JSON.stringify(one), /NEVER-ECHO/);
});
test('new mail arrives at a tool boundary, only once, without changing server read state', async t => {
  const f = fixture(t);
  await runHook(f.input, 'codex-cli', f.options);
  f.setInbox([message(4)]); f.tick();
  const tool = { ...f.input, hook_event_name: 'PostToolUse' };
  const result = await runHook(tool, 'codex-cli', f.options);
  assert.match(result.hookSpecificOutput.additionalContext, /message 4/);
  f.tick(); assert.deepEqual(await runHook(tool, 'codex-cli', f.options), {});
  assert(f.calls.filter(c => c.name === 'fetch_inbox').every(c => c.args.mark_read === false));
  assert(!f.calls.some(c => /acknowledge|mark_message/.test(c.name)));
});
test('tool bursts are throttled while user input always checks', async t => {
  const f = fixture(t); await runHook(f.input, 'codex-cli', f.options);
  const before = f.calls.length;
  await runHook({ ...f.input, hook_event_name: 'PostToolUse' }, 'codex-cli', f.options);
  assert.equal(f.calls.length, before);
  await runHook({ ...f.input, hook_event_name: 'UserPromptSubmit' }, 'codex-cli', f.options);
  assert.equal(f.calls.length, before + 1);
});
test('stop continues for pending mail once, then defers new mail rather than looping', async t => {
  const f = fixture(t); await runHook(f.input, 'codex-cli', f.options);
  f.setInbox([message(8)]);
  const stop = { ...f.input, hook_event_name: 'Stop' };
  assert.equal((await runHook(stop, 'codex-cli', f.options)).decision, 'block');
  f.setInbox([message(8), message(9)]);
  assert.deepEqual(await runHook({ ...stop, stop_hook_active: true }, 'codex-cli', f.options), {});
  f.tick();
  assert.match((await runHook({ ...f.input, hook_event_name: 'PostToolUse' }, 'codex-cli', f.options)).hookSpecificOutput.additionalContext, /message 9/);
});
test('body is bounded, excess messages remain available on later hooks', async t => {
  const f = fixture(t);
  f.setInbox(Array.from({ length: 8 }, (_, i) => ({ ...message(i + 1), body_md: 'x'.repeat(4000) })));
  const first = await runHook(f.input, 'codex-cli', f.options);
  assert(JSON.stringify(first).length < 11000);
  f.tick();
  const next = await runHook({ ...f.input, hook_event_name: 'PostToolUse' }, 'codex-cli', f.options);
  assert.match(next.hookSpecificOutput.additionalContext, /message 6/);
  assert.doesNotMatch(next.hookSpecificOutput.additionalContext, /message 1/);
});
test('server failure does not advance delivery state and a later hook retries', async t => {
  const f = fixture(t); await runHook(f.input, 'codex-cli', f.options); f.tick();
  await assert.rejects(runHook(f.input, 'codex-cli', { ...f.options, call: async () => { throw new Error('offline'); } }));
  f.setInbox([message(10)]);
  assert.match((await runHook(f.input, 'codex-cli', f.options)).hookSpecificOutput.additionalContext, /message 10/);
});
test('unrelated folders and child agents are ignored', async t => {
  const f = fixture(t);
  assert.deepEqual(await runHook({ ...f.input, cwd: path.dirname(f.root) }, 'codex-cli', f.options), {});
  assert.deepEqual(await runHook({ ...f.input, agent_id: 'child' }, 'codex-cli', f.options), {});
  assert.equal(f.calls.length, 0);
});
test('explicit adoption preserves the original identity and forbids sharing across sessions', async t => {
  const f = fixture(t);
  const args = { root: f.root, call: f.options.call, program: 'codex-cli', session: 'session-1', project: f.root, agent: 'TealDesert' };
  await bindSession(args);
  await assert.rejects(bindSession({ ...args, session: 'session-2' }), /already bound/);
  assert.match((await runHook(f.input, 'codex-cli', f.options)).hookSpecificOutput.additionalContext, /TealDesert/);
  assert(!f.calls.some(c => c.name === 'register_agent'));
});
test('installer preserves unrelated hooks, removes old mail handler and is idempotent', () => {
  const before = { permissions: { allow: ['test'] }, hooks: { SessionStart: [{ hooks: [
    { type: 'command', command: 'existing-command' },
    { type: 'command', command: 'pwsh C:\\GSADUs\\.claude\\hooks\\agent-mail\\SessionStart-AgentMail.ps1' } ] }] } };
  const script = 'C:\\GSADUs\\.claude\\hooks\\agent-mail\\delivery.mjs';
  const next = mergeHooks(before, 'claude-code', script);
  assert.deepEqual(next.permissions, before.permissions);
  assert.equal(next.hooks.SessionStart[0].hooks[0].command, 'existing-command');
  assert.doesNotMatch(JSON.stringify(next), /SessionStart-AgentMail/);
  assert.deepEqual(mergeHooks(next, 'claude-code', script), next);
});
test('installer dry run changes nothing and repeat installation has no changes', t => {
  const f = fixture(t);
  const args = { workspace: f.root, home: path.join(f.root, 'home') };
  install(args);
  assert(!fs.existsSync(path.join(f.root, '.claude', 'settings.json')));
  assert(install({ ...args, apply: true }).every(x => x.applied));
  assert(install({ ...args, apply: true }).every(x => !x.changed));
});
test('git worktree resolves to the main repository mailbox', () => {
  assert.equal(canonicalProject(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1'))).toLowerCase(), 'c:\\gsadus');
});
test('concurrent copies of a hook do not register or deliver twice', async t => {
  const f = fixture(t); f.setInbox([message(11)]);
  const results = await Promise.all([runHook(f.input, 'codex-cli', f.options), runHook(f.input, 'codex-cli', f.options)]);
  assert.equal(results.filter(r => r.hookSpecificOutput).length, 1);
  assert.equal(f.calls.filter(c => c.name === 'register_agent').length, 1);
});
test('uncertain registration is recovered by the exact session marker', async t => {
  const f = fixture(t);
  const call = async (name, args) => name === 'list_agents' ? [
    { name: 'RecoveredBird', program: 'codex-cli', task_description: `${path.basename(f.root)}: session session-1` },
    { name: 'OtherBird', program: 'codex-cli', task_description: `${path.basename(f.root)}: session session-2` },
  ] : f.options.call(name, args);
  const output = await runHook(f.input, 'codex-cli', { ...f.options, call });
  assert.match(output.hookSpecificOutput.additionalContext, /RecoveredBird/);
  assert.doesNotMatch(output.hookSpecificOutput.additionalContext, /OtherBird/);
  assert(!f.calls.some(c => c.name === 'register_agent'));
});
test('MCP transport accepts JSON and SSE and rejects tool errors', async t => {
  let mode = 'json';
  const server = http.createServer(async (req, res) => {
    let body = ''; for await (const chunk of req) body += chunk;
    assert.equal(JSON.parse(body).params.name, 'fetch_inbox');
    const data = { jsonrpc: '2.0', id: 1, result: { isError: mode === 'error', content: [{ type: 'text', text: JSON.stringify([message(12)]) }] } };
    res.setHeader('Content-Type', mode === 'sse' ? 'text/event-stream' : 'application/json');
    res.end(mode === 'sse' ? `event: message\ndata: ${JSON.stringify(data)}\n\n` : JSON.stringify(data));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const endpoint = `http://127.0.0.1:${server.address().port}/mcp/`;
  assert.equal((await rpc('fetch_inbox', {}, endpoint))[0].id, 12);
  mode = 'sse'; assert.equal((await rpc('fetch_inbox', {}, endpoint))[0].id, 12);
  mode = 'error'; await assert.rejects(rpc('fetch_inbox', {}, endpoint));
});
