# GSADUs — Integrated Workflow Context

> **Synced working memory for Claude Code across Home + Work PCs.**
> Source: `C:\Users\Vadim\.claude\projects\C--Users-Vadim\memory\`
> Last updated: 2026-03-21
> Companion: `C:\GSADUs\PLANNING.md` — gaps, recommendations, automation candidates

---

## Role Matrix

| Role | Primary Domain | Key Tools |
|------|---------------|-----------|
| Revit BIM Manager | AEC/Construction | Revit, Dynamo |
| ADU Catalog Dev | Product/Design | Revit Families, DB |
| Software Developer | Engineering | Code, APIs |
| Workflow Integration Dev | Systems | Cross-domain glue |
| Revit Tool Builder | Tooling | Revit API, Dynamo, pyRevit |
| Database Manager | Data | GSheets, .db, AppSheet |

## Key Locations

- **Local repo**: `C:\GSADUs` (GitHub: https://github.com/Vadim-GSADUs/)
- **Shared drive**: `G:\Shared drives\GSADUs Projects\Our Models\0 - CATALOG`
- **Revit export output**: `G:\...\0 - CATALOG\Output\`
- **Revit catalog**: `G:\...\0 - CATALOG\2 - Revit\GSADUs Catalog.rvt`
- **pyRevit extension**: `G:\...\0 - CATALOG\2 - Revit\pyRevit\GSADUs_Tools.extension`
- **Rendered images (landing zone)**: `G:\...\0 - CATALOG\Working\Support\Rendered\` (root, sorted into subfolders by scanner)
- **Base images**: `G:\...\0 - CATALOG\Working\Support\PNG\`
- **GSheet catalog**: `G:\...\0 - CATALOG\Working\AppSheet GSADUs Catalog.gsheet`
- **Materials DB**: `G:\...\Interior Design Bundles\gsadus_materials.db`
- **Multi-PC**: Home + Work, synced via `setup.ps1`

## Active Priority

**Web renders by end of March 2026** — full pipeline must deliver rendered catalog images to 3rd-party web developer. Renders still being created; web export not yet attempted.

---

## Repo Structure (C:\GSADUs)

| Directory | Purpose |
|-----------|---------|
| `AppSheetCatalog/` | clasp-managed Apps Script — GSheet catalog sync, web export (active) |
| `AppsScript/` | Semi-archive for misc clasp projects (always `clasp pull` before editing — files go stale) |
| `BatchExportV1/` | Revit batch export add-in (C# .sln) — **Paused** (likely superseded by pyRevit) |
| `BatchExportV2/` | Next-gen batch export (C# .slnx) — **Paused** |
| `PostProcess/DigitalDarkroom/` | AI rendering engine (Streamlit + fal.ai) |
| `PostProcess/PNGTools/` | Image prep tools (aspect ratio, crop, filenames) |
| `Tools/` | Misc utilities (materials, Revit helpers — not pipeline-critical) |
| `setup.ps1` | Multi-PC repo sync script |

---

## Image Pipeline (End-to-End)

```
1. Revit Catalog (.rvt)
   │  BatchExport (V1/V2) or pyRevit Selection Sets V2 (actively adding export)
   │  Exports "Base Images": Floor Plans, 3D Plans, Elevations,
   │  Interior & Exterior Perspectives. Also: .csv, .pdf, .rvt
   │  Output lands at: G:\...\0 - CATALOG\Output\
   ▼
2. PNGTools  [PREP]
   │  Batch processing — hundreds of images:
   │  - Correct aspect ratios & buffer space
   │  - Normalize filenames (Model ID: A200-M1, B400-M3-ii)
   │  - Transparent/whitespace crop
   ▼
3. DigitalDarkroom  [RENDER]
   │  AI renders via fal.ai (Nano-Banana-2 / Aura-SR):
   │  - Architectural styles (ext/int), environments, design bundles
   │  - Batch matrix processing (style × environment combos)
   │  Outputs directly to Shared Drive:
   │  - High-res PNGs + _meta.json sidecars
   │  → G:\...\Working\Support\Rendered\ (root — scanner sorts into subfolders)
   ▼
4. Apps Script scanner picks up from Rendered root
   │  scanRenderedImages() — 6-phase Drive→Sheet sync:
   │  - Phase 1: orphan sorting from root into {Model ID}/ subfolders
   │  - Upsert + sidecar metadata enrichment
   │  - Rename/URL sync, deletion cleanup
   │  - Rendered Matrix dashboard sync (coverage: models × styles)
   │  Base images in: G:\...\Working\Support\PNG\
   ▼
