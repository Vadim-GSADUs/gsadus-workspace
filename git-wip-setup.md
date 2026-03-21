# Git WIP Aliases — Cross-PC Setup Guide

Quick commands to save and sync work-in-progress between office and home PCs.

> **Note:** The PowerShell profile syncs via OneDrive automatically. You only need the manual setup below on a brand-new PC that has never signed into OneDrive yet.

---

## Setup (run once on a new PC before OneDrive syncs)

Open PowerShell and run:

```powershell
New-Item -ItemType File -Force $PROFILE
Add-Content $PROFILE "`nfunction wip { git add -A; git commit -m \"wip: \$(Get-Date -Format 'yyyyMMdd-HHmm')\"; git push --force-with-lease }"
Add-Content $PROFILE "`nfunction unwip { git pull; `$msg = git log -1 --format='%s' 2>`$null; if (`$msg -match '^wip:') { git reset HEAD~1 } else { Write-Host '  (last commit is not a wip - pull only)' -ForegroundColor DarkGray } }"
. $PROFILE
```

---

## Usage

### Leaving the office
Navigate to your project folder, then:
```powershell
wip
```
Stages all changes, commits with a timestamp (`wip: 20260311-1742`), and force-pushes to GitHub (safely — only succeeds if remote is exactly what you left it as).

### Arriving at home (or other PC)
Navigate to your project folder, then:
```powershell
unwip
```
Pulls the latest, then un-commits the WIP (only if the latest commit is actually a wip) so your changes are back as unsaved work — right where you left off.

---

## Why `--force-with-lease`?

After `unwip` resets a wip commit, your local branch is one commit behind remote. The next `wip` creates a new commit on that same base, which diverges from remote — a plain `git push` would fail. `--force-with-lease` replaces the old wip commit on remote, but **only if no one else has pushed in the meantime** (safe for single-user repos).

---

## The Golden Rule (avoid conflicts)

> **Pull → Work → Wip → Switch PC** — tight loop, every session.

- Always `unwip` when arriving at a PC before starting work
- Always `wip` before switching PCs
- Never work on two PCs at the same time

---

## Manual equivalent (if aliases aren't set up)

**Saving WIP:**
```bash
git add -A
git commit -m "wip: 20260311-1742"
git push --force-with-lease
```

**Resuming WIP:**
```bash
git pull
# Only reset if the latest commit is a wip:
git log -1 --pretty=%s   # check the message first
git reset HEAD~1
```
