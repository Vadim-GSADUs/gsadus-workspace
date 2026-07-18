---
title: Skill Opportunity Audit — GSADUs workspace level (gsadus-workspace + gsadus-vault)
type: audit
maintained: agent
status: active
sources:
  - C:\GSADUs\Vault\wiki\curated\skill-audit-prompt.md
last_reviewed: 2026-07-18
tags: [claude-code, skills, agents, hooks, audit, workspace, vault]
---

# Skill Opportunity Audit

| Metadata | Value |
|---|---|
| Audit date | 2026-07-18 |
| Repositories | **Joint audit**: `gsadus-workspace` (`C:\GSADUs`, commit `eaf452a`) + `gsadus-vault` (`C:\GSADUs\Vault`, commit `1aededb`). Read-only context: `Tools\ShellProfile\profile.ps1` (gsadus-tools) |
| Git evidence window | Workspace repo 2026-03-04 → 07-18 (full history); Vault 2026-04-15 → 07-18 (full history) |
| Transcript window — Home (VG-Home) | `C--GSADUs`: 12 sessions, 2026-06-18 → 07-18 (all retained, fully indexed); `C--GSADUs-Vault`: 1 session (07-08); keyword-recurrence scan across all 84 retained sessions in 9 GSADUs project dirs |
| Transcript window — Work (gsadus-vadim, over SSH) | `C--GSADUs`: 6 sessions, 2026-06-16 → 07-08 (fully indexed); `C--GSADUs-Vault`: 0 sessions; keyword scan across all 72 retained GSADUs sessions; user-level `.claude` config inventoried. Index built remotely via the scp-a-script pattern; only the index transferred; remote temp files deleted |
| Method | Breadth-first per the canonical prompt: one-line-per-session index over **both machines' full retained history** before any deep dive; 8 Home transcripts deep-dived; five roles ran (Workflow Historian, Codebase Archaeologist, Extension Classifier, External Researcher, Skeptical Reviewer — the Skeptical pass killed 2 of 3 draft skills) |
| Unavailable evidence | Anything before ~2026-06-16 on either machine (transcript retention; the May 18 → Jun 18 era survives only as the 63-session analysis preserved in workspace memory `user-workflow-patterns.md`); Work-PC root sessions after 07-08 (none exist — workspace-level ops moved to Home, locally or via SSH); wiki-scan light-run logs (none were ever created — itself a finding) |

Per workspace rule 7, this report expires: if it sits unactioned for 3–4 months, rerun the audit rather than acting on it.

## Executive Summary

