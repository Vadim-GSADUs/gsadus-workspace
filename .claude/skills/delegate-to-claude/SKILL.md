---
name: delegate-to-claude
description: Launch a pinned, non-interactive Claude Code session (Fable or Opus) from any other harness or script — Codex handing a slice, a review, or an investigation to a Claude agent — with a self-contained brief and scoped tool permissions, the caller reviewing the diff before it lands. Use when a Codex session needs a Claude agent, or when a scripted workflow needs a deterministic headless Claude run.
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
# or: -Brief "…" · -Model claude-opus-4-8 · -Effort high · -AllowedTools Read,Glob,Grep · -OutputFormat json · -DryRun
```

- `-Repo` is the working directory. The session starts there, so that repo's `CLAUDE.md`
  (which imports `AGENTS.md`) and the workspace chain load exactly as in an interactive
  session. Never run sub-repo work from `C:\GSADUs`.
- **The brief is the whole context** — the delegate sees no chat history. State the goal, the
  files, the docs to read first, the verification command, and what to report back.
- Defaults follow the owner's rule for scripted launches (2026-07-14): model pinned
  (`claude-fable-5-1`; `claude-opus-4-8` for git-heavy chores), `--permission-mode acceptEdits`,
  an explicit `--allowedTools` list, `--setting-sources user,project,local` (a non-bare `-p`
  session — under `--bare`, OAuth and instruction discovery are skipped). Never inherit
  account defaults.
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

- `claude` on PATH and signed in (OAuth). Verified 2026-09-05 on VG-Home: `claude-opus-4-8`
  round-trips in ~4 s. **`claude-fable-5-1` needs Claude Code ≥ 2.1.251** (`claude update`);
  an older CLI answers `400 … does not support this model`.
- From the Codex app, the launch needs network and writes under `~\.claude`, which Codex's
  `workspace-write` sandbox blocks — approve the escalation for the command. Unverified until
  the first real Codex-side run; record the outcome here.
- `--bare` is announced to become the `-p` default in a future Claude Code release. When it
  lands, add the explicit non-bare flag to `claude-run.ps1` and re-verify — the same watch as
  Vault `scripts/wiki-scan.ps1`.
