// node --test .claude/hooks/vercel-deploy/pushed-repo.test.mjs
import assert from 'node:assert/strict';
import path from 'node:path';
import test from 'node:test';
import { pushedRepo } from './pushed-repo.mjs';

const cwd = 'C:/GSADUs/WebApp';
const cases = [
  ['git push origin main', { dir: cwd, namesMain: true }],
  ['cd /c/GSADUs/PM && git push', { dir: path.resolve('C:/GSADUs/PM'), namesMain: false }],
  ['Set-Location "C:\\GSADUs\\PM"; git push origin main', { dir: path.resolve('C:\\GSADUs\\PM'), namesMain: true }],
  // A long -C path was cut at 40 characters past the push and the hook stood down (2026-10-14).
  ['git -C /c/GSADUs/WebApp/.claude/worktrees/guard-exec-form push origin HEAD:main 2>&1 | tail -2',
    { dir: path.resolve('C:/GSADUs/WebApp/.claude/worktrees/guard-exec-form'), namesMain: true }],
  ['cd /c/GSADUs/WebApp && git push origin main; cd /c/GSADUs/PM', { dir: path.resolve(cwd), namesMain: true }],
  ['git push --dry-run origin main', null],
  ['git status', null],
];
for (const [command, expected] of cases) {
  test(command, () => assert.deepEqual(pushedRepo(command, cwd), expected));
}
