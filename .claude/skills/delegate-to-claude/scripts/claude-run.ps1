#Requires -Version 7
<#
claude-run.ps1 — launch a pinned, non-interactive Claude Code session from any harness.

Companion to ..\SKILL.md (delegate-to-claude). Same pattern as Tools\ShellProfile\profile.ps1
Invoke-WipConflictAgent and Vault\scripts\wiki-scan.ps1 — the owner's rule for scripted
launches (2026-07-14): pin the model, pre-grant scoped permissions, never inherit account
defaults.

  claude-run.ps1 -Repo C:\GSADUs\PM -BriefFile brief.md
  claude-run.ps1 -Repo C:\GSADUs\WebApp -Brief "Review lib/estimator/calculate.ts for …" -AllowedTools Read,Glob,Grep
  claude-run.ps1 … -DryRun            # print the exact command, launch nothing

Exit code = the delegate's exit code (0 = success). stdout = the delegate's final report.
#>
param(
    [Parameter(Mandatory)][string]$Repo,
    [string]$Brief,
    [string]$BriefFile,
    [string]$Model = 'claude-fable-5-1',
    [string]$Effort = 'high',
    [string]$PermissionMode = 'acceptEdits',
    [string[]]$AllowedTools = @('Read', 'Glob', 'Grep', 'Edit', 'Write', 'Bash(git:*)', 'Bash(npm:*)', 'Bash(node:*)', 'Bash(pwsh:*)', 'PowerShell(git:*)'),
    [ValidateSet('text', 'json', 'stream-json')][string]$OutputFormat = 'text',
    [string]$Name,
    [string[]]$AddDir = @(),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Repo -PathType Container)) { Write-Error "Repo not found: $Repo"; exit 2 }
if ([string]::IsNullOrWhiteSpace($Brief) -eq [string]::IsNullOrWhiteSpace($BriefFile)) {
    Write-Error 'Pass exactly one of -Brief or -BriefFile.'; exit 2
}
if ($BriefFile) {
    if (-not (Test-Path -LiteralPath $BriefFile -PathType Leaf)) { Write-Error "Brief file not found: $BriefFile"; exit 2 }
    $Brief = Get-Content -LiteralPath $BriefFile -Raw
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Write-Error "'claude' is not on PATH."; exit 2 }

$claudeArgs = @(
    '-p', $Brief
    '--model', $Model
    '--effort', $Effort
    '--permission-mode', $PermissionMode
    '--allowedTools'
    $AllowedTools
    # A non-bare -p session: --bare skips OAuth and instruction discovery. If a future release
    # makes --bare the -p default, add the explicit non-bare flag here and re-verify (SKILL.md).
    '--setting-sources', 'user,project,local'
    '--output-format', $OutputFormat
)
if ($Name) { $claudeArgs += @('--name', $Name) }
foreach ($d in $AddDir) { $claudeArgs += @('--add-dir', $d) }

if ($DryRun) {
    $shown = $claudeArgs | ForEach-Object {
        if ($_ -eq $Brief) { "'<brief: $($Brief.Length) chars>'" }
        elseif ($_ -match '\s') { "'$_'" } else { $_ }
    }
    Write-Host "cwd:    $Repo"
    Write-Host "launch: claude $($shown -join ' ')"
    exit 0
}

# A nested launch from inside a Claude Code session must not inherit its marker.
$env:CLAUDECODE = $null
$env:CLAUDE_CODE_ENTRYPOINT = $null

Push-Location -LiteralPath $Repo
try {
    & claude @claudeArgs
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $code
