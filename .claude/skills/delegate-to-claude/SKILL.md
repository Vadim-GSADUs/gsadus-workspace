---
name: delegate-to-claude
description: Launch a non-interactive Claude Code session on the account's default model from any other harness or script — Codex handing a slice, a review, or an investigation to a Claude agent — with a self-contained brief and scoped tool permissions, the caller reviewing the diff before it lands. Use when a Codex session needs a Claude agent, or when a scripted workflow needs a deterministic headless Claude run.
---

# delegate-to-claude — a headless Claude session from any harness

The mirror image of Claude → Codex delegation (WebApp `CLAUDE.md`, *Implementation style*:
`codex exec` through the openai-codex plugin). Cross-harness orchestration always runs through
the shell; an imported agent definition cannot do it — a Codex custom agent is an OpenAI model
with Codex's tools, whatever its prompt says (Vault `wiki/curated/agent-harnesses.md`).

## Run

```powershell
pwsh -File C:\GSADUs\.claude\skills\delegate-to-claude\scripts\claude-run.ps1 `
    -Repo C:\GSADUs\PM -BriefFile .\brief.md
# or: -Brief "…" · -Model <id> · -Effort high · -AllowedTools Read,Glob,Grep · -OutputFormat json · -DryRun
```

- `-Repo` is the working directory. The session starts there, so that repo's `CLAUDE.md`
  (which imports `AGENTS.md`) and the workspace chain load exactly as in an interactive
  session. Never run sub-repo work from `C:\GSADUs`.
- **The brief is the whole context** — the delegate sees no chat history. State the goal, the
  files, the docs to read first, the verification command, and what to report back.
- Defaults follow the owner's rules for scripted launches: no `--model` pin, so the session
  runs the account's default model (2026-09-30; `-Model <id>` overrides one launch);
  pre-granted scoped permissions (2026-07-14): `--permission-mode acceptEdits` and an explicit
  `--allowedTools` list; and `--setting-sources user,project,local` (a non-bare `-p` session —
  under `--bare`, OAuth and instruction discovery are skipped).
- Output: the delegate's final report on stdout, exit code propagated. `-OutputFormat json`
  for machine parsing. Sessions persist (`claude --resume` continues one); `-DryRun` prints the
  exact command and launches nothing.

## Rules

1. **The caller stays the integrator.** Review the delegated diff, run the repo's verification
   chain, commit atomically with explicit paths. Never commit a delegated diff unreviewed.
2. The delegate never pushes (a push to PM or WebApp `main` is a release) and never touches
   Doppler, DSNs, or `PM/lib/db.ts` unless the brief says so explicitly.
3. Scope `-AllowedTools` to the task: a review needs `Read,Glob,Grep`; implementation adds
   `Edit,Write,Bash(git:*),Bash(npm:*)`. Nothing broader without a reason in the brief.
4. One delegate per repo at a time. Parallel work uses worktrees (`claude -w`), not a shared tree.

## Requirements and failure modes

- `claude` on PATH and signed in (OAuth). Verified 2026-09-30 on VG-Home: the default model
  (`claude-opus-5-5`) round-trips in ~2 s. When the account default moves to a newer model, an
  outdated CLI answers `400 … does not support this model`; run `claude update`.
- From the Codex app, the launch needs network and writes under `~\.claude`, which Codex's
  `workspace-write` sandbox blocks — approve the escalation for the command. Unverified until
  the first real Codex-side run; record the outcome here.
- `--bare` is announced to become the `-p` default in a future Claude Code release. When it
  lands, add the explicit non-bare flag to `claude-run.ps1` and re-verify — the same watch as
  Vault `scripts/wiki-scan.ps1`.
