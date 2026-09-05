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
  - Vault\wiki\curated\key-locations.md Local Repos table <-> setup.ps1 $repos + retired-on-disk
  - Vault\wiki\curated\workspace-<name>.md hub pages <-> *.code-workspace files on disk
  - AGENTS.md / CLAUDE.md pair per repo root (agent-harness convention, 2026-09-05):
    AGENTS.md canonical, CLAUDE.md line 1 = @AGENTS.md, no .agents/ or .codex/ dirs,
    no Codex-sync substitution artifacts, AGENTS.md within Codex's 32 KiB read cap and the
    200-line instruction-hygiene cap

Known legitimate exceptions encoded below:
  - PostProcess\ is a grouping folder, not a repo (its children are the repos)
  - pyRevit is absent from the hub .code-workspace by design
  - Recovery/ in .gitignore is preventive (Revit crash dumps), may not exist on disk

Added 2026-08-31 (Pass 02) — the key-locations and hub-page checks. The registry check is
keyed on .code-workspace FILES; key-locations.md is keyed on REPOS. Those are different
axes and nothing spanned the second one: PM, Shared and SiteCheck were each missing from
key-locations.md for weeks while this script reported green, because each had a workspace
file and therefore a registry row. A passing check was masking the gap.
Repos are derived from setup.ps1 $repos plus $GSADUsRetiredRepos still on disk — the same
sources of truth the rest of this script already uses; nothing here redefines what a repo
is. Path comparisons are forward-slash normalised so -Root genuinely works off a root other
than C:\GSADUs (previously -Root was advertised but three comparisons hardcoded C:\GSADUs
or Windows separators, so the script could not be exercised against a fixture).

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
$registryPath = Join-Path $Root 'Vault/wiki/curated/workspaces.md'
$keyLocPath   = Join-Path $Root 'Vault/wiki/curated/key-locations.md'
$hubDir       = Join-Path $Root 'Vault/wiki/curated'

foreach ($f in @($setupPath, $profilePath, $gitignorePath, $searchIgnorePath, $hubWsPath, $registryPath, $keyLocPath)) {
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
    if (-not (Test-Path (Join-Path $Root $h))) {
        $drift.Add("GSADUs.code-workspace folder '$h' does not exist on disk")
    }
}

