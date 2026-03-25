# GSADUs PowerShell profile — wip / unwip / end-day helpers
# Dot-sourced by $PROFILE on each shell start.
# This file is the source of truth for all wip/unwip functions.
# Edit here, run `wip`, and every PC picks up changes on next shell start after unwip.

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
    git commit --no-verify --no-gpg-sign -m "wip: $(Get-Date -Format 'yyyyMMdd-HHmm') [skip ci]"
    git push --force-with-lease
}

function unwip {
    git fetch -q 2>$null
    $ahead = git log "HEAD..@{u}" --oneline 2>$null
    if (-not $ahead) {
        Write-Host "  (nothing new on remote - skipped)" -ForegroundColor DarkGray
        return
    }
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
        git fetch -q 2>$null
        # Block only if remote has REAL (non-wip) commits not yet on this PC.
        # Old wip commits left by a previous unwip are fine — force-with-lease will overwrite them.
        $nonWipAhead = git log "HEAD..@{u}" --format="%s" 2>$null | Where-Object { $_ -notmatch "^wip:" }
        if ($nonWipAhead) {
            Write-Host "  WARN $rel — remote has real commits not pulled here, run unwip-all first" -ForegroundColor Red
            Pop-Location
            continue
        }
        $dirty    = git status --porcelain 2>$null
        $unpushed = git log "@{u}..HEAD" --oneline 2>$null
        if ($dirty) {
            # Skip if working tree matches remote — prevents bounce-back after unwip with no new work.
            # Stage everything temporarily so untracked files are included in the diff.
            git add -A 2>$null
            $diffFromRemote = git diff --cached "@{u}" 2>$null
            git reset HEAD 2>&1 | Out-Null
            if (-not $diffFromRemote) {
                Write-Host "  skip $rel (up to date)" -ForegroundColor DarkGray
                Pop-Location
                continue
            }
            Write-Host "  wip  $rel" -ForegroundColor Cyan
            git add -A
            git commit --no-verify --no-gpg-sign -m "wip: $(Get-Date -Format 'yyyyMMdd-HHmm') [skip ci]" -q
            git push --force-with-lease
            if ($LASTEXITCODE -ne 0) { Write-Host "  ERROR: push failed for $rel" -ForegroundColor Red }
        } elseif ($unpushed) {
            Write-Host "  push $rel (unpushed commits)" -ForegroundColor Yellow
            git push --force-with-lease
            if ($LASTEXITCODE -ne 0) { Write-Host "  ERROR: push failed for $rel" -ForegroundColor Red }
        } else {
            Write-Host "  skip $rel (up to date)" -ForegroundColor DarkGray
        }
        Pop-Location
    }
}

function unwip-all {
    foreach ($repo in Get-WipRepos) {
        Push-Location $repo
        $rel = $repo.Replace($GSADUsRoot, "").TrimStart("\")
        if (-not $rel) { $rel = "." }
        git fetch -q 2>$null
        $ahead = git log "HEAD..@{u}" --oneline 2>$null
        if (-not $ahead) {
            Write-Host "  skip $rel (up to date)" -ForegroundColor DarkGray
            Pop-Location
            continue
        }
        # Stash any local state (modified + untracked) so the pull always succeeds cleanly.
        $stashed = $false
        $dirty = git status --porcelain 2>$null
        if ($dirty) {
            git stash --include-untracked -q
            $stashed = $true
        }
        Write-Host "  unwip $rel" -ForegroundColor Cyan
        git pull -q 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR: pull failed for $rel" -ForegroundColor Red
            if ($stashed) { git stash pop -q 2>&1 | Out-Null }
            Pop-Location
            continue
        }
        $msg = git log -1 --format="%s" 2>$null
        if ($msg -match "^wip:") { git reset HEAD~1 2>&1 | Out-Null }
        if ($stashed) {
            git stash pop 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                # Untracked files from the stash already exist in working tree (restored by wip reset).
                # The working tree already has the correct state — drop the stale stash.
                git stash drop -q 2>$null
            }
        }
        Pop-Location
    }
}

function end-day {
    Write-Host ""
    Write-Host "Saving work across all repos..." -ForegroundColor Cyan
    wip-all
    Write-Host ""
    Write-Host "Locking screen." -ForegroundColor Yellow
    rundll32.exe user32.dll,LockWorkStation
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