5. GSheet Catalog (6 tabs)
   │  ADU Models, Base Images, Rendered Images,
   │  Design Bundles, User Data, Element Costs
   ▼
6. Downstream (not yet active — renders still being created)
   ├─ AppSheet app (mobile/web catalog)
   └─ web_export.js → external sheet → 3rd-party web dev
```

---

## pyRevit Extension — GSADUs Tools.tab

| Panel | Key Tools | Purpose |
|-------|-----------|---------|
| Prototype | DraftingView, Stories, Project Info, Styles, DetectMisalignment, ABL, AutoDim, Convert Patterns | BIM standards |
| Diagnostics | Diagnostics, Wall Core Analysis, Room Ceiling Analysis, AccentFloor V1/V2, Sandbox | Model QA |
| Modeling Tools | Downspout, RoofDripLine, JoinAll, Move/SwapAllByType, Cycle, Tag All/Manager, Unpaint, Delete Null Tags, SwapHosted, BatchWarnings, Design Bundles, LB Accent, Instance Editor, Camera (Manager + Runner + 3D Plan View) | Modeling automation |
| Families | Export Type Catalog, Place Catalog, Batch Delete/Edit Params, Bulk Upgrade, Type Manager, Remap Family, SharedParamAudit | Family management |
| Selection Sets V2 | Quick Select, Open Manager, Audit, Stage Set, Show Box, Sync Registry, Diagnostics | Selection management — **actively being updated for batch image export** |

---

## DigitalDarkroom Detail

- **Stack**: Streamlit UI + Python core + fal.ai API
- **Data**: `db_export.json` from `gsadus_materials.db` (refresh via `data/refresh_db_export.bat`)
- **Core**: prompt_engine, api_fal, image_processing, render_logger, settings, vision_engine (stub)
- **PromptBuilder API**: styles, environments, bundles → payload generation
- **Design Options**: persistent saved configs in `data/design_options.json`
- **Rule**: `core/` = pure Python only, zero Streamlit imports
- **Status**: Phase 1-5 complete

## Database Layer

| Name | Type | Purpose |
|------|------|---------|
| AppSheet GSADUs Catalog | GSheet | Master catalog (6 tabs) |
| gsadus_materials.db | SQLite | Styles, environments, design bundles |
| db_export.json | JSON cache | DigitalDarkroom runtime data |

### Apps Script (clasp)
- **Repo**: `C:\GSADUs\AppSheetCatalog`
- `scan_rendered_images.js` — Drive→Sheet sync (sidecar enrichment)
- `web_export.js` — ETL to external sheet (generatePreview → commitUpsert)
- `rendered_matrix.js` — coverage dashboard (models × styles rendered)
- `helpers.js` — config, Drive nav, `getColMap_()`

### Key Patterns
- Column-safe access via `getColMap_()` — no hardcoded indices
- AppSheet image paths relative to `Working/` folder
- Model ID format: `[A-Z]\d{3,4}-M\d+(-i|-ii|-iii|-iv)?` — shared across ALL tools
- Scanner safety: skips deletion when Drive returns 0 files

---

## Selection Sets V2 — Shared Library Detail

**Lib location:** `G:\...\2 - Revit\pyRevit\GSADUs_Tools.extension\lib`

15 shared Python modules coordinate all Selection Set tools. Key modules:

| Module | Role |
|--------|------|
| `selection_sets_core.py` | Read-only helpers — get sets, classify members, build capability snapshot |
| `selection_sets_audit.py` | Three-phase element collection + audit plan/apply/report |
| `selection_sets_sync.py` | GA population, CSV export, master sync orchestration |
| `selection_sets_registry.py` | Index GA instances by SetId; compat wrapper (old/new family names) |
| `selection_sets_state.py` | Staging state wrappers (`get_stage_record`, `get_origin_status`) |
| `stage_storage.py` | ExtensibleStorage on SelectionFilterElement (HomeCenterX/Y, IsStaged) |
| `selection_sets_select.py` | Picker UI table + element selection logic |
| `selection_sets_stage.py` | Move set to origin / restore to home; MoveFailureCollector for warnings |
| `selection_sets_showbox.py` | IBB visualization curves (`IBB` linestyle, `1ST FLOOR` target) |
| `selection_sets_manager.py` | Unified manager UI; routes to stage/select/showbox/manager modes |
| `selection_sets_workflows.py` | Orchestration entry points used by each tool's `script.py` |
| `export_settings_store.py` | Image export config (default: 1920×1080, PNG, 150 DPI) |
| `image_export_utils.py` | Format helpers: PNG/TIFF/JPEG/BMP/TARGA at 72/150/300/600 DPI |
| `print_set_utils.py` | Named Revit Print Set helpers |
| `selection_sets_validation.py` | Move validation stub (not yet implemented) |

### Key Constants
- `MODEL_GROUP_PARAM = "ModelGroup"` — on every model/detail element; links element → set name
- `SETID_PARAM = "SetId"` — on GA instances; links annotation → selection set UID
- `HELPER_COMMENT_TAG = "GSADUs IBB"` — prefix marking helper/visualization elements
- `COMPAT_FAMILY_NAMES = ("GSADUs Catalog", "GSADUs Registry")` — both names accepted
- Audit proximity buffer: `2.5 ft` XY, `±50 ft` Z around seed bounding box
- Staging bbox tolerance: `0.05 ft`
- Target plan view: `"1ST FLOOR"`

### Audit Workflow (selection_sets_audit.py)
Three-phase element collection driven by seed elements in the set:
1. **Phase A** — BoundingBoxIntersects filter: model elements within seed IBB + 2.5 ft XY, ±50 ft Z
2. **Phase B** — View-specific: plan view annotations and Area elements intersecting IBB
3. **Phase C** — Constraints: AreaSchemeLines and RoomSeparationLines within IBB

Seed categories:
- **Audit seeds** (for A/B/C collection): Walls, Floors, Roofs
- **Origin seeds** (for center/staging): Walls, Columns, Structural Columns

Member role classification: `missing` | `helper_visualization` | `helper_registry_ga` | `annotation` | `seed_audit` | `seed_origin` | `support_view_specific` | `member`

### Sync Registry Workflow (selection_sets_sync.py)
`run_sync_registry_workflow()` → `sync_annotations_and_counts()` → `run_exports_after_sync()`

**Step 1 — GA population:** Creates/moves/updates GenericAnnotation instances on `1ST FLOOR` view. One GA per selection set, linked by `SetId` + `ModelGroup`.

**GA parameters computed per set:**

| GA Parameter | Source |
|---|---|
| `Bed` | Count of rooms with "bed" in name |
| `Bath` | Count of rooms with "bath" in name |
| `Width` | Bounding box of walls (X span) |
| `Length` | Bounding box of walls (Y span) |
| `MG Interior Conditioned` | Sum of "1 Interior Conditioned" areas |
| `MG Interior Unconditioned` | Sum of "2 Interior Unconditioned" areas |
| `MG Exterior Covered` | Sum of "3 Exterior Covered" areas |
| `MG Exterior Uncovered` | Sum of "4 Exterior Uncovered" areas |
| `Ridge Height` | Z-max from roof geometry |
| `Roof Slope` | Slope from dominant sloped roof face |
| `Roof Type` | Classified: Flat / Monoslope / Gable / Hip |

**Step 2 — CSV exports:**
- **Elements CSV** → `{model_title}_Elements.csv`
  - Fields: `ModelGroup, Category, Family, Type, Area Type, Area, Volume, Length, Depth, Width, Height, Thickness, Perimeter`
- **Registry CSV** → `{model_title}_Registry.csv` (exported from Revit's named "Registry" schedule)
- **Export directory:** `G:\...\Working\Support\CSV\`
- Current canonical output: `GSADUs Catalog_Registry.csv`

### Staging (stage_storage.py + selection_sets_stage.py)
ExtensibleStorage schema on `SelectionFilterElement` (schema GUID: `d3f2a1b0-...`):
- `HomeCenterX`, `HomeCenterY` (Double, internal feet) — recorded on first stage
- `IsStaged` (Int32) — 1 = at origin, 0 = at home

Stage Set moves all set elements to (0,0,0) for batch processing; unstage restores to home.

### Future Integration
- GA parameters + Registry CSV → AppSheet GSADUs Catalog sync (not yet active; currently local CSV only)
- Selection Sets V2 batch export capability in active development (may supersede C# BatchExport)

---

## Design Bundles — Interior Material Packages

Design Bundles are pre-selected material packages (e.g., cabinet finishes, hardware, countertops, wall paint) offered to ADU buyers. The goal is to apply these bundles inside Revit so that interior camera views render with the correct colors and materials, giving DigitalDarkroom better source images for AI rendering.

### Current Status
- **Proof of concept only** — Revit materials and `gsadus_materials.db` entries exist but are not yet matched to actual real-world design bundle materials
- **TODO:** Full material definition pass — map every bundle option to real Revit materials with correct colors and hatch patterns

### Revit Tool — Design Bundles.pushbutton
**Location:** `GSADUs Tools.tab > Modeling Tools.panel > Design Bundles.pushbutton`
**Pre-shared-lib architecture** — has its own internal modules (`mapping_storage.py`, `mapping_engine.py`, `schedule_helpers.py`, `mapping_ui.py`); not yet integrated with `lib/`

**How it works:**
- Reads room parameters (Usage Keys, e.g., `INT_Cab_Finish_Kitchen`, `INT_Hardware_Finish`) to get material names
- Looks up those material names in Revit's material library
- Applies materials to elements using one of three modes:

| Mode | What it does |
|------|-------------|
| `paint` | Paints all geometry faces with material (doc.Paint) |
| `change_type` | Duplicates a template type with material set in compound layer 0; renames as `{template} - {material}` |
| `param_only` | Writes material Id to instance parameter (partially implemented) |

**Two processing tracks:**
1. **System Families** (Walls, Floors, Ceilings, Roofs, Columns, Stairs, Railings, Curtain Walls) — configured per category with optional filter parameter on type
2. **Component Families** (Casework, Plumbing Fixtures, etc.) — configured via mapping rules: Usage Key → target instance parameters (e.g., "Cabinet Material", "Door Inlay Material")

**Key Schedule dependency:** Tool uses Revit Key Schedules to structure room parameters. The primary Key Schedule (e.g., "Key - BUNDLES by Room (script)") defines which room parameters are bundle-driven. Not all bundle logic is visible in code — some context lives in the Key Schedules themselves.

**Scope options:** All accent elements in model, or selected elements only.

**Settings persistence:** ExtensibleStorage on the document (schema GUID: `B7E94A5C-3D8F-4E12-A6C9-1F2B3D4E5F6A`); also importable/exportable as JSON.

### Connection to Export Workflow
Design Bundles → applied to Revit model → interior camera views exported with correct material appearance → DigitalDarkroom has better base images → AI rendering is more accurate per bundle.

The batch processing capability (all elements in one transaction, scope filtering) makes this a candidate for driving **per-bundle export runs**: apply bundle A → export cameras → apply bundle B → export cameras → etc.

### Integration TODOs
- Material definition: match all bundle options to real Revit materials (colors + hatch patterns)
- Integrate tool modules into shared `lib/` (currently standalone)
- Connect to batch image export pipeline (Selection Sets V2 / BatchExport)
- `gsadus_materials.db` bundles → Revit material sync (currently manual)

---

## Cost Estimator — Back Burner

**Status:** Built but not implemented. Needs review and refactoring before use.
**File:** `G:\...\Working\Cost Estimator.xlsx` (source: .gsheet)
**Apps Script:** `C:\GSADUs\AppsScript\Cost Estimator\scenarios.gs`

### What It Does
General-purpose ADU construction cost calculator designed to accept a wide range of input precision:
- **Ambiguous:** "439 SF, 1 bed, 1 bath" → Auto column derives all other values
- **Refined:** Full Revit-exported data + manually filled overrides per row

### Calcs Tab — Column Structure
Every row is a unique input (quantity, material dropdown, bool, etc.). Each row follows this pattern:

| Col | Role | Detail |
|-----|------|--------|
| A | Category code | CSI division reference |
| B | Description | Row label |
| C | Override/Input | User-supplied precise value — blank = let Auto drive |
| D | Auto | Default calculated from minimal inputs (statistical assumptions) |
| E | Final | `=IF(C="", D, IF(C="Yes", TRUE, IF(C="No", FALSE, C)))` — C wins if present |
| F | Cost per unit | Unit rate from Cost Sheet lookup |
| G | Adjustment factor | Per-row multiplier — placement here (column vs input row) is still under review |
| H | Adjusted cost | Computed from Final × unit cost × adjustment |
| I | Notes | Misc info, flags |

**Key design principle:** Every row has a precise override slot (Col C). Users can go from zero overrides (fully auto) to fully specified — any mix is valid.

### Inputs Collected (representative rows)
- Location: address → county/AHJ → distance multiplier
- Livable SF (named range `Livable`), garage, covered porch, uncovered flatwork, raised deck
- Beds (named range `Beds`), baths (named range `Baths`) — auto-derived from SF if blank
- Roof: length, width, plate height, overhang, shape (Gable/Hip/Flat), material
- Envelope: exterior wall material, windows (qty + type), doors
- Systems: fire sprinklers, solar (auto-mandated >750 SF, size from zip code climate zone)
- Fees: impact fees, school fees, utility connections, permit costs

### Division Percent Breakdown Columns (after Col I)
Columns beyond I allocate each row's cost across the **20 CSI divisions** as percentages. This serves two purposes:
1. **Preliminary budgets** — project managers get division-level cost breakdowns before work starts
2. **Post-project calibration** — compare theoretical allocations vs. real expense accounts once a job closes, to refine future estimates

### Outputs
- Total construction cost + indirect costs/fees (K3, L3)
- Cost per SF (K3 / livable SF)
- Per-division cost breakdown

### Scenarios Sheet + Apps Script (`scenarios.gs`)
`runCostSweep()` iterates a matrix of SF × bed/bath combos, pushing each into the Calcs named ranges (`Livable`, `Beds`, `Baths`), flushing recalc, reading `K3`, and writing the result back to the Scenarios sheet with color-coded classification:

| Classification | Condition | Color |
|---|---|---|
| INVALID | Hard impossible (SF<250, baths>beds+1, etc.) | Medium grey — cell cleared |
| UNLIKELY | Technically possible but impractical | Light grey |
| QUESTIONABLE | Plausible but atypical (oversized studio, large unit with 1 bath) | Light yellow |
| VALID | Normal scenario | White |

Min SF thresholds: Studio 250/300, 1bed 350/400, 2bed 600/650, 3bed 900/950, 4bed 1050/1100 (strict/plausible).

If beds/baths are blank in the scenario header, the script clears those named ranges and lets Calcs auto-assume — so the sweep supports both explicit and auto-derived scenarios in the same run.

### Known Issues / TODOs
- Needs full review and refactoring before use
- Col G adjustment factors — open question whether they belong as column multipliers or as dedicated input rows
- Col H adjusted cost structure — needs review for correctness
- External IMPORTRANGE dependency (Google Sheets climate zone data for solar) — breaks in .xlsx copy
- No connection to Revit data or AppSheet catalog yet — Registry CSV exports (Bed, Bath, Width, Length, area breakdowns) are a natural future input source

---

## Cross-Domain Dependency Map

```
BIM Workflows ←→ ADU Catalog ←→ Database ←→ AppSheet
      ↕                              ↕
