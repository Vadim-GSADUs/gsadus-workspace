# GSADUs — Planning, Gaps & Recommendations

> **Purpose:** Analytical working document for tracking pipeline gaps, integration opportunities, feature ideas, and automation candidates.
> Companion to `CONTEXT.md` (which describes *what exists*) — this file describes *what's missing, broken, or worth building next*.
> Intended audience: human developers + AI discovery/planning agents.
> Last updated: 2026-03-22

---

## How to Use This File

- **Humans:** Use this to orient before starting any new development. Check "Active Priorities" first, then relevant sections.
- **AI Discovery Agent:** On each run, re-read `CONTEXT.md`, scan key directories for changes, then return here to update statuses, add new gaps found, and reprioritize. Focus effort on sections marked `[NEEDS INVESTIGATION]`.

---

## Active Priorities

| Priority | Item | Deadline | Status |
|----------|------|----------|--------|
| 🔴 HIGH | Web renders delivered to 3rd-party dev | End of March 2026 | `web_export.js` never run — **critical path** |
| 🔴 HIGH | Render volume sufficient for web export | End of March 2026 | Renders still being created |
| 🟡 MED | Design Bundle material definitions | No deadline | Proof of concept only — blocks interior render accuracy |
| 🟡 MED | Selection Sets V2 batch image export | No deadline | In active development |
| 🟢 LOW | Cost Estimator refactor | No deadline | Back burner — needs review before use |

---

## Pipeline Gaps

Gaps are broken or missing connections in the end-to-end image pipeline. These are the highest-leverage items because they block the full workflow from running.

### GAP-01 — `web_export.js` Never Executed
**Between:** GSheet Catalog → External sheet → 3rd-party web dev
**Impact:** Critical — this is the final delivery step for the March 2026 deadline
**Blocker:** Render volume not yet sufficient; web export not yet attempted
**Next action:** Run `web_export.js` in test mode against current catalog data to validate the ETL before renders are complete. Don't wait for full render coverage to discover schema issues.

### GAP-02 — Pipeline Steps Run Independently (No Orchestration)
**Between:** All steps
**Impact:** High — each step (PNGTools → DigitalDarkroom → Scanner → GSheet) is triggered manually
**Detail:** No handoff automation between steps. A completed render batch requires manual intervention at each stage transition.
**Next action:** Define trigger points. Even simple file-watcher scripts or a manual "run next step" button in pyRevit would reduce friction significantly.

### GAP-03 — Per-Bundle Interior Export Loop Missing
**Between:** Design Bundles tool → Camera export → DigitalDarkroom
**Impact:** High — this is the core interior render workflow and it doesn't exist end-to-end
**Detail:** The pieces exist separately: Design Bundles applies materials, Camera Runner exports views, DigitalDarkroom processes images. Nothing orchestrates them as a loop (apply bundle A → export → apply bundle B → export → ...).
**Dependency:** Blocked by GAP-05 (material definitions incomplete) and Selection Sets V2 export capability
**Next action:** Once Selection Sets V2 export is functional, design the orchestration script in pyRevit

### GAP-04 — Registry CSV → AppSheet Not Automated
**Between:** Revit Sync Registry → GSheet Catalog
**Impact:** Medium — model metadata (beds, baths, areas, dimensions) reaches GSheet manually via CSV
**Detail:** `run_sync_registry_workflow()` exports to `G:\...\Working\Support\CSV\GSADUs Catalog_Registry.csv`. The Apps Script infrastructure to ingest CSVs already exists in `scan_rendered_images.js` patterns — the pattern just hasn't been applied to registry data.
**Next action:** Add a `sync_registry_csv.js` Apps Script that reads the Registry CSV and upserts into the ADU Models tab

### GAP-05 — Design Bundle Materials Undefined
**Between:** Design Bundles tool → Revit material library
**Impact:** Medium (blocks interior render accuracy)
**Detail:** Both `gsadus_materials.db` and Revit material library contain placeholder/proof-of-concept entries. One bundle exists nearly complete for testing, but full material definition pass has not been done.
**Next action:** Material definition sprint — match every bundle option to real Revit materials with correct colors, hatch patterns, and render appearance

