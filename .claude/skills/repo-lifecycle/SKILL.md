---
name: repo-lifecycle
description: "Add, rename, move, retire, archive, or sunset a GSADUs repo — or investigate leftover references to a removed repo. Use when the user asks to add a new repo/project to the workspace, rename a repo folder, retire or archive a repo, or reports stale references to one."
---

# repo-lifecycle — GSADUs repo add / rename / retire runbook

Every lifecycle event must touch all of its surfaces together, then end green:

```powershell
pwsh -File C:\GSADUs\.claude\skills\repo-lifecycle\scripts\check-repo-registry.ps1
```

**Self-check (every run):** the surface lists below and `scripts/check-repo-registry.ps1`
are maintained together. Before executing, diff this list against the script's checks;
a surface added, renamed, or removed on either side must be reflected in the other in
the same change.

## Inputs and stop conditions

- Inputs: event (`add` | `rename` | `retire`), repo/folder name; for rename also the new folder + GitHub names.
- Stop if the target repo has uncommitted work — save or wip it first.
- "Delete" phrasing → confirm that archive (not deletion) is intended before anything else.

## Add

- `setup.ps1` → new `@{ Url; Path }` row in `$repos`.
- `CLAUDE.md` → folder-tree row (folder → GitHub name → one-liner).
- `.gitignore` → `<Folder>/` entry under sub-repos (top-level folder only; grouping-folder children are already covered).
- `.ignore` → matching `!<Folder>/` negation so root search reaches the new repo.
- `GSADUs.code-workspace` → folder entry (skip only with a documented reason — pyRevit is the precedent).
- Vault `wiki/curated/workspaces.md` → registry row; follow its "How to add a new workspace" for the hub page + frontmatter.
- Vault decision-log → drafted row (a new repo meets the majors-only bar).
- Other machine: `unwip-all` clones it via setup.ps1; per-machine state per the wip-sync reference below.
- Run `check-repo-registry.ps1` → green.

## Rename / move

- GitHub rename: exact steps (or `gh repo rename`) — **requires explicit user confirmation; never run unprompted**.
- This machine: move the folder, then `git remote set-url origin <new-url>`.
- `setup.ps1` → update the row's Url + Path.
- `CLAUDE.md` → tree row, plus every other old-name mention (`git grep` the workspace repo).
- `.gitignore` / `.ignore` → rename both entries.
- `GSADUs.code-workspace` → folder path.
- Tools `ShellProfile\profile.ps1` → `$GSADUsEnvFiles` paths if the repo carries a synced `.env` (edit lands in the **gsadus-tools** repo).
- Vault → `workspaces.md` row + `workspace-<name>.md` hub (title, `sources:` frontmatter).
- Vault decision-log → drafted row if the rename meets the majors bar.
- Receiving machine: folder move + `git remote set-url` + **memory migration** — follow the wip-sync reference below; do not restate it here.
- Run `check-repo-registry.ps1` → green.

## Retire / archive / sunset

- Confirm archive intent; the GitHub archive itself is instructions + explicit confirmation, never automatic.
- `setup.ps1` → remove the `$repos` row.
- `CLAUDE.md` → move the repo to the retired section, keeping the guard sentences (do not extend; behavior/schemas are not pipeline contracts).
- `.gitignore` / `.ignore` → entries follow the folder: keep while it stays on disk, remove when it leaves.
- `GSADUs.code-workspace` → remove the folder entry unless the read-only folder should still open in the hub.
- Tools `ShellProfile\profile.ps1` → add to `$GSADUsRetiredRepos`; remove from `$GSADUsEnvFiles` if present (**gsadus-tools** commit).
- Vault → `workspaces.md` row marked *(retired)*; hub page gets `status: deprecated` (**never delete Vault pages**).
- Vault decision-log → drafted row (a retirement meets the majors-only bar).
- Other machine: per-machine state per the wip-sync reference; the retired folder stays read-only there too.
- Run `check-repo-registry.ps1` → green.

## Boundaries

- Never delete Vault pages — deprecate only. Never touch retired repos' content.
- Never perform the GitHub archive/rename without explicit user confirmation in this session.
- Never force-push. If the consistency script is still red after the edits: stop and report the remaining mismatches instead of improvising.

## References (read at need — never restate their content here)

- Vault `wiki/curated/wip-sync.md` → **"Claude Code machine-local state (NOT synced by git or wip)"** — memory migration and per-machine config after any rename/retire.
- Vault `wiki/curated/workspaces.md` → **"How to add a new workspace"** — hub-page + registry procedure.
