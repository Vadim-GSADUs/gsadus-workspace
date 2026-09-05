# GSADUs Workspace

## Folder Structure

Each folder is an independent GitHub repo. Never nest projects inside one another.

```
C:\GSADUs\
├── AppSheetCatalog\      gsadus-appsheet-catalog       Google AppSheet catalog scripts
├── AppsScript\           gsadus-appsscript             Google Apps Script archive (clasp-managed)
├── Dashboard\            gsadus-dashboard              Pipeline operations dashboard/control plane
├── PM\                   gsadus-pm                     Internal PM/scheduling webapp (BuilderTrend replacement)
├── PostProcess\
│   ├── Darkroom\         (retired — see below)          Kept on disk as read-only reference
│   ├── DigitalDarkroom\  (retired — see below)          Kept on disk as read-only reference
│   └── PNGTools\         gsadus-png-tools              Desktop image tool: batch PNG prep + Darkroom AI render
├── pyRevit\              gsadus-pyrevit                pyRevit extension — GSADUs Tools tab
├── Shared\               gsadus-shared                 Shared internal npm packages (GitHub Packages; @gsadus/pipedrive)
├── SiteCheck\            (retired — see below)          Kept on disk as read-only reference
├── Tools\                gsadus-tools                  Office workflow utilities (.exe / PS1)
├── Vault\                gsadus-vault                  Obsidian knowledge vault
├── WebApp\               gsadus-web-app                Internal platform app: design bundles, cost estimator, models prototype
├── WebCatalog\           gsadus-web-catalog            Web catalog of ADU models (Next.js + Supabase + GCS)
├── setup.ps1                                           Clones all repos to this structure
└── GSADUs.code-workspace                               VS Code / Cursor multi-root workspace
```

### Retired / archived repos (not cloned by `setup.ps1`)

