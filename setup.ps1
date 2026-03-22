# GSADUs Workspace Setup
# Clones all repos into the correct local folder structure.
# Safe to re-run — pulls latest if a repo already exists.
#
# Usage:
#   pwsh -File setup.ps1
#   Right-click -> "Run with PowerShell"

$Root = "C:\GSADUs"

$repos = @(
    @{ Url = "https://github.com/Vadim-GSADUs/gsadus-appsheet-catalog.git";   Path = "AppSheetCatalog" },
    @{ Url = "https://github.com/Vadim-GSADUs/gsadus-appsscript.git";         Path = "AppsScript" },
    @{ Url = "https://github.com/Vadim-GSADUs/GSADUs.Revit.Addin.git";        Path = "BatchExportV1" },
    @{ Url = "https://github.com/Vadim-GSADUs/GSADUs.Revit.BatchExport.git";  Path = "BatchExportV2" },
    @{ Url = "https://github.com/Vadim-GSADUs/gsadus-digital-darkroom.git";   Path = "PostProcess\DigitalDarkroom" },
    @{ Url = "https://github.com/Vadim-GSADUs/gsadus-png-tools.git";          Path = "PostProcess\PNGTools" },
    @{ Url = "https://github.com/Vadim-GSADUs/gsadus-tools.git";              Path = "Tools" }
)

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "    [OK]    $msg" -ForegroundColor Green }
function Write-Pull { param($msg) Write-Host "    [pull]  $msg" -ForegroundColor Yellow }
function Write-Skip { param($msg) Write-Host "    [skip]  $msg" -ForegroundColor DarkGray }

Write-Step "GSADUs Workspace Setup — Root: $Root"

# ── Step 1: Initialize C:\GSADUs as the workspace repo ───────────────────────
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

# ── Step 2: Clone / pull all sub-repos ───────────────────────────────────────
Write-Step "Sub-repos"
foreach ($repo in $repos) {
    $localPath = Join-Path $Root $repo.Path
    if (Test-Path (Join-Path $localPath ".git")) {
        Write-Pull $repo.Path
        Push-Location $localPath
        git pull
        Pop-Location
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
Write-Step "Git global config"
git config --global core.safecrlf false
Write-Ok "core.safecrlf = false (suppress LF/CRLF warnings)"

# ── Step 4: Install PowerShell profile (wip / unwip) ─────────────────────────
Write-Step "PowerShell profile (wip / unwip)"
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
$wipBlock = @'
# Git WIP shortcuts - sync work between office and home PCs
$GSADUsRoot = "C:\GSADUs"

function Get-WipRepos {
    # Only include repos owned by Vadim-GSADUs (skips third-party forks)
    $candidates = @()
    if (Test-Path "$GSADUsRoot\.git") { $candidates += $GSADUsRoot }
    Get-ChildItem $GSADUsRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if (Test-Path "$($_.FullName)\.git") { $candidates += $_.FullName }
        Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if (Test-Path "$($_.FullName)\.git") { $candidates += $_.FullName }
        }
    }
    $repos = @()
    foreach ($c in $candidates) {
        Push-Location $c
        $url = git remote get-url origin 2>$null
        if ($url -match "Vadim-GSADUs") { $repos += $c }
        Pop-Location
    }
    $repos
}

# -- single-repo commands (run from inside a repo) ----------------------------
function wip {
    git add -A
    git commit -m "wip: $(Get-Date -Format 'yyyyMMdd-HHmm')"
    git push --force-with-lease
}

function unwip {
    git pull
    $msg = git log -1 --format="%s" 2>$null
    if ($msg -match "^wip:") { git reset HEAD~1 }
    else { Write-Host "  (last commit is not a wip - pull only)" -ForegroundColor DarkGray }
}

# -- all-repo commands (run from anywhere) ------------------------------------
function wip-all {
    foreach ($repo in Get-WipRepos) {
        Push-Location $repo
        $rel = $repo.Replace($GSADUsRoot, "").TrimStart("\")
        if (-not $rel) { $rel = "." }
        $dirty    = git status --porcelain 2>$null
        $unpushed = git log "@{u}..HEAD" --oneline 2>$null
        if ($dirty) {
            Write-Host "  wip  $rel" -ForegroundColor Cyan
            git add -A
            git commit -m "wip: $(Get-Date -Format 'yyyyMMdd-HHmm')" -q
            git push --force-with-lease -q
        } elseif ($unpushed) {
            Write-Host "  push $rel (unpushed commits)" -ForegroundColor Yellow
            git push --force-with-lease -q
        } else {
            Write-Host "  skip $rel (nothing to commit)" -ForegroundColor DarkGray
        }
        Pop-Location
    }
}

function unwip-all {
    foreach ($repo in Get-WipRepos) {
        Push-Location $repo
        $rel = $repo.Replace($GSADUsRoot, "").TrimStart("\")
        if (-not $rel) { $rel = "." }
        Write-Host "  unwip $rel" -ForegroundColor Cyan
        git pull -q
        $msg = git log -1 --format="%s" 2>$null
        if ($msg -match "^wip:") { git reset HEAD~1 }
        Pop-Location
    }
}

function end-day {
    Write-Host ""
    Write-Host "Saving work across all repos..." -ForegroundColor Cyan
    wip-all
    Write-Host ""
    Write-Host "PC shuts down in 15 min.  Run 'shutdown /a' to cancel." -ForegroundColor Yellow
    shutdown /s /t 900
}

# -- startup task helpers -----------------------------------------------------
function Register-StartupUnwip {
    $profilePath = $PROFILE
    $cmd = ". '$profilePath'; unwip-all"
    $action   = New-ScheduledTaskAction -Execute "pwsh" -Argument "-NoExit -Command $cmd"
    $trigger  = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName "GSADUs-unwip-all" -Action $action `
        -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null
    Write-Host "Startup unwip registered. Opens a terminal on next login." -ForegroundColor Green
}

function Unregister-StartupUnwip {
    Unregister-ScheduledTask -TaskName "GSADUs-unwip-all" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Startup unwip removed." -ForegroundColor Yellow
}
'@
if (-not (Test-Path $PROFILE)) {
    Set-Content $PROFILE $wipBlock
    Write-Ok "Created profile at $PROFILE"
} elseif (-not (Select-String -Path $PROFILE -Pattern "force-with-lease" -Quiet)) {
    Set-Content $PROFILE $wipBlock
    Write-Ok "Upgraded wip/unwip in profile at $PROFILE"
} else {
    Write-Skip "wip/unwip already up to date — skipped"
}
. $PROFILE

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " Workspace ready at $Root" -ForegroundColor Green
Write-Host ""
Write-Host " Next steps on a new PC:"
Write-Host "   1. Open GSADUs.code-workspace in VS Code / Cursor"
Write-Host "   2. Build BatchExportV1 or V2 — the build auto-copies the"
Write-Host "      .addin manifest to %AppData%\Autodesk\Revit\Addins\2026\"
Write-Host ""
Write-Host " External file dependencies to verify manually:"
Write-Host "   - Revit addin manifests in %AppData%\Autodesk\Revit\Addins\2026\"
Write-Host "       BatchExportV1\src\GSADUs.Revit.Addin\deploy\GSADUs.Revit.Addin.addin"
Write-Host "       BatchExportV2\deploy\GSADUs.Revit.BatchExport.addin"
Write-Host "     Copy these if Revit loads before you build, or if DLL paths changed."
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
