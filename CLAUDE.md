# GSADUs Workspace

## Folder Structure

Each folder is an independent GitHub repo. Never nest projects inside one another.

```
C:\GSADUs\
├── AppSheetCatalog\      gsadus-appsheet-catalog       Google AppSheet catalog scripts
├── AppsScript\           gsadus-appsscript             Google Apps Script archive (clasp-managed)
├── Dashboard\            gsadus-dashboard              Pipeline operations dashboard/control plane
├── DesignBundles\        gsadus-design-bundles         Interior design bundles + cost estimator
├── PostProcess\
│   ├── Darkroom\         gsadus-darkroom-web           Web render console (Next.js) — stalled/archive
│   ├── DigitalDarkroom\  (retired — see below)          Kept on disk as read-only reference
│   └── PNGTools\         gsadus-png-tools              Desktop image tool: batch PNG prep + Darkroom AI render
├── pyRevit\              gsadus-pyrevit                pyRevit extension — GSADUs Tools tab
├── Tools\                gsadus-tools                  Office workflow utilities (.exe / PS1)
├── Vault\                gsadus-vault                  Obsidian knowledge vault
├── WebCatalog\           gsadus-web-catalog            Web catalog of ADU models (Next.js + Supabase + GCS)
├── setup.ps1                                           Clones all repos to this structure
└── GSADUs.code-workspace                               VS Code / Cursor multi-root workspace
```

### Retired / archived repos (not cloned by `setup.ps1`)

- **`GSADUs.Revit.Addin`** (was `BatchExportV1\`) — legacy Revit batch-export addin.
- **`GSADUs.Revit.BatchExport`** (was `BatchExportV2\`) — current-gen Revit batch-export addin.
- **`gsadus-digital-darkroom`** (`PostProcess\DigitalDarkroom\`) — legacy Streamlit render app;
  a failed attempt at a browser-based PNGTools. Archived (read-only) on GitHub on 2026-07-07,
  **replaced by the PNGTools Darkroom workflow** (`gsadus-png-tools`). The local folder stays on
  disk as read-only reference (the Darkroom web repo's workspace links to it) but is excluded
  from `setup.ps1`, `wip`/`unwip` (see `$GSADUsRetiredRepos` in `Tools\ShellProfile\profile.ps1`),
  and `.env` sync. Do not extend it or treat its behavior as a pipeline contract.

The Revit addins were archived on 2026-06-18, replaced by the pyRevit GSADUs Tools
extension (`gsadus-pyrevit`, `pyRevit\`). Do not re-add retired repos to the workspace.

## Workspace Sync Protocol (wip / unwip)

`unwip-all` is self-healing: it syncs the workspace root first (so `setup.ps1` is current), then calls `setup.ps1 -CloneOnly` to clone any missing repos before unwipping the rest.

**When adding or removing a repo:**
1. Update `setup.ps1` on the source machine and commit it (via `wip-all` or a real commit).
2. On the receiving machine, `unwip-all` detects and clones the missing repo automatically — no manual steps needed.
3. If `unwip-all` still misses a repo (e.g. fresh machine with no profile yet), run `setup.ps1` manually.

**Agent rule:** When asked to sync a receiving machine, always run `unwip-all` — do not assume the repo list is already complete. If `unwip-all` reports a repo as missing after running, run `setup.ps1` on that machine.

## Rules for AI Agents

1. **One repo = one direct subfolder of `C:\GSADUs\`.** Never create project files inside an existing repo folder unless you are actively working on that repo.
2. **New projects get their own repo and folder.** Do not add a new project as a subfolder of an existing repo.
3. **`PostProcess\` is a grouping folder, not a repo.** Sub-projects inside it each have their own repo.
4. **`AppsScript\` is a clasp-managed archive.** Google's environment is the source of truth. Run `clasp pull` inside a subfolder to get the latest before editing.
5. **Do not commit `*.addin` files to this workspace repo.** They belong in the `deploy\` folder of each Revit addin repo.
6. **Fix the root cause; never fall back to a legacy path or leave stale code behind.** When patching or fixing, address the actual error at its source. Do **not** reach for a superseded/legacy method as a quick workaround, and do **not** leave the old or duplicate code path behind "just in case" — remove or migrate superseded code as part of the same change. Stacked fallbacks and orphaned code snowball, get silently ignored, and make every later edit harder to reason about. A genuine fallback must be a deliberate, documented design decision (and the superseded path retired on a stated timeline), never a reflex. This applies to every repo in this workspace.

## Project Context — The Vault

All project context, workflows, planning, gaps, and tool documentation lives in the **Obsidian Vault** at `C:\GSADUs\Vault\`. Read `Vault\CLAUDE.md` for the vault schema and frontmatter conventions.

Key vault pages:
- `Vault\wiki\curated\key-locations.md` — all file paths and machine hostnames
- `Vault\wiki\curated\planning.md` — gaps, roadmap, automation candidates
- `Vault\wiki\auto\pipeline-image-export.md` — end-to-end image pipeline
- `Vault\wiki\curated\wip-sync.md` — cross-PC sync workflow

When starting a new session, read the relevant vault pages for context rather than expecting standalone docs at this root level.

### Searching across repos (Vault included)

The root `.gitignore` excludes every sub-repo (so this workspace repo doesn't track them). Ripgrep — which powers Claude Code's Grep/Glob and `rg`/`fd` — honors `.gitignore`, so a search from `C:\GSADUs\` root would otherwise **silently skip all repo content, including the Vault**. A root **`.ignore`** file re-includes the sub-repos for search only; it does not affect git, and each sub-repo's own `.gitignore` still applies once ripgrep descends (node_modules, `.env`, etc. stay excluded). With it in place, Grep/Glob from the root reach the Vault and every repo.

- `.ignore` is committed to the workspace repo — keep it committed so every machine inherits this behavior (it must stay in sync like `setup.ps1`).
- If it's ever missing (fresh clone before first sync), search the target repo directly (`path: C:\GSADUs\Vault`) or pass `rg --no-ignore-vcs`. Do **not** "fix" this by editing `.gitignore` — that would make git try to track the nested repos.