- **Strong Skill candidates: 1** — `repo-lifecycle` (38/50), the add/rename/retire runbook. It is the only skill idea that survived adversarial review; two others (wip-conflict resolution 41→29, cross-machine sync 38→27) were killed because their content already ships at the moment of need (the generated `.wip-conflict.md` checklist + seeded agent prompt) or became a Vault section the day before this audit.
- **Useful non-Skill improvements: 10**, grouped in five bundles: the always-loaded-context debloat + two-machine memory consolidation; tracking `C:\GSADUs\.claude\` in git (the linchpin — today the wip-conflict hook and any future workspace skill are machine-local and silently absent from the work PC); three Vault-script tune-ups (model pin, proposal carry-forward, light-scan diagnosis); four verified one-time fixes; and one Vault documentation section (the agent-session SSH remote-execution pattern).
- **Most important current inefficiency:** workspace *process* knowledge is needed far beyond root sessions — `unwip` appears in **42% of the 135 non-root repo sessions** across both machines — while every mechanism that could carry it (hooks, skills, settings, memory) is machine-local and unsynced. The two PCs have measurably diverged: the work PC lacks the 07-11 wip-conflict hook, its workspace memory is frozen at 2026-06-24 with facts contradicted since, and its account-default model differs. The same gap class caused the documented rename-orphaned-memory incident (07-08, found 07-17).
- **Highest-value recommendation:** track `C:\GSADUs\.claude\` in the control repo (keep `settings.local.json` ignored, scope the `.ignore` search exclusion down in the same change). It permanently fixes hook parity, and it is the precondition for every skill-shaped artifact at workspace level.
- **Evidence limitations:** ~30-day transcript retention on both machines (mid-June onward; the earlier month exists only as a preserved summary); Work evidence is index-only by design; the vault-automation cadence claims rest partly on absence of logs, which was verified on both machines but is inherently negative evidence.

Posture finding: this workspace's sync/automation machinery is unusually mature and largely *self-correcting in code* (tree-content dedupe, stash self-pruning, secret-leak guard, conflict reports that seed a pinned agent). The audit found the leverage is not more automation — it is making the existing machinery and its knowledge **reach both machines and all cwds**, and deleting stale context that misleads agents.

## Current Claude Code Configuration

**Workspace repo (`C:\GSADUs\.claude\` — machine-local today, `.gitignore:26` ignores it):**
- `settings.json`: two SessionStart hooks (`"shell": "powershell"`), working — current-date injection and the `.wip-conflict.md` detector (added 07-11, session `51d303ec`). **Verified scoping (official docs, 2026-07-18): these fire only for sessions started at `C:\GSADUs`** — never in WebApp/pyRevit/etc. sessions. Presence on the work PC unverified and doubtful (its root sessions predate the hook).
- `settings.local.json`: scoped allowlist (git/gh/ssh Vadim@gsadus-vadim/python; pruned 2026-07-17).
- No skills, agents, rules, or commands at workspace level. No `.mcp.json`.

**Vault:** no `.claude` at all (deliberate). Its automation is `scripts\wiki-scan.ps1` (headless `claude -p`, acceptEdits, git-scoped tools, **no model pin**) + scheduled task `GSADUs-wiki-scan` (weekly Sun 18:00, home only — verified registered, last run 07-12 clean, next 07-19) + the `end-day` light-scan chain (verified **never executed on either machine** — zero light logs; work PC has no logs directory at all).

**User level — Home (VG-Home):** no custom skills/agents/commands; 4 inert `gsd-*.js` files remain in `hooks\` (unwired since the 07-17 GSD parking; the work PC's equivalents were deleted that night). `settings.json`: `claude-fable-5[1m]`, effort high, no hooks. Plugins: claude-plugins-official + anthropic-agent-skills marketplaces; anthropic-skills suite active (incl. `consolidate-memory`, `skill-creator`). MCP: `aec-model-bridge` (user scope; Revit — irrelevant here).

**User level — Work (gsadus-vadim, inventoried 2026-07-18 over SSH):** skills: `skill-creator` only. `settings.json`: model **`sonnet`**, task-timer + notification-sound hooks, slack plugin, and a **malformed permissions entry `"--dangerously-skip-permissions"`** (a CLI flag string, not a valid rule — inert junk). `settings.local.json`: pyRevit-era allowlist incl. `ssh User@vg-home`.

**Auto-memory (`~\.claude\projects\C--GSADUs\memory\`):** Home: 12 files, current through 07-17, but 2 verified stale (`project_vault_phase1.md` — predates the maintained/owner model, cites the deleted `wiki/inbox/`; `project_postprocess_repos.md` — "archive repos stay in setup.ps1" false since 07-07) and `MEMORY.md` duplicates the CLAUDE.md folder table. Work: **5 files frozen at 2026-06-24** ("WebCatalog… pending add to setup.ps1"; predates all three retirements and the rename).

**Child-repo skills (for duplication checks):** WebApp `handoff`/`verify-slice`/`design-dna`; pyRevit `new-tool`/`tool-audit`. Sibling audits (both 2026-07-17) live at `WebApp\docs\skill-opportunity-audit.md` and `pyRevit\docs\skill-opportunity-audit.md`; their cross-repo flags are consolidated in this report.

**Verified config-scoping rules that shape everything below** (code.claude.com/docs — memory, large-codebases, skills, settings; retrieved 2026-07-18):
- Parent-directory **CLAUDE.md inherits in full** into child-repo sessions → `C:\GSADUs\CLAUDE.md` (81 lines) taxes every GSADUs session on the machine; official guidance: keep under 200 lines; `/doctor` (v2.1.206+) proposes trims.
- **`.claude\settings.json`/hooks load from the starting directory only**; **project skills walk up only to the session's git-repo root** → workspace-level skills/hooks do NOT reach sub-repo sessions. Documented cross-repo routes: user level (machine-local), `--add-dir`, or plugins. A one-line inherited CLAUDE.md pointer can still make a workspace skill file *readable* from any cwd.

## Repeated Work and Friction

| Pattern | Frequency evidence | Current cost | Source |
|---|---|---|---|
| wip/unwip conflict resolution | 7+ dedicated sessions, both machines, spanning the whole window (Work `e8b308f9` 06-16 → Home `9971728c` 07-18); `unwip` in 42% of 135 non-root sessions | 15–45 min/incident; diagnosis re-derived when the session lacks protocol context; "honestly, this system drives me crazy" (Work `89dcb9c7` 06-18) | Both indexes; deep dives |
| Cross-machine config replication ("apply the same to the other machine") | 8+ sessions, 06-16 → 07-18, the most consistent request pattern; `gsadus-vadim` in 9/12 Home root sessions | Each machine-local change re-planned ad hoc; $-expansion/nested-pwsh/scp pitfalls re-derived until 07-17 | Historian §1; `1ec47c01`, `cb755500`, `1801656c` |
| Repo add/rename/retire events | 3 events in 5 weeks + 2 residue incidents; **every** event missed ≥1 of ~9 surfaces | Dead `.gitignore`/`.ignore` entries persist today; rename orphaned both PCs' memory (found 9 days later); retired addin still loading into Revit (`7f2ee86c` 07-09); adds smeared over 12–22 days | Archaeologist B1; `wip-sync.md:94-98` |
| Vault upkeep / drift audits | ≥6 sessions both machines pre-automation; now 2 scheduled/manual scan runs (07-10, 07-12) + wiki-agent commits | Largely solved by wiki-scan; residual gaps: no model pin, light path never runs, 07-12 owner proposals still unapplied | Vault git log; `_health.md`; scan logs |
| Protocol questions ("which command / what's the end-of-day sequence") | 4+ sessions 06-16 → 07-08, then stopped (wip-sync.md improved) | Now low; historical #4 request type in the May–June analysis | Historian §3; `user-workflow-patterns.md` |
| Memory/context staleness misleading agents | Work memory frozen 06-24; 2 stale Home files; retired-repo status re-briefed by user (`1ec47c01` 07-15) | Agents act on contradicted facts; user re-teaches | Both inventories |
| Corrections that recurred after being memorialized | Breadth-not-recency given twice a month apart (`a9161250` 06-18, `9971728c` 07-17); spawned-agent defaults (`1ec47c01` 07-15); vault-search-first (`3f61e700` 06-24) | Re-teaching; the 07-15 case = "babysit and say yes for every search" | Historian §2 |
| Usage-limit-driven session management | Standing constraint across the window (95% usage 06-25; 45-min timer 07-13; "spare tokens before weekly reset" 07-18) | Shapes all dispatching; makes always-loaded context waste directly costly | Historian §9 |

One-time spikes deliberately **excluded** from skill design: the 07-08 retirement day, the 07-11→13 automation build-out, the 07-17/18 audit burst.

## Candidate Scorecard

Scores = Recurrence + Time saved + Error reduction + Context reduction + Trigger clarity + Project specificity + Procedural complexity + Testability + Maintenance stability + Security (/50). Bands: 40–50 strong · 32–39 useful · 24–31 later · <24 reject. Recurrence 0–1 auto-rejects. Scores shown are **post-Skeptical-Review finals** (draft → final where changed).

| # | Candidate | Mechanism (final) | Score | Recommendation |
|---|---|---|---:|---|
| S2 | Repo add/rename/retire runbook | **Project Skill `repo-lifecycle`** + consistency-check script | 40→**38** | **Recommend — the one new Skill (Phase 2, after N2)** |
| S1 | wip-conflict resolution skill | ~~Skill~~ → extend `Write-WipConflictReport`/seeded prompt in profile.ps1 (Tools repo — cross-repo flag) + memory sync via N1 | 41→**29** | Reject as Skill; promotion gate below |
| S3 | Cross-machine sync procedure | ~~Skill~~ → "Remote execution from agent sessions" section in Vault `remote-access.md` | 38→**27** | Documentation (Phase 2) |
| N1 | Context debloat + memory consolidation (both PCs) | Config action: CLAUDE.md surgical trim + `/doctor` + installed `consolidate-memory` | n/a | **Phase 1** |
| N2 | Track `C:\GSADUs\.claude\` in git | Config change (.gitignore/.ignore edits) | n/a | **Phase 1 — linchpin** |
| N3 | Vault script tune-ups (model pin; proposal carry-forward; light-scan diagnosis; explicit headless flags) | Scripts (Vault repo) | n/a | **Phase 1** (pin + diagnosis) / Phase 2 (rest) |
| N4 | One-time fixes (setup.ps1 SETUP.md refs; dead ignore entries; redundant autostash; work-PC settings junk; 4 inert gsd hook files) | Config/docs one-timers | n/a | Phase 1 riders + Phase 2 work-PC pass |
| N5 | HANDOFF/kickoff workspace generalization | Deferred behind the WebApp `/handoff` validation gate | 27 (now) | Phase 2 gate — do not build yet |
| R1 | `_health.md` proposal-triage skill | — | 22 | Reject (recurrence ~1) |
| R2 | `gshelp` command-discoverability function | Cross-repo flag (Tools) at most | ~18 | Reject (questions stopped after 07-08) |
| R3 | Obsidian/knowledge-base skill packs (kepano etc.) | — | — | Reject — adapt nothing now (see Duplication) |
| R4 | chezmoi-style `~/.claude` sync | — | — | Reject (Install-Profile.ps1 pattern already owns this; cross-repo flag) |
| R5 | `autoMemoryDirectory` → synced repo | — | — | Reject (would recreate the perpetually-dirty-tree phantom-unwip class) |
| R6 | Workspace plugin / local marketplace | — | — | Phase 3 — revisit only if the pointer pattern proves insufficient |
| R7 | Scheduled-task heartbeat hooks; syncthing | — | — | Reject (over-engineering; owner ruled out syncthing 06-18) |

## Recommended Skills

### Skill 1 (only) — `repo-lifecycle`

**Identity**
- Name: `repo-lifecycle`. Scope: project — `C:\GSADUs\.claude\skills\repo-lifecycle\` (**requires N2 first**, or it silently exists on one machine only).
- Purpose: run the add / rename / retire runbook for a GSADUs repo so that every surface changes together, on both machines, with a mechanical consistency check at the end.
- Trigger description: "Add, rename, move, retire, archive, or sunset a GSADUs repo — or investigate leftover references to a removed repo. Use when the user asks to add a new repo/project to the workspace, rename a repo folder, retire or archive a repo, or reports stale references to one."
- Model invocation: enabled. Slash `/repo-lifecycle <add|rename|retire> <repo>` also expected.

**Evidence**
- Three events in five weeks, each with verified misses: BatchExport retirement (06-18) left `.gitignore`/`.ignore` entries that are **still there today** (with `revit-mcp/`, gone since March); the DesignBundles addition (06-25, `a47586f`) missed CLAUDE.md for 12 days; the WebApp rename (07-08, `a755d4f`) orphaned per-machine Claude memory on both PCs, discovered 9 days later; retirement residue kept loading into Revit (`7f2ee86c`, 07-09). WebCatalog's add smeared across 22 days (06-03 → 06-25).
- Recurrence is not spent: AppSheetCatalog is on a declared sunset path (memory, 2026-07-10), so at least one more retirement is queued; the workspace has added ~1 repo/month since March.
- Current failure mode: the checklist exists nowhere; the best prior artifact is a **commit message body** (the rename commit carries the receiving-machine procedure).

**Boundaries**
- Handles: per-event checklists across the control repo (`setup.ps1` `$repos`, `CLAUDE.md` tree + retired section, `.gitignore` + `.ignore`, `GSADUs.code-workspace`), the Tools repo (`$GSADUsRetiredRepos`, `$GSADUsEnvFiles` — flag that these edits land in gsadus-tools), the Vault (`workspaces.md` registry row + `workspace-<name>.md` hub with `status: deprecated` on retire + drafted majors-bar `decision-log` row), GitHub archive/rename instructions, per-machine steps (memory migration + folder move + `git remote set-url` on the receiving PC — **by reference to `wip-sync.md` "Claude Code machine-local state", never restated**), and a closing run of the consistency script.
- Must not: delete Vault pages (deprecate only); perform the GitHub archive/rename itself without explicit confirmation (outward-facing); touch retired repos' content; restate the machine-local inventory; force-push anything.
- Inputs: event type, repo name, (rename) new folder/repo name. Outputs: coordinated edits, a repeat-on-the-other-machine checklist, a drafted decision-log row, a green consistency-check run.
- Failure/stop: consistency script still red after edits → stop and report; the target repo has uncommitted work → stop; "delete" phrasing → confirm that archive (not deletion) is intended.
- Approvals: GitHub-side archive/rename; anything destructive.

**Proposed structure**
```text
.claude/skills/repo-lifecycle/
├── SKILL.md
└── scripts/
    └── check-repo-registry.ps1
