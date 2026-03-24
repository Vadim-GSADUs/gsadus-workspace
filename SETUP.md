# GSADUs — New PC Bootstrap

One-time setup on any new machine. Do this once, then forget it.

## Prerequisites

Install these before anything else:

- [Git for Windows](https://git-scm.com/download/win)
- [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases) (`pwsh`)
- [GitHub CLI](https://cli.github.com/) (`gh`) — then run `gh auth login`

## Step 1 — Clone the workspace

```powershell
git clone https://github.com/Vadim-GSADUs/gsadus-workspace.git C:\GSADUs
```

> Private repos (AppSheetCatalog, BatchExportV2, DigitalDarkroom) require SSH or gh auth.
> Run `gh auth login` first if you haven't already.

## Step 2 — Clone all sub-repos

```powershell
cd C:\GSADUs
pwsh -File setup.ps1
```

This clones every sub-repo into its correct folder. Safe to re-run anytime.

## Step 3 — Wire up the PowerShell profile (one time only)

Add a single line to your `$PROFILE` that dot-sources `profile.ps1`:

```powershell
# Run this in PowerShell to append the line:
Add-Content $PROFILE ". C:\GSADUs\profile.ps1"
```

Then reload the shell (or open a new terminal). The `wip`, `unwip`, `wip-all`,
`unwip-all`, and `end-day` functions are now available.

> **Why this works:** `profile.ps1` lives in this repo. Every `unwip` pulls the
> latest version. The next shell start dot-sources it automatically — no
> re-running `setup.ps1`, no version checks, no manual steps.

## Step 4 — Verify

```powershell
Get-Command wip, unwip, wip-all, unwip-all, end-day
```

All five should resolve. If not, check that the `Add-Content` line above
was written to the correct profile path (`echo $PROFILE`).

## Optional — Register startup unwip

To automatically pull WIP changes when you log in:

```powershell
Register-StartupUnwip
```

Removes it:

```powershell
Unregister-StartupUnwip
```

## External dependencies (verify manually)

Revit addin manifests live outside the repos — copy them if Revit loads before you build:

- `BatchExportV1\src\GSADUs.Revit.Addin\deploy\GSADUs.Revit.Addin.addin`
- `BatchExportV2\deploy\GSADUs.Revit.BatchExport.addin`

Copy to: `%AppData%\Autodesk\Revit\Addins\2026\`
