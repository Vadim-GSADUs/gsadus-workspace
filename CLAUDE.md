# GSADUs Workspace

## Folder Structure

Each folder is an independent GitHub repo. Never nest projects inside one another.

```
C:\GSADUs\
├── AppSheetCatalog\      gsadus-appsheet-catalog       Google AppSheet catalog scripts
├── AppsScript\           gsadus-appsscript             Google Apps Script archive (clasp-managed)
├── BatchExportV1\        GSADUs.Revit.Addin            Revit addin — legacy batch export (V1)
├── BatchExportV2\        GSADUs.Revit.BatchExport      Revit addin — current batch export (V2)
├── PostProcess\
│   ├── DigitalDarkroom\  gsadus-digital-darkroom       AI image post-processing tool
│   └── PNGTools\         gsadus-png-tools              Batch PNG crop, rename, and audit tool
├── Tools\                gsadus-tools                  Office workflow utilities (.exe / PS1)
├── Vault\                gsadus-vault                  Obsidian knowledge vault
├── setup.ps1                                           Clones all repos to this structure
└── GSADUs.code-workspace                               VS Code / Cursor multi-root workspace
```

## Rules for AI Agents

1. **One repo = one direct subfolder of `C:\GSADUs\`.** Never create project files inside an existing repo folder unless you are actively working on that repo.
2. **New projects get their own repo and folder.** Do not add a new project as a subfolder of an existing repo.
3. **`PostProcess\` is a grouping folder, not a repo.** Sub-projects inside it each have their own repo.
4. **`AppsScript\` is a clasp-managed archive.** Google's environment is the source of truth. Run `clasp pull` inside a subfolder to get the latest before editing.
5. **Do not commit `*.addin` files to this workspace repo.** They belong in the `deploy\` folder of each Revit addin repo.

## Project Context — The Vault

All project context, workflows, planning, gaps, and tool documentation lives in the **Obsidian Vault** at `C:\GSADUs\Vault\`. Read `Vault\CLAUDE.md` for the vault schema and frontmatter conventions.

Key vault pages:
- `Vault\wiki\curated\key-locations.md` — all file paths and machine hostnames
- `Vault\wiki\curated\planning.md` — gaps, roadmap, automation candidates
- `Vault\wiki\auto\pipeline-image-export.md` — end-to-end image pipeline
- `Vault\wiki\curated\wip-sync.md` — cross-PC sync workflow

When starting a new session, read the relevant vault pages for context rather than expecting standalone docs at this root level.
