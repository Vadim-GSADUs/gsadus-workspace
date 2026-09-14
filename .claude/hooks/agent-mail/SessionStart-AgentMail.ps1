<#
.SYNOPSIS
    Claude Code SessionStart hook: make sure the MCP Agent Mail server is up, then surface this
    repo's unread Agent Mail for the session's Claude identities. Silent when there is nothing.

.DESCRIPTION
    Wired identically in C:\GSADUs\.claude\settings.json (workspace sessions) and in
    ~\.claude\settings.json (every other repo on this machine; shared project settings are read
    only from the session's primary working directory, and an identical handler in two files
    runs once). Reads the hook JSON from stdin (cwd, session_id).

    project_key = the git root of cwd (the same absolute path agents register with).
    Identities  = agents in that project whose program is claude-code, or exactly
                  $env:AGENT_MAIL_AGENT when the session was launched with it set.
    Output      = a SessionStart additionalContext block listing every unread message, or
                  nothing. Never blocks the session: every failure degrades to silence, except a
                  server that could not be started, which is reported in one line.

    Windows PowerShell 5.1 compatible.
#>
$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Emit-Context([string]$text) {
    @{ hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $text } } | ConvertTo-Json -Depth 4 -Compress
}

function Get-AmExe {
    $candidates = @()
    if ($env:AGENT_MAIL_HOME) { $candidates += (Join-Path $env:AGENT_MAIL_HOME 'am.exe') }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\mcp-agent-mail\am.exe')
    $onPath = Get-Command am.exe -ErrorAction SilentlyContinue
    if ($onPath) { $candidates += $onPath.Source }
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

# --- hook input -----------------------------------------------------------------------------
$cwd = (Get-Location).Path
try {
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $j = $raw | ConvertFrom-Json; if ($j.cwd) { $cwd = [string]$j.cwd } }
} catch {}

# --- server up? (start it if not) -----------------------------------------------------------
$starter = Join-Path $PSScriptRoot 'Start-AgentMail.ps1'
& $starter -Quiet 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Emit-Context "AGENT MAIL: the server on 127.0.0.1:8765 is down and could not be started (pwsh -File $starter). Inbox not checked; the agent-mail MCP tools will fail until it runs."
    exit 0
}

# --- project + identities -------------------------------------------------------------------
$am = Get-AmExe
if (-not $am) { exit 0 }
$top = & git -C $cwd rev-parse --show-toplevel 2>$null
$project = if ($top) { ($top -replace '/', '\') } else { $cwd }

$agents = @()
try { $agents = @((& $am agents list --project $project --json 2>$null | Out-String) | ConvertFrom-Json) } catch { $agents = @() }
if ($env:AGENT_MAIL_AGENT) { $agents = @($agents | Where-Object { $_.name -eq $env:AGENT_MAIL_AGENT }) }
else { $agents = @($agents | Where-Object { $_.program -eq 'claude-code' }) }
if ($agents.Count -eq 0) { exit 0 }

# --- unread inbox per identity --------------------------------------------------------------
$lines = @()
$total = 0
foreach ($a in $agents) {
    $name = $a.name
    try {
        $inbox = (& $am inbox --project $project --agent $name --json --include-bodies --limit 10 2>$null | Out-String) | ConvertFrom-Json
    } catch { continue }
    if (-not $inbox -or -not $inbox.count -or $inbox.count -eq 0) { continue }
    $total += [int]$inbox.count
    $lines += "- identity $name ($($a.task_description)): $($inbox.count) unread"
    foreach ($m in $inbox.inbox) {
        $flag = if ($m.ack_status -eq 'required') { ' [ack required]' } else { '' }
        $body = [string]$m.body_md
        $body = ($body -replace '\s+', ' ').Trim()
        if ($body.Length -gt 240) { $body = $body.Substring(0, 240) + '...' }
        $lines += "  - #$($m.id) thread $($m.thread) from $($m.from), $($m.age)$flag - $($m.subject)"
        if ($body) { $lines += "    $body" }
    }
}
if ($total -eq 0) { exit 0 }

$head = "AGENT MAIL - $total unread message(s) for this repo's Claude identities in project $project (server http://127.0.0.1:8765, owner inbox http://127.0.0.1:8765/mail/)."
$tail = "Act on these before other work: register_agent with the same name to adopt an identity above (or a new one; the server assigns names), fetch_inbox, then reply_message on the existing thread and acknowledge_message where ack is required. Rules: C:\GSADUs\AGENTS.md, section Agent Mail."
Emit-Context (($head, ($lines -join "`n"), $tail) -join "`n")
exit 0