### GAP-06 — Camera Tools Undocumented
**Between:** Camera Manager + Runner (pyRevit) → export output
**Impact:** Medium — these tools generate the actual view images that feed the pipeline, but their behavior, output format, and naming conventions are not captured in CONTEXT.md
**Status:** `[NEEDS INVESTIGATION]` — Discovery agent should read Camera Manager/Runner scripts and document
**Next action:** Read Camera tool scripts; document view selection logic, output paths, filename format

### GAP-07 — `vision_engine.py` Intent Identified — Not Yet Implemented
**In:** DigitalDarkroom (`PostProcess/DigitalDarkroom/core/vision_engine.py`)
**Impact:** Low (stub — not blocking anything currently)
**Detail:** Original intent is now defined — see INT-06 below. The stub should eventually become the home for the render-worthiness classifier. Not urgent; does not block the March 2026 deadline.
**Next action:** Implement once INT-06 approach is validated (see INT-06)

---

## Integration Opportunities

Things that *could* connect but currently don't. Lower urgency than Gaps but high long-term value.

### INT-01 — Registry CSV → Cost Estimator
The Registry CSV already exports `Bed`, `Bath`, `Width`, `Length`, and all area breakdowns per model. The Cost Estimator's named ranges (`Livable`, `Beds`, `Baths`) are the input surface. These are a natural match.
**Value:** Pre-populate cost estimates directly from Revit model data with no manual entry
**Effort:** Low-medium (Apps Script or Python bridge)
**Dependency:** Cost Estimator refactor (GAP area) should happen first

### INT-02 — `gsadus_materials.db` → Revit Material Sync
Materials are defined in the SQLite DB but applied manually in Revit. A pyRevit tool could read `db_export.json` and create/update Revit materials to match bundle definitions.
**Value:** Single source of truth for bundle materials; eliminates manual Revit material management
**Effort:** Medium (pyRevit + Revit material API)

### INT-03 — Design Bundles Tool → Shared `lib/`
The Design Bundles pushbutton has its own internal modules (`mapping_storage.py`, `mapping_engine.py`, etc.) predating the shared `lib/` architecture. Migrating would improve consistency and reduce maintenance surface.
**Value:** Consistency, shared patterns (ExtensibleStorage, error handling)
**Effort:** Medium — functional, so low urgency; refactor when touching the tool for other reasons

### INT-04 — Rendered Matrix Dashboard → Render Queue
`rendered_matrix.js` tracks which model × style combos have been rendered. This coverage data could drive DigitalDarkroom's batch queue automatically — only rendering missing combinations.
**Value:** Eliminates manual tracking of what still needs rendering
**Effort:** Medium (read matrix from GSheet, generate queue config for DigitalDarkroom)

### INT-06 — Render-Worthiness Classifier (Prototype Built, Not Validated)
**Between:** Revit image export → DigitalDarkroom render queue
**Status:** Prototype only — untested, not part of active workflow
**Problem:** 364 exterior perspective images were exported (4 angles × 91 models). Not all angles show a primary entry feature (front door, covered porch, patio with sliding/French doors). Sending unworthy images to DigitalDarkroom wastes fal.ai API credits on angles that would never be used.
**Proposed solution:** Claude vision API classifier — sends each image to `claude-sonnet-4-6` with a structured prompt, gets YES/NO + confidence + reason per image, writes a `render_audit.csv` for human review before any render batch is submitted.
**Prototype location:** `C:\GSADUs\PostProcess\PNGTools\PNG_RenderAudit.py` + `core/render_audit.py`
**Trial status:** Script runs correctly; halted on first test due to no Anthropic API credits on the test account. Accuracy not yet validated.
**Cost estimate (when ready to test):** ~$1–2 for full 364-image run at Sonnet pricing; ~$0.30 with Haiku.
**Filename convention note:** Camera angle is encoded in the filename (e.g., `A400-M3 Ext_225.png` = 225° = SW). Could be used as a cheap pre-filter once per-model entry orientations are known, reducing vision API calls by 40–60%.
**Natural long-term home:** `vision_engine.py` in DigitalDarkroom (currently a stub).
**Next action:** Add Anthropic API credits → run 20-image trial → review accuracy → decide whether to productionize or drop.

### INT-05 — Selection Sets V2 → Design Bundles Coordination
Currently separate tools. A coordinated workflow would: (1) select a model set, (2) apply a bundle, (3) trigger camera export — all from a single pyRevit command.
**Value:** Reduces the per-bundle export loop from a multi-step manual process to one button
**Effort:** High (requires GAP-03 orchestration work)

