param(
    [switch]$NonInteractive,  # skip Read-Host at end (used by unwip-all and scripts)
    [switch]$CloneOnly        # skip pulling existing repos, only clone missing (used by unwip-all)
)

# GSADUs Workspace Setup
# Clones all repos into the correct local folder structure.
# Safe to re-run — pulls latest if a repo already exists.
# Run once on a new PC, then never touch this file again.
#
# Usage:
#   pwsh -File setup.ps1
#   Right-click -> "Run with PowerShell"
#
# After cloning, see SETUP.md for one-time profile configuration.

$Root = "C:\GSADUs"

$repos = @(
    @{ Url = "git@github.com:Vadim-GSADUs/gsadus-appsheet-catalog.git";   Path = "AppSheetCatalog" },
    @{ Url = "git@github.com:Vadim-GSADUs/gsadus-appsscript.git";         Path = "AppsScript" },
    @{ Url = "git@github.com:Vadim-GSADUs/GSADUs.Revit.Addin.git";        Path = "BatchExportV1" },
    @{ Url = "git@github.com:Vadim-GSADUs/GSADUs.Revit.BatchExport.git";  Path = "BatchExportV2" },
    @{ Url = "git@github.com:Vadim-GSADUs/gsadus-digital-darkroom.git";   Path = "PostProcess\DigitalDarkroom" },
    @{ Url = "git@github.com:Vadim-GSADUs/gsadus-png-tools.git";          Path = "PostProcess\PNGTools" },
    @{ Url = "git@github.com:Vadim-GSADUs/gsadus-pyrevit.git";            Path = "pyRevit" },
    @{ Url = "git@github.com:Vadim-GSADUs/gsadus-tools.git";              Path = "Tools" },
    @{ Url = "git@github.com:Vadim-GSADUs/gsadus-vault.git";              Path = "Vault" }
)

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "    [OK]    $msg" -ForegroundColor Green }
function Write-Pull { param($msg) Write-Host "    [pull]  $msg" -ForegroundColor Yellow }
function Write-Skip { param($msg) Write-Host "    [skip]  $msg" -ForegroundColor DarkGray }

Write-Step "GSADUs Workspace Setup — Root: $Root"

# ── Step 1: Initialize C:\GSADUs as the workspace repo ───────────────────────
if (-not $CloneOnly) {
    Write-Step "Workspace root repo (gsadus-workspace)"
    $workspaceGit = Join-Path $Root ".git"
    if (Test-Path $workspaceGit) {
        Write-Pull "C:\GSADUs (gsadus-workspace)"
        Push-Location $Root
        git pull
        Pop-Location
    } else {
        Write-Ok "Initializing C:\GSADUs as gsadus-workspace"
        Push-Location $Root
        git init
        git remote add origin git@github.com:Vadim-GSADUs/gsadus-workspace.git
        git fetch origin
        git reset --hard origin/main
        Pop-Location
    }
}

# ── Step 2: Clone / pull all sub-repos ───────────────────────────────────────
Write-Step "Sub-repos"
foreach ($repo in $repos) {
    $localPath = Join-Path $Root $repo.Path
    if (Test-Path (Join-Path $localPath ".git")) {
        if ($CloneOnly) {
            Write-Skip $repo.Path
        } else {
            Write-Pull $repo.Path
            Push-Location $localPath
            git pull
            Pop-Location
        }
    } else {
        $parent = Split-Path $localPath -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Write-Ok "Cloning $($repo.Path)"
        git clone $repo.Url $localPath
    }
}

# ── Step 3: Git global config ────────────────────────────────────────────────
if (-not $CloneOnly) {
    Write-Step "Git global config"
    git config --global core.safecrlf false
    Write-Ok "core.safecrlf = false (suppress LF/CRLF warnings)"
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " Repos cloned to $Root" -ForegroundColor Green
Write-Host ""
if (-not $CloneOnly) {
    Write-Host " Next: follow SETUP.md for one-time profile configuration."
}
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

if (-not $NonInteractive) {
    Read-Host "Press Enter to exit"
}
