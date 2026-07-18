#Requires -Version 7
<#
check-repo-registry.ps1 — GSADUs repo-lifecycle consistency check.

Cross-checks every surface that must change together when a repo is added,
renamed, or retired. Companion to ..\SKILL.md — the surface list there and the
checks here are maintained together (the skill's self-check rule).

Surfaces cross-checked:
  - setup.ps1 $repos            <-> git repos on disk
  - Tools\ShellProfile\profile.ps1 $GSADUsRetiredRepos (retired set, on-disk read-only)
  - .gitignore                  (coverage of repo folders + dead directory entries)
  - .ignore                     (search re-include negations: coverage + dead entries)
  - GSADUs.code-workspace       (hub folder roots vs $repos)
  - Vault\wiki\curated\workspaces.md registry <-> *.code-workspace files on disk

Known legitimate exceptions encoded below:
  - PostProcess\ is a grouping folder, not a repo (its children are the repos)
  - pyRevit is absent from the hub .code-workspace by design
  - Recovery/ in .gitignore is preventive (Revit crash dumps), may not exist on disk

Exit 0 = all surfaces consistent. Exit 1 = drift (each mismatch named). Exit 2 = cannot parse inputs.
#>
param([string]$Root = 'C:\GSADUs')

$GroupingFolders  = @('PostProcess')   # folders that contain repos but are not repos
$HubExcludedRepos = @('pyRevit')       # absent from GSADUs.code-workspace by design
$GitignoreNonRepo = @('Recovery')      # preventive ignores allowed to not exist on disk

$drift = [System.Collections.Generic.List[string]]::new()

$setupPath    = Join-Path $Root 'setup.ps1'
$profilePath  = Join-Path $Root 'Tools\ShellProfile\profile.ps1'
$gitignorePath = Join-Path $Root '.gitignore'
$searchIgnorePath = Join-Path $Root '.ignore'
$hubWsPath    = Join-Path $Root 'GSADUs.code-workspace'
$registryPath = Join-Path $Root 'Vault\wiki\curated\workspaces.md'

foreach ($f in @($setupPath, $profilePath, $gitignorePath, $searchIgnorePath, $hubWsPath, $registryPath)) {
    if (-not (Test-Path -LiteralPath $f)) { Write-Error "Required input missing: $f"; exit 2 }
}

# ── Parse inputs ─────────────────────────────────────────────────────────────
$setupRaw = Get-Content -LiteralPath $setupPath -Raw
if ($setupRaw -notmatch '(?s)\$repos\s*=\s*@\((.*?)\r?\n\)') {
    Write-Error 'Could not parse $repos block in setup.ps1'; exit 2
}
$setupRepos = @([regex]::Matches($Matches[1], 'Path\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if ($setupRepos.Count -eq 0) { Write-Error 'Parsed zero repos from setup.ps1 $repos'; exit 2 }

$profRaw = Get-Content -LiteralPath $profilePath -Raw
if ($profRaw -notmatch '(?s)\$GSADUsRetiredRepos\s*=\s*@\((.*?)\r?\n\)') {
    Write-Error 'Could not parse $GSADUsRetiredRepos block in profile.ps1'; exit 2
}
$retiredRepos = @([regex]::Matches($Matches[1], "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })

# Git repos actually on disk: direct children of $Root, plus children of grouping folders
$diskRepos = [System.Collections.Generic.List[string]]::new()
foreach ($dir in (Get-ChildItem -LiteralPath $Root -Directory)) {
    if (Test-Path (Join-Path $dir.FullName '.git')) { $diskRepos.Add($dir.Name) }
    elseif ($GroupingFolders -contains $dir.Name) {
        foreach ($sub in (Get-ChildItem -LiteralPath $dir.FullName -Directory)) {
            if (Test-Path (Join-Path $sub.FullName '.git')) { $diskRepos.Add("$($dir.Name)\$($sub.Name)") }
        }
    }
}

# ── setup.ps1 vs disk vs retired ─────────────────────────────────────────────
foreach ($r in $setupRepos) {
    if (-not (Test-Path (Join-Path (Join-Path $Root $r) '.git'))) {
        $drift.Add("setup.ps1 lists '$r' but no git repo exists at $Root\$r")
    }
    if ($retiredRepos -contains $r) {
        $drift.Add("'$r' is in BOTH setup.ps1 `$repos and `$GSADUsRetiredRepos — retire means removing it from setup.ps1")
    }
}
foreach ($d in $diskRepos) {
    if (($setupRepos -notcontains $d) -and ($retiredRepos -notcontains $d)) {
        $drift.Add("git repo on disk '$d' is neither in setup.ps1 `$repos nor in `$GSADUsRetiredRepos")
    }
}
foreach ($r in $retiredRepos) {
    if (-not (Test-Path (Join-Path $Root $r))) {
        $drift.Add("`$GSADUsRetiredRepos lists '$r' but the folder is gone from disk — drop the entry (profile.ps1, gsadus-tools repo)")
    }
}

# Expected top-level folder names (first path segment of every active repo path)
$expectedTop = @($setupRepos | ForEach-Object { ($_ -split '[\\/]')[0] } | Sort-Object -Unique)

# ── .gitignore: coverage + dead directory entries ────────────────────────────
$gitignoreLines = Get-Content -LiteralPath $gitignorePath | ForEach-Object { $_.Trim() }
$gitignoreDirs  = @($gitignoreLines | Where-Object { $_ -match '^([A-Za-z][A-Za-z0-9._ -]*)/$' } |
                    ForEach-Object { $_.TrimEnd('/') })
foreach ($t in $expectedTop) {
    if ($gitignoreDirs -notcontains $t) { $drift.Add(".gitignore is missing the '$t/' sub-repo entry") }
}
foreach ($g in $gitignoreDirs) {
    if (($GitignoreNonRepo -contains $g) -or ($expectedTop -contains $g)) { continue }
    if (-not (Test-Path (Join-Path $Root $g))) {
        $drift.Add(".gitignore has dead entry '$g/' — no such folder on disk")
    } elseif ($diskRepos -notcontains $g) {
        $drift.Add(".gitignore entry '$g/' exists on disk but is not a registered repo or grouping folder")
    }
}

# ── .ignore: search re-include negations ─────────────────────────────────────
$searchLines = Get-Content -LiteralPath $searchIgnorePath | ForEach-Object { $_.Trim() }
$searchNegs  = @($searchLines | Where-Object { $_ -match '^!([A-Za-z][A-Za-z0-9._ -]*)/$' } |
                  ForEach-Object { $_.TrimStart('!').TrimEnd('/') })
foreach ($t in $expectedTop) {
    if ($searchNegs -notcontains $t) { $drift.Add(".ignore is missing the '!$t/' search re-include") }
}
foreach ($n in $searchNegs) {
    if (($expectedTop -notcontains $n) -and -not (Test-Path (Join-Path $Root $n))) {
        $drift.Add(".ignore has dead negation '!$n/' — no such folder on disk")
    }
}

# ── GSADUs.code-workspace hub folders vs $repos ──────────────────────────────
$hubFolders = @((Get-Content -LiteralPath $hubWsPath -Raw | ConvertFrom-Json).folders.path)
$hubLocal   = @($hubFolders | Where-Object { $_ -notmatch '^[A-Za-z]:' })   # skip G:/ shared-drive roots
$setupReposFwd = @($setupRepos | ForEach-Object { $_ -replace '\\', '/' })
foreach ($r in $setupReposFwd) {
    if (($HubExcludedRepos -contains $r) -or ($hubLocal -contains $r)) { continue }
    $drift.Add("GSADUs.code-workspace is missing folder '$r' (only $($HubExcludedRepos -join ', ') is excluded by design)")
}
foreach ($h in $hubLocal) {
    if ($setupReposFwd -notcontains $h) {
        $drift.Add("GSADUs.code-workspace folder '$h' does not match any setup.ps1 repo")
    }
    if (-not (Test-Path (Join-Path $Root ($h -replace '/', '\')))) {
        $drift.Add("GSADUs.code-workspace folder '$h' does not exist on disk")
    }
}

# ── Vault workspaces.md registry vs *.code-workspace files on disk ───────────
$registryRaw = Get-Content -LiteralPath $registryPath -Raw
$regAbs = @([regex]::Matches($registryRaw, '(?i)C:\\GSADUs\\[^`\s|]*?\.code-workspace') | ForEach-Object { $_.Value })
$regRel = @([regex]::Matches($registryRaw, '(?i)repo:\s*\.\./([^\s`]*?\.code-workspace)') |
             ForEach-Object { Join-Path $Root ($_.Groups[1].Value -replace '/', '\') })
$registryFiles = @($regAbs + $regRel | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)

$wsOnDisk = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $Root -Filter *.code-workspace -File | ForEach-Object { $wsOnDisk.Add($_.FullName) }
foreach ($dir in (Get-ChildItem -LiteralPath $Root -Directory)) {
    Get-ChildItem -LiteralPath $dir.FullName -Filter *.code-workspace -File -ErrorAction SilentlyContinue |
        ForEach-Object { $wsOnDisk.Add($_.FullName) }
    if ($GroupingFolders -contains $dir.Name) {
        foreach ($sub in (Get-ChildItem -LiteralPath $dir.FullName -Directory)) {
            Get-ChildItem -LiteralPath $sub.FullName -Filter *.code-workspace -File -ErrorAction SilentlyContinue |
                ForEach-Object { $wsOnDisk.Add($_.FullName) }
        }
    }
}
$wsOnDiskNorm = @($wsOnDisk | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)

foreach ($r in $registryFiles) {
    if ($wsOnDiskNorm -notcontains $r) { $drift.Add("Vault workspaces.md references missing file: $r") }
}
foreach ($w in $wsOnDiskNorm) {
    if ($registryFiles -notcontains $w) { $drift.Add("Workspace file on disk not in the Vault workspaces.md registry: $w") }
}

# ── Report ───────────────────────────────────────────────────────────────────
if ($drift.Count -gt 0) {
    Write-Host "check-repo-registry: DRIFT — $($drift.Count) mismatch(es):" -ForegroundColor Red
    foreach ($m in $drift) { Write-Host "  - $m" -ForegroundColor Red }
    exit 1
}
Write-Host ("check-repo-registry: OK — {0} active repos, {1} retired; setup.ps1, disk, .gitignore, .ignore, hub workspace and Vault registry all consistent." -f $setupRepos.Count, $retiredRepos.Count) -ForegroundColor Green
exit 0