Revit Tools  ←→ Software Dev ←→ Integration (touches all)
```

Changes in one domain ripple to others. Always check connected domains.

## Cross-PC Setup Rules

- `setup.ps1` is the source of truth for new PC setup — clones all repos and installs the PowerShell profile
- **Whenever profile functions (`wip`, `unwip`, etc.) change, `setup.ps1` must be updated in the same commit**
- The profile lives in OneDrive and syncs automatically — `setup.ps1` is only needed on a PC that hasn't signed into OneDrive yet
- Version check in `setup.ps1` detects stale profiles by looking for `force-with-lease` — update this marker if the check logic changes

## Decision Log

| Date | Decision | Domains | Status |
|------|----------|---------|--------|
| 2026-03-20 | Selection Sets V2 actively gaining batch image export capability | Revit Tools, BIM, Pipeline | In progress |
| 2026-03-20 | Shared lib (`lib/`) established as single source of truth for all Selection Set tool logic | Revit Tools | Active |
| 2026-03-20 | Registry CSV export is current bridge from Revit to downstream catalog; AppSheet direct sync planned but not active | BIM, Database, AppSheet | Planned |
| 2026-03-20 | Design Bundles tool is proof of concept — Revit materials not yet matched to real bundle materials; full definition pass is a TODO | Revit Tools, Design Bundles | TODO |
| 2026-03-21 | BatchExport C# development paused — likely shifting batch image export fully into pyRevit / Selection Sets V2 | Revit Tools, Pipeline | Decision pending |
| 2026-03-21 | IDEA: Discovery agent — scheduled automation that scrapes codebase/tools and maintains CONTEXT.md big picture | All | Future TODO |

## Open Items

- Pipeline currently segmented — steps run independently; goal is end-to-end integration
- DigitalDarkroom `vision_engine.py` — stub, not yet implemented
- BatchExport C# development paused — considering full shift to pyRevit given simpler dev/debug cycle and live iteration
- Selection Sets V2 actively being built to handle export — likely supersedes C# BatchExport tools
- Web export to 3rd-party not yet attempted — dependent on render volume