```
- `SKILL.md`: the three event checklists, each surface one line (file → what changes); the self-check rule ("the surface list and the script are maintained together — verify one against the other every run"); pointers to `wip-sync.md` (machine-local state) and `workspaces.md` ("How to add a new workspace"). No references/, templates/, tests/ dirs.
- `scripts/check-repo-registry.ps1` (pwsh 7): cross-checks `setup.ps1` `$repos` vs directories on disk vs `.gitignore`/`.ignore` entries vs `GSADUs.code-workspace` folders vs the Vault `workspaces.md` registry vs `$GSADUsRetiredRepos`, with the known legitimate exceptions encoded (pyRevit absent from the hub workspace by design; `PostProcess\` is a grouping folder). Exit non-zero on drift, name each mismatch. Also worth invoking from the weekly deep-scan prompt (it extends the scan's existing registry check rather than duplicating it — see N3).

**Validation plan**
1. Normal: dry-run "retire AppSheetCatalog" → the produced plan touches every surface in the checklist, requests confirmation for the GitHub archive, and ends with the script green. Success: zero surfaces missed against this audit's B1 reconstruction.
2. Ambiguous: "get rid of the Dashboard repo" → skill asks retire-vs-delete and defaults to the archive path; no destructive action pre-confirmation.
3. Failure/out-of-scope (self-demonstrating): run `check-repo-registry.ps1` **before** N4's cleanup — it must flag `BatchExportV1/`, `BatchExportV2/`, `revit-mcp/`; and a request to "clean up the Darkroom folder" → refuse per CLAUDE.md retired-repo rule.

**Cost and maintenance**
- Context: zero idle cost beyond the description line; body loads on trigger. Runtime deps: pwsh 7 only; syncs to both PCs via git once N2 lands.
- Security: edits config/doc files, all git-reversible; GitHub actions gated on explicit confirmation.
- Maintenance: the surface list is deliberately drift-prone — the script is its ratchet. Owner: Vadim. Retire when the workspace shape stops changing or a stronger mechanism supersedes it.

## Non-Skill Improvements

**CLAUDE.md (N1 — surgical, not wholesale):** `C:\GSADUs\CLAUDE.md` is 81 lines — already inside the official ≤200 guidance, and it inherits into every session on the machine, which is exactly why it earns a *surgical* trim, not a rewrite. Compress genuine redundancy only: the retired-repos block and the search-mechanism section can each lose narrative lines, but their guard sentences ("do not extend / do not treat schemas as pipeline contracts"; "never fix a search miss by editing `.gitignore`") stay verbatim — they exist because agents did exactly those things. Run the native `/doctor` trim proposals as a cross-check (it flags derivable content like the folder table; keep the table's repo↔GitHub-name mapping, which is *not* derivable from disk). Target: whatever falls out; ~60 lines is incidental, not a goal.

**Memory (N1, both machines):** run the installed `consolidate-memory` on Home (fix `project_vault_phase1.md`, `project_postprocess_repos.md`; dedupe MEMORY.md vs CLAUDE.md folder table) and on the work PC (its 5-file workspace memory is frozen at 06-24 and contradicted; curate — don't bulk-copy Home's files, per the WebApp-audit precedent). This is also where S1's surviving content lives: `feedback_stash_pop_conflict.md` is the stash-diagnosis home and must exist on both machines.

**Path-scoped rules:** none. Nothing found is file-area-scoped; always-on protocol facts stay in CLAUDE.md, procedures go to the one skill.

**Subagents:** none new. The auto-spawned conflict agent (profile.ps1 `Invoke-WipConflictAgent`) is already correctly pinned (Opus 4.8, acceptEdits, git-scoped) per the owner's 07-15 correction.

**Hooks (N2 first, then parity):** track `C:\GSADUs\.claude\` in the control repo — un-ignore it in `.gitignore` (keep `settings.local.json` ignored; `.wip-conflict.md` already separately ignored) and scope `.ignore:35`'s `.claude/` search exclusion down to `settings.local.json` in the same change, or committed skills become invisible to root Grep. Rollout caution (Skeptical Reviewer): the work PC may hold an untracked divergent `settings.json` — plan a one-time reconcile on first pull, and verify the wip-conflict hook now fires there. No new hooks: SessionStart date+conflict hooks are sufficient; heartbeat/monitoring hooks were rejected.

**MCP:** none. Nothing workspace-level needs live external data; the Vault's Obsidian layer is plain files.

**Scripts (N3, Vault repo):**
- `wiki-scan.ps1`: add `--model claude-opus-4-8` to `$claudeArgs` — the owner mandate for scripted launches (`feedback_agent_launch_defaults.md`), already precedented in `Invoke-WipConflictAgent`; today the scan inherits the account default, which on the work PC is `sonnet`.
- Same file: make the headless invocation explicit about its context contract (the official headless docs state `--bare` is recommended for scripted calls and will become the `-p` default in a future release — the scan currently relies on ambient CLAUDE.md/memory discovery from `C:\GSADUs`; pass explicit settings/flags so a CLI default flip can't silently change scan behavior).
- Deep-scan prompt: one line — "carry forward any prior `_health.md` proposals that remain unapplied" (cheap hardening; the 07-12 owner proposals are 6 days unactioned, though persisting drift would likely re-derive them).
- **Light-scan path: diagnose now, in one sitting** (Skeptical Reviewer, contra my draft's instrument-and-wait): zero light logs exist on either machine. Test whether `end-day` is ever actually run and whether `claude` resolves inside the hidden `-NoProfile` pwsh it spawns. Then either fix the launch or remove the chaining per rule 6 — no dead paths.

**Documentation (S3's landing place):** add a "Remote execution from agent sessions" section to Vault `remote-access.md`: the scp-a-script-then-`pwsh -File` pattern (never inline `$` over ssh — the remote default shell expands it), `-o BatchMode=yes -o ConnectTimeout=10`, per-user home paths (`User` vs `Vadim`), both-ends verification, delete remote temp files. Verified absent from that page today; it has been re-derived in 8+ sessions and was only ever written down inside audit prompts. Re-promote to a skill only if sessions still re-derive it a month after the page carries it.

**One-time fixes (N4, all verified):**
1. `setup.ps1:15,93` — `SETUP.md` → `BOOTSTRAP.md` (SETUP.md does not exist).
2. Prune dead `.gitignore`/`.ignore` entries (`BatchExportV1/`, `BatchExportV2/`, `revit-mcp/`) — rides naturally with N2's edit of the same files.
3. Drop the root repo's month-old `unwip-autostash` — **deliberately, not batched**: the self-pruner can never drop it (CLAUDE.md legitimately evolved past the stash base), so re-verify its one change (+rule-6 line) is in HEAD per the `feedback_stash_pop_conflict.md` procedure, then `git stash drop`.
4. Work PC (over SSH, with N1's memory pass): remove the malformed `"--dangerously-skip-permissions"` permissions entry; delete Home's 4 inert `gsd-*.js` hook files (work PC's were already deleted 07-17).

## Cross-Repo / Workspace Candidates

Flagged outward — not implemented here:

- **Tools repo (`profile.ps1`):** extend `Write-WipConflictReport` (and/or the seeded agent prompt) with the stash-conflict residuals from S1 — `git checkout --ours/--theirs` decision, the semantic redundancy re-verification before any manual `stash drop`, and the pwsh `'stash@{0}'` quoting pitfall. This is where the Skeptical Reviewer relocated S1's surviving value: one source of truth, fires at the moment of need, already syncs via gsadus-tools with no dependency on N2. Optionally also the light-scan fix if diagnosis points at `end-day`.
- **Tools repo (optional, low):** a `claude-config` install/sync helper for user-level `~\.claude` assets, mirroring the `Install-Profile.ps1` shim pattern — only if machine-local skill/config divergence keeps biting after N1/N2.
- **Per-repo (gated):** HANDOFF/kickoff generalization — after the WebApp `/handoff` skill passes its own ~5-slice validation gate, clone/adapt it as *per-repo project skills* (git-synced). Confirmed against scoping rules: a workspace-level skill cannot reach child-repo sessions, and a user-level one doesn't sync — per-repo is the only shape that fits the two-PC model.
- **WebCatalog/Vault (open item from the WebApp audit):** the cross-repo DB-migration procedure still has no Vault section.

**Consolidation ledger for prior audits' flags** (this audit is the workspace-level consolidation point): GSD dormancy cleanup — **done** both PCs 2026-07-17; permission allowlist prune — **done** 07-17 (owner closed the two remaining items; do not re-flag); rename→orphaned-memory Vault section — **done** 07-17 (`wip-sync.md`); wip/unwip hygiene (pyRevit flag) — **adjudicated here** (S1 outcome above); aec-bridge governance — **closed by owner ruling** 07-17; migration-procedure Vault section — **open** (above); `/handoff` generalization — **open, gated** (above).

## Rejected Skill Ideas

- **`wip-conflict` skill (S1, 41→29):** the generated `.wip-conflict.md` report already embeds the resolution checklist (profile.ps1 `Write-WipConflictReport`) and the auto-spawned agent receives the same loop in its seeded prompt — both sync via the Tools repo today. The skill's marginal content was largely *manual workarounds for bugs whose root-cause fixes landed* (tree-content dedupe 07-07; path-scoped stash-redundancy check 07-17) — codifying them would violate rule 6. Residuals → profile.ps1 report extension (cross-repo flag) + the memory file synced by N1. **Promotion gate:** if ≥2 further conflict sessions re-derive diagnosis from scratch *after* N1 (memory on both PCs) and the report extension land, revisit as a workspace skill.
- **`sync-machines` skill (S3, 38→27):** half its content (the machine-local inventory) became `wip-sync.md:89-106` one day before this audit — a skill would be a third copy on day one; the other half (the ssh/scp execution pattern) belongs in `remote-access.md`, which already owns hostnames and per-machine paths. All 8+ re-derivation sessions predate any documentation existing.
- **`_health.md` proposal-triage skill (R1):** one occurrence (the 07-10 decisions-applied evening). Recurrence gate.
- **`gshelp` (R2):** protocol questions stopped after 07-08 once `wip-sync.md` improved; the 06-18 analysis proposed it, and the need expired before anyone built it — instructive precedent for not building on stale demand.
- **Obsidian/KB skill packs (R3)** — kepano/obsidian-skills (MIT, active, Obsidian's own creator) is the best of class, but the Vault already runs a stricter native regime (maintained/owner semantics, scheduled scan agent, three-tier sources); imported skills would fight `Vault\CLAUDE.md`, and the useful fraction (markdown syntax reference) isn't a current failure mode. Heavier packs (claude-obsidian, obsidian-second-brain) add large shell/network surface for value the vault already has. Adapt nothing now.
- **chezmoi `~/.claude` sync (R4):** duplicates the existing tracked-file+shim pattern (`Install-Profile.ps1`); community guides are POSIX-flavored.
- **`autoMemoryDirectory` into a synced repo (R5):** reasoning verified by the Skeptical Reviewer against the 07-07 incident record — auto-memory writes continuously, so a synced memory dir is a permanently dirty tree on both PCs; the wip tree-dedupe would never converge and memory files would hit genuine cross-machine merge conflicts. This is precisely the failure class the clasp convention exists to prevent.
- **Workspace plugin / local marketplace (R6):** the documented route for cross-repo skills, but heavier than needed while exactly one skill lives at workspace level; revisit if that changes.
- **Heartbeat hooks / syncthing (R7):** over-engineering; syncthing was evaluated and rejected by the owner on 06-18 (weaker conflict resolution than the wip model).

## Duplication and Security Review

**Duplication checks:** installed `anthropic-skills` (consolidate-memory is *used* by N1, not duplicated; skill-creator available for authoring `repo-lifecycle`), native `/doctor` trim (used by N1), built-in `fewer-permission-prompts` (not needed — allowlists were pruned 07-17), `update-config` (the 07-11 hook was built with it; N2 is a git change, not a settings change), WebApp `handoff`/`verify-slice` and pyRevit `new-tool`/`tool-audit` (no overlap with `repo-lifecycle`), Vault `wiki-scan.ps1` and profile.ps1 functions (the consistency script *extends* the deep scan's registry check; S1/S3 were rejected precisely to avoid duplicating profile.ps1 and wip-sync.md), external packs per R3–R4 (inspected: kepano/obsidian-skills MIT ~46 commits active, obsidian-second-brain large-surface, chezmoi guides — none installed, none needed).

**Security findings:**
1. **Tracking `.claude` (N2) makes hooks repo-delivered** — a supply-chain-style surface in principle, but the repo is private, single-author, and the hooks are two small read-only pwsh snippets; the work PC gets Claude Code's one-time project-hook trust prompt. Keep `settings.local.json` (machine allowlists) out of git as specified.
2. **The headless vault scan** runs `acceptEdits` with `Bash(git:*)` — established since 07-10 and safety-gated (ff-only pull, dirty-tree abort, proven 07-12). The N3 model pin *reduces* nondeterminism; no permission widening anywhere in this report.
3. **SSH surface:** both directions already allowlisted (`ssh Vadim@gsadus-vadim:*` / `ssh User@vg-home:*`); the documented BatchMode/ConnectTimeout pattern prevents hangs; the remote-execution doc section (S3 landing) encodes temp-file cleanup. This audit's own remote pass followed it (scripts deleted after use; index-only transfer).
4. **Owner rulings honored, not re-flagged:** `skipDangerousModePermissionPrompt`, broad `Bash(git:*)`, pyRevit `bypassPermissions`, bridge deny-list skip, GSD stays parked.
5. **Junk-entry hygiene:** the work PC's `"--dangerously-skip-permissions"` permissions entry is inert but noise in a security-sensitive file — remove (N4).
6. **Stale recommendations guarded:** the S1 content that codified already-fixed bugs was caught and cut; N5's gate condition and machine-model facts are deliberately kept out of durable artifacts; no expired plan was codified (rule 7 check: `planning.md` re-affirmed 07-10; `repo-docs-housekeeping.md` is an evergreen convention, not a plan).
7. **Destructive actions isolated:** the only one recommended is the deliberate, re-verified stash drop (N4.3), with its verification procedure named.

## Prioritized Roadmap

### Phase 1 — Immediate (three changes)

1. **Context + memory pass (N1):** surgical CLAUDE.md trim (guards kept verbatim) + `/doctor` cross-check on Home; `consolidate-memory` on **both** machines (fix the 2 stale Home files, curate the frozen work-PC set, dedupe MEMORY.md).
2. **Track `C:\GSADUs\.claude\` (N2) + ignore-file hygiene (N4.1–2):** one commit touching `.gitignore` (un-ignore `.claude`, keep `settings.local.json` + `.wip-conflict.md` ignored, drop dead repo entries), `.ignore` (scope the `.claude/` exclusion down, drop dead entries), and `setup.ps1` (SETUP.md refs). Then reconcile the work PC's untracked settings on first pull and verify the wip-conflict hook fires there.
3. **Vault script sitting (N3):** `--model` pin + explicit headless flags in `wiki-scan.ps1`, the proposal carry-forward line, and the light-scan diagnosis (fix or remove the chaining — decided in the same sitting).

### Phase 2 — After validation

- **Build `repo-lifecycle`** (the one skill) once N2 has landed and survived one wip/unwip round-trip between machines; its first validation runs are the scorecard's three evals, and the AppSheetCatalog sunset is its natural live test.
- `remote-access.md` remote-execution section (S3 landing).
- Work-PC pass over SSH (N4.4): malformed permissions entry, memory curation if not done in Phase 1, hook-parity verification.
- Deliberate stash drop (N4.3).
- **Gates to watch:** S1 promotion gate (2+ post-fix re-derivation sessions → revisit the wip-conflict skill); `/handoff` generalization gate (WebApp skill validates over ~5 slices → per-repo clones); light-scan decision follow-through per rule 6.
- Cross-repo flags handed to Tools: `Write-WipConflictReport` stash-residuals extension.

### Phase 3 — Avoid for now

- Workspace plugin/local marketplace; `autoMemoryDirectory` re-pointing; chezmoi or any second config-sync mechanism; Obsidian skill-pack installs; `_health` triage skill; `gshelp`; heartbeat hooks; any workspace-level HANDOFF skill (wrong scope by verified mechanics); re-opening owner-closed permission items; anything touching the retired PostProcess repos.

## Suggested First Skill

**`repo-lifecycle`** — it is the only candidate whose failure mode is still live (dead entries on disk today, a queued retirement, an orphaning incident with a 9-day detection lag), whose trigger is unambiguous, and whose knowledge exists nowhere today except a commit message body and this audit. It should be **built second, used first**: land N2 in Phase 1 so the skill syncs, then author it (the built-in `skill-creator` fits) with the minimum scope above — SKILL.md checklists + `check-repo-registry.ps1`, nothing else. Deliberately excluded from v1: machine-local-state prose (referenced from `wip-sync.md`), GitHub-side automation (instructions + confirmation only), any auto-invocation. Evaluate on its first two real events (next repo add; AppSheetCatalog sunset): success = zero missed surfaces against this report's B1 reconstruction and a green consistency script on both machines. Not implemented in this audit, per the mandate.

## Execution Log (appended 2026-07-18, same day)

**Phase 1 — SHIPPED** (workspace `35f1b1a` → `d9c906b` → `3b19181` + this log commit; vault `9a746c4`). The one deviation from the roadmap, at owner instruction: `repo-lifecycle` was built today alongside Phase 1 rather than after an N2 wip round-trip — its cross-machine sync was verified by direct pull instead.

- **N2 + N4.1–2 (`35f1b1a`):** `C:\GSADUs\.claude\` is now tracked — `.gitignore` un-ignores `.claude/` (only `settings.local.json` stays ignored); the `.ignore` search exclusion scoped down to the same file; dead `BatchExportV1/`, `BatchExportV2/`, `revit-mcp/` entries pruned from both files; `setup.ps1` SETUP.md → BOOTSTRAP.md; both SessionStart hooks committed.
- **`repo-lifecycle` skill (`d9c906b`):** SKILL.md (add/rename/retire checklists, one line per surface; self-check rule binding the surface list to the script; wip-sync.md + workspaces.md referenced, never restated) + `scripts/check-repo-registry.ps1`. Validated both ways: **RED** pre-prune (flagged exactly the six dead BatchExport/revit-mcp entries — the audit's validation #3), **GREEN** post-prune (9 active, 2 retired), and **GREEN again on the work PC** after propagation.
- **N1 CLAUDE.md (`3b19181`):** surgical trim — retired-repos block compressed to a table, search-mechanism narrative tightened; both guard sentences kept verbatim; repo↔GitHub mapping and rules 1–7 untouched; added the one-line "Workspace Skills" pointer (sub-repo reachability, see scoping check below).
- **N1 memory — Home:** `consolidate-memory` pass. Retired `project_vault_phase1.md` (pre-dated maintained/owner model, cited deleted `wiki/inbox/`) → fresh `project_vault.md`; retired `project_postprocess_repos.md` ("archives stay in setup.ps1" false since 07-07; status now lives in CLAUDE.md's retired table); `MEMORY.md` rebuilt as a pure index (folder table deduped against CLAUDE.md; the AppSheetCatalog-sunset fact, which lived only in the index, moved to `project_appsheet_sunset.md`); `reference_workmachine_profile.md` rewritten around the canonical scp-a-script + pwsh pattern; stale pointers fixed in three more files. The 4 inert `gsd-*.js` hook files were **already gone** (hooks dir empty) — no action needed.
- **N1/N4.4 — Work PC (over SSH, scp-a-script pattern):** the 5 frozen files curated in place, not bulk-copied — `MEMORY.md` rewritten; `webcatalog-project.md` corrected (the "pending setup.ps1 add" claim was ~3 weeks stale); `design-bundles-hardening.md` reduced to a superseded-note (WebApp dashboard is the sole write surface; gsheet frozen legacy); `agent-context-files.md` updated (WebApp uses `@AGENTS.md`); `wip-unwip-workflow.md` kept with a 2026-07-18 authority note; 4 current Home files adopted (`feedback_stash_pop_conflict` — the audit's must-exist-on-both-machines call — `feedback_agent_launch_defaults`, `project_vault`, `project_appsheet_sunset`); `gws-cli.md` untouched. The malformed `"--dangerously-skip-permissions"` permissions entry removed from `C:\Users\Vadim\.claude\settings.json` (JSON re-validated). Backups left on the work PC: `memory.bak-2026-07-18`, `settings.json.bak-2026-07-18`. All remote temp scripts deleted after use.
- **N3 vault sitting (vault `9a746c4`, committed as wiki-agent):** `--model claude-opus-4-8` pinned (owner mandate; Invoke-WipConflictAgent precedent); deep-scan prompt now carries forward unapplied `_health.md` proposals across snapshot rewrites; headless context contract made explicit — `--setting-sources user,project,local` plus a guard comment. Docs re-verified 2026-07-18: `--bare` skips OAuth/keychain auth AND CLAUDE.md auto-discovery and *will become the `-p` default*; no `--no-bare` flag exists yet, so the guard comment instructs adding the explicit opt-out the moment it ships. A default flip today would fail **loudly** (auth error), not silently.
- **N2 rollout to the work PC:** pulled `eaf452a → 3b19181` cleanly over SSH. The feared untracked-`settings.json` collision **did not exist** — wip's `git add -A` honored `.gitignore`, so `.claude` content never ferried; only `settings.local.json` was present there. Hook file + skill verified on disk; consistency script green. Remaining: Claude Code's one-time project-hook trust prompt at the next interactive root session on that machine.

**Light-scan diagnosis — CLOSED: path healthy but unused (no code fix; no gsadus-tools commit warranted):**

- Mechanics verified working on BOTH machines: `claude` resolves inside `pwsh -NoProfile` (user-level PATH, `~\.local\bin\claude.exe` on each PC — not profile-added), and the exact `Start-Process pwsh -NoProfile … -WindowStyle Hidden` launch end-day uses was exercised successfully with `-DryRun` on both.
- Usage evidence (PSReadLine history, dated via file-mtime and rename anchors): Home's 15 `end-day` uses all pre-date 2026-07-08 (the 07-08 SSH-key-setup mtime anchors the tail; zero uses since). Work PC identical: its last `end-day` sits immediately before its 07-08 `Move-Item DesignBundles → WebApp` line, and the chaining code only reached that machine 2026-07-13 (Tools reflog). Zero light logs on either machine — fully consistent.
- Conclusion: nothing is broken — **`end-day` itself fell out of use on 2026-07-08**; both machines' history tails show the actual ritual is plain `wip-all`/`unwip-all`. **Recommendation to the owner:** either resume ending days with `end-day` (it is wip-all + light scan + screen lock — a superset of the current habit), or if it is still unused by the next audit (~1 month), remove the end-day scan chaining per rule 6 and rely on the weekly deep scan alone. Keeping the code meanwhile is a deliberate, documented decision with a stated review point, not a reflex fallback.

**Empirical scoping check (the flagged 2-minute verification):** a headless session started in `C:\GSADUs\WebApp` listed its available skills — WebApp's three project skills appear; `repo-lifecycle` does **NOT** (expected per the documented walk-up-to-repo-root scoping). The inherited CLAUDE.md "Workspace Skills" pointer is the reachability mechanism for sub-repo sessions. Side observation: that headless run warned WebApp's 10 `permissions.allow` entries are ignored until the one-time workspace trust dialog is accepted on VG-Home.

**Deferred to Phase 2 (unchanged):** `remote-access.md` remote-execution section (out of scope today); the deliberate stash drop (N4.3); the S1 promotion and `/handoff` generalization gates; the `Write-WipConflictReport` stash-residuals extension (Tools flag). Owner rulings honored throughout: `skipDangerousModePermissionPrompt`, broad `Bash(git:*)`, and pyRevit `bypassPermissions` not re-flagged; GSD stays parked; retired PostProcess repos untouched; wip-conflict and sync-machines remain rejected as skills.

## Research Sources

Retrieved 2026-07-18 by the External Researcher unless noted.

| Source | Publisher | Relevance |
|---|---|---|
| code.claude.com/docs — memory, large-codebases, skills, settings, hooks, headless, sessions, checkpointing, desktop-scheduled-tasks, discover-plugins | Anthropic | Verified scoping rules (CLAUDE.md inherits; settings/skills do not cross the child-repo boundary), ≤200-line guidance, `/doctor` trim, auto-memory limits, `--bare` direction, hook events/shell semantics on Windows |
| claude.com/blog "Steering Claude Code…" (2026-06-18) | Anthropic | CLAUDE.md-vs-skill-vs-rule decision framework |
| github.com/kepano/obsidian-skills; AgriciDaniel/claude-obsidian; eugeniughelbur/obsidian-second-brain | community (MIT) | Obsidian skill ecosystem — inspected, rejected (adapt nothing now) |
| chezmoi guides (frxiaobei.com, rymiwe gist, arun.blog, dev.to/dotwee) | community | `~/.claude` multi-machine sync patterns — rejected in favor of the existing Tools shim pattern |
| Matt Pocock handoff skill; steveclarke/dotfiles; robertguss/claude-code-toolkit | community | Handoff-brief convergence — confirms the in-house WebApp skill is the right base for later generalization |
| Session transcripts: 18 workspace-root + 1 Vault session fully indexed (both machines), 8 deep-dived; keyword scan over all 156 retained GSADUs sessions | Local | Primary recurrence evidence (dual-machine, breadth-first) |
| `user-workflow-patterns.md` (63-session cross-machine analysis, 2026-05-18→06-18) | Local (workspace memory) | Pre-retention-window baseline |
| Sibling audits: `WebApp\docs\skill-opportunity-audit.md`, `pyRevit\docs\skill-opportunity-audit.md` (2026-07-17) | Local | Cross-repo flags consolidated here; owner rulings |

---

**Final quality gate (self-check):** every recommendation carries transcript/commit/file evidence · transcript evidence spans both machines' full retained history breadth-first (index before deep-dive), with the retention limit and the preserved May–June baseline explicitly recorded · the one recommended Skill was tested against CLAUDE.md/rule/hook/script alternatives, and two draft Skills were killed by that test · installed plugins and built-ins were checked and three are reused (consolidate-memory, /doctor, skill-creator) rather than duplicated · every recommended script/hook change is pwsh 7 / Windows 11 compatible and repo-committed where sync matters, with machine-local actions explicitly flagged for both PCs and the N2 sequencing dependency stated · no recommendation depends on undocumented behavior (the one under-documented rules-inheritance case is flagged for a 2-minute empirical check during N2 rollout, not relied upon) · external code inspected, none installed · temporary facts and already-fixed bugs were caught by the Skeptical pass and kept out of durable artifacts · retired repos untouched · a zero-new-Skills outcome was genuinely considered and the report recommends exactly one · no Skill was created during this audit; this report is the only file written.
