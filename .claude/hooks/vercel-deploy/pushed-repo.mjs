// Which checkout a shell command pushed, parsed from its text (watch.mjs; pushed-repo.test.mjs).
import path from 'node:path';

const PUSH = /\bgit\s+(?:-C\s+\S+\s+)?push\b/;
const DIR = /(?:\bcd|\bSet-Location|\bgit\s+-C)\s+("[^"]+"|'[^']+'|[^\s;&|]+)/g;

// Git Bash hands out /c/... paths; node on Windows needs C:/...
export const nativePath = (p) => p.replace(/^["']|["']$/g, '').replace(/^\/([a-zA-Z])\//, (_, d) => `${d.toUpperCase()}:/`);

/** The repo a pushing command acted on (the last `cd` / `Set-Location` / `git -C` up to and
 *  including `git push`, else the session cwd), or null when the command did not push. */
export function pushedRepo(command, cwd, branch = 'main') {
  const push = command.match(PUSH);
  if (!push || /\bpush\b[^\n;&|]*--dry-run/.test(command)) return null;
  const dirs = [...command.slice(0, push.index + push[0].length).matchAll(DIR)].map((m) => nativePath(m[1]));
  return {
    dir: dirs.length ? path.resolve(cwd, dirs[dirs.length - 1]) : cwd,
    namesMain: new RegExp(`\\bpush\\b[^\\n;&|]*(?:\\s|:)${branch}\\b`).test(command),
  };
}
