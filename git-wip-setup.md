# Git WIP Aliases — Cross-PC Setup Guide

Quick commands to save and sync work-in-progress between office and home PCs.

## Setup (run once per PC)

### PowerShell 7 (recommended — what you use day-to-day)

Open PowerShell and run:

```powershell
New-Item -ItemType File -Force $PROFILE
Add-Content $PROFILE "`nfunction wip { git add -A; git commit -m \"wip: \$(Get-Date -Format 'yyyyMMdd-HHmm')\"; git push }"
Add-Content $PROFILE "`nfunction unwip { git pull; git reset HEAD~1 }"
. $PROFILE
```

> If your profile is in OneDrive (default), it syncs to your other PCs automatically — no setup needed there.

### Git Bash (if you use it instead)

Open Git Bash and paste this:

```bash
echo "alias wip='git add -A && git commit -m \"wip: \$(date +%Y%m%d-%H%M)\" && git push'" >> ~/.bashrc
echo "alias unwip='git pull && git reset HEAD~1'" >> ~/.bashrc
source ~/.bashrc
```

That's it. The commands load automatically every time you open a new terminal.

---

## Usage

### Leaving the office
Navigate to your project folder, then:
```bash
wip
```
Stages all changes, commits with a timestamp (`wip: 20260311-1742`), and pushes to GitHub.

### Arriving at home (or other PC)
Navigate to your project folder, then:
```bash
unwip
```
Pulls the latest, then un-commits the WIP so your changes are back as unsaved work — right where you left off.

---

## The Golden Rule (avoid conflicts)

> **Pull → Work → Commit → Push** — tight loop, every session, every PC.

- Always `git pull` before starting work on any PC
- Always push before switching PCs (`wip` if mid-session)
- Never let commits sit locally while working on another machine

---

## Manual equivalent (if aliases aren't set up)

**Saving WIP:**
```bash
git add -A
git commit -m "wip: 20260311-1742"
git push
```

**Resuming WIP:**
```bash
git pull
git reset HEAD~1
```
