# GSADUs — Quick Start

## Prerequisites
- [Git for Windows](https://git-scm.com/download/win)
- [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases) (`pwsh`)
- [GitHub CLI](https://cli.github.com/) → run `gh auth login`

## Setup

```powershell
git clone https://github.com/Vadim-GSADUs/gsadus-workspace.git C:\GSADUs
cd C:\GSADUs
pwsh -File setup.ps1
```

## Next Steps

Open the Vault in Obsidian: `C:\GSADUs\Vault`

Detailed setup instructions (profile, SSH, Revit addins, plugins): see `Vault\wiki\curated\setup-bootstrap.md`
