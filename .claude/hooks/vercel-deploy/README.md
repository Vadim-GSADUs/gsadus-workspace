# Vercel deploy hook

A user-level Claude Code `PostToolUse` hook (`Bash|PowerShell`, `asyncRewake`). After a
`git push` of `main` in WebApp or PM, from the main checkout or any worktree, it runs
[`Tools/Vercel/Wait-Deployment.ps1`](../../../Tools/Vercel/README.md) in the background and
wakes the session that pushed once every Vercel project for that commit is done:

| Repo | Vercel projects it waits on |
|---|---|
| WebApp | `gsadus` (the App, repo root) and `gsadus-site` (the Site, `apps/site`) |
| PM | `gsadus-pm` |

The wake is one system reminder, `Vercel production deploy (hook): …`, naming each project:
**READY** with its URL, **not built** (CANCELED: its `ignoreCommand` skipped the push, or it
was canceled; production keeps its previous build, which is fine), or **FAILED** with its
build-log command. The reminder opens with "deployed" or "FAILED", or "NOT READY" when the
waiter could not get results (no deployment, auth, timeout). Every outcome wakes the session.

**WebApp's two projects are watched on every push**, not only when the Site's paths changed.
Each project's ignore step diffs against its own last *successful* deployment, not against
the push, so either project can build (or fail) on a push that did not touch its files. On
2026-10-07/08 the Site's ignore step itself crashed on 21 App-only pushes, and nothing
reported it ([WebApp 9922bbbe](https://github.com/Vadim-GSADUs/gsadus-web-app/commit/9922bbbe)).

## When it fires

- The command contains `git push` (not `--dry-run`); the repo is the last `cd` /
  `Set-Location` / `git -C` before it, else the session's cwd.
- It names `main` (`origin main`, `HEAD:main`), or the checkout is on `main`.
- The push landed: `origin/main` now equals that checkout's `HEAD`. A rejected push, or one
  started with `run_in_background`, leaves `origin/main` on an older commit, and the hook
  stays quiet. Push in the foreground to be watched.
- One watcher per commit: a lock in the temp dir (`vercel-deploy-watch-<repo>-<sha12>.lock`)
  skips repeats for 30 minutes; locks older than a day are swept.

## Install (per machine)

```powershell
node C:\GSADUs\.claude\hooks\vercel-deploy\install.mjs          # show the plan
node C:\GSADUs\.claude\hooks\vercel-deploy\install.mjs --apply  # write it (backup first)
```

It merges one entry into `~\.claude\settings.json`, replacing any earlier one, in **exec
form**: `"command": "node", "args": ["…\\watch.mjs", "hook"]`, no `shell`. That form is the
fix of 2026-10-14. `asyncRewake` wakes the model only when the hook exits 2. Before then the
entry used `"shell": "powershell"`, which Claude Code runs as `pwsh -NoProfile -NonInteractive
-ExecutionPolicy Bypass -Command "<command>"`, and `pwsh -Command` turns a native program's
exit 2 into 1. So from 2026-09-23 to 2026-10-14 every waiter ran and finished, and every
result was dropped as a non-blocking hook error: no transcript on gsadus-vadim holds a single
wake. Never put a shell between Claude Code and an exit code it acts on. Verified against
Claude Code 2.1.295 (the desktop app) and 2.1.234 (the terminal CLI), which both support the
exec form.

## Testing it without a push

Run a command whose text only looks like a push, in a session on the machine, for a
checkout whose `HEAD` equals `origin/main` and whose commit is already deployed:

```powershell
Remove-Item "$env:TEMP\vercel-deploy-watch-WebApp-$((git -C C:\GSADUs\WebApp rev-parse origin/main).Substring(0,12)).lock" -ErrorAction SilentlyContinue
"probe, nothing is pushed: git -C C:/GSADUs/WebApp push origin main"
```

The hook parses the text as a push, the waiter finds the commit's deployments already done
(about 10 s), and the session is woken with the reminder, mid-turn or idle. Running
`watch.mjs` by hand with a JSON payload on stdin proves its exit code, not the wake.

How a command's text maps to a checkout is `pushed-repo.mjs`; its cases run with
`node --test .claude/hooks/vercel-deploy/pushed-repo.test.mjs`. Until 2026-10-14 it read
only 40 characters past the push, so a long `git -C <worktree> push` was never watched.
