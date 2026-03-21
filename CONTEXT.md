# GSADUs — Integrated Workflow Context

> **Synced working memory for Claude Code across Home + Work PCs.**
> Source: `C:\Users\Vadim\.claude\projects\C--Users-Vadim\memory\`
> Last updated: 2026-03-20

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
| `BatchExportV1/` | Revit batch export add-in (C# .sln) — Active |
| `BatchExportV2/` | Next-gen batch export (C# .slnx) — In Dev |
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

## Open Items

- Pipeline currently segmented — steps run independently; goal is end-to-end integration
- DigitalDarkroom `vision_engine.py` — stub, not yet implemented
- BatchExport C# vs pyRevit: C# harder to test/debug blindly; pyRevit allows live iteration
- Selection Sets V2 actively being built to handle export — may supersede C# BatchExport tools
- Web export to 3rd-party not yet attempted — dependent on render volume