| GitHub repo | Was | Retired | GitHub state | Superseded by |
|---|---|---|---|---|
| `GSADUs.Revit.Addin`, `GSADUs.Revit.BatchExport` | `BatchExportV1\`, `BatchExportV2\` (gone from disk) | 2026-06-18 | archived | pyRevit GSADUs Tools extension (`gsadus-pyrevit`) |
| `gsadus-digital-darkroom` | `PostProcess\DigitalDarkroom\` | 2026-07-07 | archived | PNGTools Darkroom workflow (`gsadus-png-tools`) |
| `gsadus-darkroom-web` | `PostProcess\Darkroom\` | 2026-07-07 | archived | PNGTools outgrew it |
| `gsadus-site-check` | `SiteCheck\` | 2026-08-06 | **deleted 2026-08-11** | The Site Check module ships from `gsadus-web-app`; its live contract is `WebApp\docs\site-check\SPEC.md` |

The retired folders stay on disk read-only and are excluded from `setup.ps1`, `wip`/`unwip`
(`$GSADUsRetiredRepos` in `Tools\ShellProfile\profile.ps1`) and `.env` sync. Do not extend them,
treat their schemas as contracts, or re-add them. `SiteCheck\` has no remote at all (the GitHub
repo was deleted 2026-08-11): its `origin` fails by design — never re-point or re-create it.

## Dev Port Map (owner decision 2026-08-11)

Each webapp project owns a port lane so simultaneous dev servers never conflict. OAuth
redirect allowlists (each project's own Supabase) and the Maps browser key (WebApp only)
are configured per lane — a server outside its lane breaks sign-in and/or Maps.

**Port 3000 is VACATED by all web projects (2026-08-11):** it belongs to the Revit
ecosystem (Revit 2026's sign-on helper reserves it via http.sys while open; a pyRevit
MCP/CLI environment may claim it). No web app binds 3000, ever.

| Repo | Primary | Agent/second server | e2e | Notes |
|---|---|---|---|---|
| `WebApp` | 3009 | 3010 (non-signed-in only) | 3111 | `npm run dev` pins 3009. Maps key + `gsadus-web-catalog` OAuth allow 3009/3111 + both ts.net hosts; 3010 is NOT in either (Codex/agent work that needs no Maps/OAuth). Build-block hook guards 3000–3010. |
| `PM` | 3200 | 3209 | 3211 | PM authenticates via the `gsadus-web-catalog` Supabase project (2026-08-24 merge); its allowlist covers all three PM ports (catalog Site URL unchanged). Never run PM inside 3000–3010 — it trips WebApp's build-block hook. |

Agent rule: start dev servers only on your repo's lane; primary is the owner's. Agents
default to the second-server port; WebApp agents needing signed-in/Maps testing while the
owner holds 3009 use 3111 (also fully allowlisted).

## Workspace Sync Protocol (wip / unwip)

`unwip-all` is self-healing: it syncs the workspace root first (so `setup.ps1` is current), then calls `setup.ps1 -CloneOnly` to clone any missing repos before unwipping the rest.

**When adding or removing a repo:**
1. Update `setup.ps1` on the source machine and commit it (via `wip-all` or a real commit).
2. On the receiving machine, `unwip-all` detects and clones the missing repo automatically — no manual steps needed.
3. If `unwip-all` still misses a repo (e.g. fresh machine with no profile yet), run `setup.ps1` manually.

**Agent rule:** When asked to sync a receiving machine, always run `unwip-all` — do not assume the repo list is already complete. If `unwip-all` reports a repo as missing after running, run `setup.ps1` on that machine.

## Secrets — Doppler (adopted 2026-08-25)

All application secrets live in **Doppler** (workplace on vadim@gsadus.com); the
gitignored env files (`WebApp\.env.local`, `PM\.env.local`, `WebCatalog\pipeline\.env`,
`PostProcess\PNGTools\.env`) are **rendered artifacts** — regenerate with `pull-env`
(auto-chained after a clean `unwip-all`). Never hand-edit, copy between machines, or
commit them, and never print their values into a transcript; edit in Doppler
(dashboard or `doppler secrets set`), then `pull-env` on each machine. Vercel
Production/Preview sync from Doppler `webapp/prd`/`stg`. Full spec, hygiene rules for
agents, and the migration record: `Vault\wiki\curated\secrets-management.md`.

## Production Error Triage — Sentry (one org, every project)

One Sentry org (`gsadus`) holds every app project (`webapp`, `pm`, …). Read it from ANY repo
with the workspace probe — GET-only by construction, compact output, no MCP round-trips:

```powershell
sentry-probe issues --project pm                        # pwsh (shell-profile function)
node C:/GSADUs/Tools/Sentry/sentry-probe.mjs issue PM-10   # Git Bash / any shell
```

Commands: `projects` · `issues` · `issue <SHORT_ID>` · `events`; `--json` for the raw payload.
Auth is `SENTRY_AUTH_TOKEN`, read from Doppler `webapp/dev` at call time (never print it).
Reach for a Sentry MCP connector (claude.ai's, or one wired into the harness you are in) only for what the probe cannot do (Seer, updates).
Details: `Tools\Sentry\README.md`.

## Rules for AI Agents

1. **One repo = one direct subfolder of `C:\GSADUs\`.** Never create project files inside an existing repo folder unless you are actively working on that repo.
2. **New projects get their own repo and folder.** Do not add a new project as a subfolder of an existing repo.
3. **`PostProcess\` is a grouping folder, not a repo.** Sub-projects inside it each have their own repo.
4. **`AppsScript\` is a clasp-managed archive.** Google's environment is the source of truth. Run `clasp pull` inside a subfolder to get the latest before editing.
5. **Do not commit `*.addin` files to this workspace repo.** They belong in the `deploy\` folder of each Revit addin repo.
6. **Fix the root cause; never fall back to a legacy path or leave stale code behind.** When patching or fixing, address the actual error at its source. Do **not** reach for a superseded/legacy method as a quick workaround, and do **not** leave the old or duplicate code path behind "just in case" — remove or migrate superseded code as part of the same change. Stacked fallbacks and orphaned code snowball, get silently ignored, and make every later edit harder to reason about. A genuine fallback must be a deliberate, documented design decision (and the superseded path retired on a stated timeline), never a reflex. This applies to every repo in this workspace.
7. **Plans expire — deprecate aged plans instead of reviving them.** If a planning doc (a `planning.md`, `.planning/` artifact, roadmap, or spec) has sat untouched and unimplemented for **3–4 months**, mark it deprecated rather than executing or patching it — by then the projects have almost always evolved past what the plan describes. Recreate a fresh plan from current codebase context instead of trying to rehabilitate an aged one (decision 2026-07-10). This applies to every repo in this workspace and to the Vault's planning pages.

## Agent Harnesses — one instruction set (owner decision 2026-09-05)

The owner runs both Claude Code and the Codex app on these repos, deliberately. Both read
the same files; nothing is duplicated per harness:

- **`AGENTS.md` is the canonical, tool-neutral instruction file** at every repo root and at
  this workspace root. Rule text lives there and nowhere else.
- **`CLAUDE.md` beside it is `@AGENTS.md` plus Claude-Code-only operating notes** — never
  rule text. Reading a `CLAUDE.md` with a file tool shows the literal `@AGENTS.md` line, so
  when told to read a repo's rules, read its `AGENTS.md`.
- **Skills have one copy: `.claude/skills/<name>/SKILL.md`.** Claude Code auto-loads them
  (workspace skills only in sessions started at `C:\GSADUs`); every other harness reads the
  relevant `SKILL.md` before the task. Never create `.agents/` or `.codex/` directories —
  the Codex app's *Import from another agent* sync wrote substituted copies there on
  2026-09-05; its repo-writing categories (Instructions, Skills, Commands, Hooks, Agents)
  are off on both PCs for that reason. Only chats, plugins, MCP servers and memory sync,
  and those land in `~\.codex`, never in a repo.
- Codex's instruction chain stops at each repo's git root, so a sub-repo `AGENTS.md` points
  here (`C:\GSADUs\AGENTS.md`) for the workspace rules; Claude Code walks the directory
  tree and reaches this file on its own.
- The Next.js managed block (`nextjs-agent-rules`) lives in `AGENTS.md` only, committed.
- **Cross-harness delegation runs through the shell, never through imported agent
  definitions:** Claude → Codex via the openai-codex plugin (`codex exec`, foreground);
  Codex → Claude via `.claude\skills\delegate-to-claude\SKILL.md` (a pinned, non-interactive
  `claude -p` launch). The caller reviews every delegated diff before it lands.
- **Instruction files stay lean** (owner decision 2026-09-05): an `AGENTS.md` holds only what
  an agent cannot derive — owner decisions and contracts, environment facts (ports, secrets,
  deploy disciplines), and pointers to binding docs and skills. Not architecture or file maps
  (read the tree), not shipped-slice narrative (git has it), not one-time incidents (those go
  to the repo's HANDOFF Gotchas with its date ratchet, or to agent memory), not guardrails
  written for weaker models. Cap: 200 lines per `AGENTS.md`, enforced by the registry check;
  a file near the cap means content belongs in its binding doc, not in a tighter rewrap.

Repo add/rename/retire/archive: follow `.claude\skills\repo-lifecycle\SKILL.md` and finish
with its `scripts\check-repo-registry.ps1` green — it also enforces this convention. Full
spec, evidence, and the options weighed: `Vault\wiki\curated\agent-harnesses.md`.

## Project Context — The Vault

All project context, workflows, planning, gaps, and tool documentation lives in the **Obsidian Vault** at `C:\GSADUs\Vault\`. Read `Vault\AGENTS.md` for the vault schema and frontmatter conventions.

Key vault pages:
- `Vault\wiki\curated\key-locations.md` — all file paths and machine hostnames
- `Vault\wiki\curated\planning.md` — gaps, roadmap, automation candidates
- `Vault\wiki\auto\pipeline-image-export.md` — end-to-end image pipeline
- `Vault\wiki\curated\wip-sync.md` — cross-PC sync workflow

When starting a new session, read the relevant vault pages for context rather than expecting standalone docs at this root level.

### Searching across repos (Vault included)

Ripgrep (Claude Code's Grep/Glob, Codex's search, `rg`/`fd`) honors the root `.gitignore`, which
excludes every sub-repo; the committed root **`.ignore`** re-includes them for search only (git
is unaffected; each sub-repo's own `.gitignore` still applies once ripgrep descends). If
`.ignore` is missing on a fresh clone, search the target repo directly or pass
`rg --no-ignore-vcs` — never "fix" it in `.gitignore`. Three facts about root searches:

- Hits mix every repo in one list — attribute each to its repo before acting on it.
- `.ignore` also hides `dist/`, `build/`, `node_modules/`, `.venv/`: never characterize build
  output from a root search; `cd` into the repo or pass `--no-ignore`.
- `<repo>\.claude\worktrees\<name>\` copies are searchable and may be stale branches.

Verify content, not timestamps, and treat any audit's findings as claims to re-verify at the
file — including this file's.