---

## Feature Roadmap

Ranked roughly by dependency order — earlier items unblock later ones.

### Phase A — Close the March 2026 Deadline
1. Test `web_export.js` against current data (GAP-01)
2. Validate filename/URL/schema consistency between GSheet and web dev's expectations
3. Establish render delivery process (manual trigger or scheduled)

### Phase B — Stabilize the Core Pipeline
4. Complete Selection Sets V2 batch export (in progress)
5. Document Camera tools (GAP-06)
6. Design the per-bundle export loop orchestration (GAP-03)
7. Automate Registry CSV → GSheet sync (GAP-04)

### Phase C — Deepen Data Quality
8. Design Bundle material definition pass (GAP-05)
9. `gsadus_materials.db` → Revit material sync tool (INT-02)
10. Per-bundle interior render runs (depends on Phase B + Phase C above)

### Phase D — Integration & Intelligence
11. Registry CSV → Cost Estimator bridge (INT-01)
12. Rendered Matrix → DigitalDarkroom queue automation (INT-04)
13. Unified pyRevit export orchestration (INT-05)
14. Cost Estimator refactor + AppSheet integration

### Phase E — Automation Infrastructure
15. Discovery agent + scheduled CONTEXT/PLANNING maintenance (see Automation Candidates below)
16. `vision_engine.py` — define and implement or remove

---

## Automation Candidates

Tasks that are currently manual, repetitive, and well-defined enough to automate.

| ID | Task | Current State | Automation Approach | Effort |
|----|------|---------------|---------------------|--------|
| AUTO-01 | Registry CSV → GSheet upsert | Manual CSV, then manual import | Apps Script triggered on file change or scheduled daily | Low |
| AUTO-02 | Rendered Matrix coverage update | Runs on scanner trigger | Already partially automated via `rendered_matrix.js` — verify it runs on schedule | Low |
| AUTO-03 | DigitalDarkroom render queue from coverage gaps | Manual queue setup | Read matrix from GSheet, write queue config | Medium |
| AUTO-04 | Per-bundle Revit export loop | Fully manual | pyRevit orchestration script (depends on export + bundle tools) | High |
| AUTO-05 | CONTEXT.md + PLANNING.md maintenance | Manual (this session) | Discovery agent — see below | Medium |

---

## Discovery Agent — Design Notes

An AI agent that periodically explores the codebase and shared drive, then updates `CONTEXT.md` and `PLANNING.md` with what's changed or newly undocumented.

### What It Should Do
1. Read `CONTEXT.md` and `PLANNING.md` as baseline
2. Run targeted scans:
   - `git log --since="7 days ago"` — what changed in the repo
   - Glob new/modified `.py` files in pyRevit extension
   - Check CSV export directory for new files
   - Check Rendered root for new images
3. Compare findings to CONTEXT.md — flag anything new, renamed, removed, or contradicted
4. Update gap statuses in PLANNING.md (e.g., mark a gap as resolved if the code now exists)
5. Add new gaps or integrations discovered
6. Update `Last updated` dates

### What It Should NOT Do
- Make code changes
- Delete or overwrite working context without flagging the diff first
- Run Revit or modify the GSheet

### Trigger Options (from simplest to most sophisticated)
| Approach | How | Notes |
|----------|-----|-------|
| **Manual** | Run `claude -p "..."` in terminal when desired | Zero setup — start here |
| **Windows Task Scheduler** | `.ps1` script calls `claude` CLI on a schedule | Simple, no dependencies |
| **Claude Code hooks** | Post-session hook writes a summary | Fires after every session — may be too frequent |
| **Git post-commit hook** | Trigger on commit to GSADUs repo | Event-driven, relevant timing |
| **GSD autonomous agent** | `/gsd:autonomous` or `/gsd:next` | GSD framework already available — worth exploring |

### Recommended Starting Point
Before building anything scheduled: write a single prompt that can be run manually (`! claude -p "..."` or as a slash command) that does the discovery scan and produces a diff of what should change in CONTEXT.md and PLANNING.md. Get that working reliably first, then consider scheduling it.

---

## Resolved Items

*(Move items here from Gaps/Opportunities when closed, with resolution date and brief note)*

| Date | Item | Resolution |
|------|------|------------|
| — | — | — |
