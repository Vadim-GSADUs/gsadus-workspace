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
    @{ Url = "https://github.com/Vadim-GSADUs/gsadus-tools.git";              Path = "Tools" },
    @{ Url = "https://github.com/oakplank/RevitMCP.git";                      Path = "revit-mcp" }
)

function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "    [OK]    $msg" -ForegroundColor Green }
function Write-Pull { param($msg) Write-Host "    [pull]  $msg" -ForegroundColor Yellow }
function Write-Skip { param($msg) Write-Host "    [skip]  $msg" -ForegroundColor DarkGray }

Write-Step "GSADUs Workspace Setup — Root: $Root"

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
