@AGENTS.md

# GSADUs Workspace — Claude Code Notes

[AGENTS.md](AGENTS.md) (imported above) is the workspace rulebook for every harness. This
file holds only what Claude Code alone acts on.

- Workspace skills (`.claude\skills\*\SKILL.md`) auto-load only in sessions started at
  `C:\GSADUs`; from a sub-repo session, read the SKILL.md directly.
- `.claude\settings.json` runs two SessionStart hooks: the current date/time, and the
  unresolved wip-conflict banner (`C:\GSADUs\.wip-conflict.md`). `settings.local.json` is the
  machine-local allowlist (gitignored).
- Vercel deploys are watched by a user-level hook (per machine; install or repair with
  `node .claude\hooks\vercel-deploy\install.mjs --apply`): after any `git push` of `main` in a
  Vercel-linked repo (WebApp, PM) it waits in the background and wakes the agent when
  production is live or failed, through `Tools\Vercel\Wait-Deployment.ps1` (the one waiter;
  AGENTS.md → Deployment readiness). Never hand-roll a deploy poll.
- Agent worktrees live at `<repo>\.claude\worktrees\<name>\` and are searchable from here —
  attribute hits before acting (AGENTS.md → Searching across repos).