# ── Vault workspaces.md registry vs *.code-workspace files on disk ───────────
$registryRaw = Get-Content -LiteralPath $registryPath -Raw
$rootPat = [regex]::Escape($Root.TrimEnd('\','/'))
$regAbs = @([regex]::Matches($registryRaw, "(?i)$rootPat[\\/][^``\s|]*?\.code-workspace") | ForEach-Object { $_.Value })
$regRel = @([regex]::Matches($registryRaw, '(?i)repo:\s*\.\./([^\s`]*?\.code-workspace)') |
             ForEach-Object { Join-Path $Root $_.Groups[1].Value })
$registryFiles = @($regAbs + $regRel |
    ForEach-Object { ([IO.Path]::GetFullPath($_)).Replace('\','/').ToLowerInvariant() } | Sort-Object -Unique)

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
$wsOnDiskNorm = @($wsOnDisk |
    ForEach-Object { ([IO.Path]::GetFullPath($_)).Replace('\','/').ToLowerInvariant() } | Sort-Object -Unique)

foreach ($r in $registryFiles) {
    if ($wsOnDiskNorm -notcontains $r) { $drift.Add("Vault workspaces.md references missing file: $r") }
}
foreach ($w in $wsOnDiskNorm) {
    if ($registryFiles -notcontains $w) { $drift.Add("Workspace file on disk not in the Vault workspaces.md registry: $w") }
}

# ── Vault key-locations.md Local Repos coverage ──────────────────────────────
# Keyed on REPOS, not on workspace files — see the header note. This is the check whose
# absence let PM/, Shared/ and SiteCheck/ go unlisted while every other surface was green.
$keyLocRaw = Get-Content -LiteralPath $keyLocPath -Raw
# Scope to the '## Local Repos' section only — later tables in this page (Shared Drive,
# CLI tooling) use the same backticked-path cell shape and are not repo rows.
$m = [regex]::Match($keyLocRaw, '(?ms)^##\s+Local Repos\b.*?(?=^##\s|\z)')
if (-not $m.Success) {
    Write-Error "Could not find the '## Local Repos' section in $keyLocPath"; exit 2
}
$keyLocRows = @([regex]::Matches($m.Value, '(?m)^\|\s*`([^`|]+?)/`\s*\|') |
                ForEach-Object { ($_.Groups[1].Value -replace '\\', '/').Trim() })
if ($keyLocRows.Count -eq 0) {
    Write-Error "Could not parse any Local Repos rows from $keyLocPath"; exit 2
}
$expectedRepoRows = @(@($setupRepos) +
                      @($retiredRepos | Where-Object { Test-Path (Join-Path $Root ($_ -replace '\\', '/')) }) |
                      ForEach-Object { $_ -replace '\\', '/' } | Sort-Object -Unique)
foreach ($e in $expectedRepoRows) {
    if ($keyLocRows -notcontains $e) {
        $drift.Add("Vault key-locations.md has no Local Repos row for '$e/' (it is in setup.ps1 `$repos, or is a retired repo still on disk)")
    }
}
foreach ($k in $keyLocRows) {
    if (-not (Test-Path (Join-Path $Root $k))) {
        $drift.Add("Vault key-locations.md Local Repos row '$k/' names a directory that is not on disk")
    }
}

# ── Vault workspace-<name>.md hub pages vs *.code-workspace files on disk ────
# A registry row existing is not the same as the hub page it links to existing.
$hubSourced = [System.Collections.Generic.List[string]]::new()
foreach ($hub in (Get-ChildItem -LiteralPath $hubDir -Filter 'workspace-*.md' -File)) {
    $hubRaw = Get-Content -LiteralPath $hub.FullName -Raw
    foreach ($m in [regex]::Matches($hubRaw, '(?im)^\s*-\s*repo:\s*\.\./(\S.*?\.code-workspace)\s*$')) {
        $hubSourced.Add((([IO.Path]::GetFullPath((Join-Path $Root $m.Groups[1].Value))).Replace('\','/')).ToLowerInvariant())
    }
}
foreach ($w in $wsOnDiskNorm) {
    if ($hubSourced -notcontains $w) {
        $drift.Add("No Vault wiki\curated\workspace-*.md hub page lists '$w' in its sources: frontmatter")
    }
}

# ── Agent-harness convention (Vault wiki/curated/agent-harnesses.md, 2026-09-05) ────────
# AGENTS.md is the canonical, tool-neutral instruction file; CLAUDE.md is `@AGENTS.md` plus
# Claude-only notes; skills live once under .claude/skills; no .agents/ or .codex/ directory
# (those are the Codex import sync's copies). Checked at the workspace root, every active repo
# root, and the nested instruction dirs listed here. Retired repos are never touched.
$NestedInstructionDirs = @('pyRevit\GSADUs_Tools.extension')
$SyncArtifacts    = @('Codex.ai', '.Codex/', '.Codex\', 'Codex Fable')   # what the sync's claude→Codex substitution leaves behind
$AgentsMdMaxBytes = 32768   # Codex project_doc_max_bytes default — a larger AGENTS.md is silently truncated
$AgentsMdMaxLines = 200     # owner decision 2026-09-05: decisions, contracts, pointers only — detail lives in binding docs
$harnessPairs = 0
foreach ($rel in (@('.') + @($setupRepos) + $NestedInstructionDirs)) {
    $dir   = if ($rel -eq '.') { $Root } else { Join-Path $Root $rel }
    $label = if ($rel -eq '.') { '<workspace root>' } else { $rel }
    if (-not (Test-Path -LiteralPath $dir)) { continue }   # a missing repo is already reported above
    foreach ($gen in @('.agents', '.codex')) {
        if (Test-Path -LiteralPath (Join-Path $dir $gen)) {
            $drift.Add("$label has a '$gen\' directory — the Codex import sync's copy; delete it (skills have ONE copy under .claude\skills — Vault agent-harnesses.md)")
        }
    }
    $agents = Join-Path $dir 'AGENTS.md'; $claude = Join-Path $dir 'CLAUDE.md'
    $hasAgents = Test-Path -LiteralPath $agents; $hasClaude = Test-Path -LiteralPath $claude
    if (-not ($hasAgents -or $hasClaude)) { continue }   # repos without agent instructions (Tools, AppsScript) have nothing to pair
    if ($hasAgents -and -not $hasClaude) { $drift.Add("$label has AGENTS.md but no CLAUDE.md — add the importer (line 1 exactly '@AGENTS.md', then Claude-only notes)") }
    if ($hasClaude -and -not $hasAgents) { $drift.Add("$label has CLAUDE.md but no AGENTS.md — AGENTS.md is the canonical file: move the rules there and leave CLAUDE.md as '@AGENTS.md' + Claude-only notes") }
    if ($hasClaude) {
        $first = Get-Content -LiteralPath $claude -TotalCount 1
        if ($null -eq $first -or $first.Trim() -ne '@AGENTS.md') { $drift.Add("$label\CLAUDE.md line 1 must be exactly '@AGENTS.md' (found: '$first') — rule text belongs in AGENTS.md") }
    }
    if ($hasAgents) {
        $raw = Get-Content -LiteralPath $agents -Raw
        foreach ($a in $SyncArtifacts) {
            if ($raw.Contains($a)) { $drift.Add("$label\AGENTS.md contains '$a' — a Codex-sync substitution artifact, not a real path or name") }
        }
        $len = (Get-Item -LiteralPath $agents).Length
        if ($len -gt $AgentsMdMaxBytes) { $drift.Add("$label\AGENTS.md is $len bytes, over Codex's $AgentsMdMaxBytes-byte project_doc_max_bytes default — Codex silently truncates it; trim the file") }
        $lineCount = ($raw.TrimEnd() -split "`r?`n").Count
        if ($lineCount -gt $AgentsMdMaxLines) { $drift.Add("$label\AGENTS.md is $lineCount lines, over the $AgentsMdMaxLines-line cap — instruction files hold decisions, contracts and pointers; move detail to its binding doc (Vault agent-harnesses.md, Instruction hygiene)") }
    }
    if ($hasAgents -and $hasClaude) { $harnessPairs++ }
}

# ── Report ───────────────────────────────────────────────────────────────────
if ($drift.Count -gt 0) {
    Write-Host "check-repo-registry: DRIFT — $($drift.Count) mismatch(es):" -ForegroundColor Red
    foreach ($m in $drift) { Write-Host "  - $m" -ForegroundColor Red }
    exit 1
}
Write-Host ("check-repo-registry: OK — {0} active repos, {1} retired; setup.ps1, disk, .gitignore, .ignore, hub workspace, Vault registry, {2} key-locations rows, {3} hub sources and {4} AGENTS.md/CLAUDE.md pairs all consistent." -f $setupRepos.Count, $retiredRepos.Count, $keyLocRows.Count, $hubSourced.Count, $harnessPairs) -ForegroundColor Green
exit 0
