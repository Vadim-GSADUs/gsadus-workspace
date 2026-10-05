<#
.SYNOPSIS
    Ensure the MCP Agent Mail server (mcp-agent-mail.exe serve --no-tui) is listening on
    127.0.0.1:8765; if it is not, start it through the scheduled task. -Stop ends it.

.DESCRIPTION
    One entry point for every caller on this machine:
      - the shared Claude Code / Codex SessionStart handler  (delivery.mjs)
      - the owner or an agent, by hand:  pwsh -File C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1 [-Stop]
      - the at-logon scheduled task  GSADUs\mcp-agent-mail   (Register-AgentMailTask.ps1), with -FromTask

    Callers never launch the server themselves: they run the task, and Task Scheduler starts
    it outside every app. The Claude and Codex desktop apps are MSIX packages; a server
    started from a hook or an agent shell would join that app's job and file-system container,
    die when the app restarts or updates, and write its logs into the app's private
    Packages\<package>\LocalCache (README.md -> App containers). Only the task's own action
    passes -FromTask, which launches the server from this process.

    Binary resolution (first hit wins): $env:AGENT_MAIL_HOME\mcp-agent-mail.exe,
    %LOCALAPPDATA%\Programs\mcp-agent-mail\mcp-agent-mail.exe (the upstream install.ps1
    default), then mcp-agent-mail.exe on PATH. Nothing machine-specific is hard-coded.

    Server config lives in ~\.config\mcp-agent-mail\config.env (HTTP_HOST/PORT,
    HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true); data in ~\.local\share\mcp-agent-mail\;
    stdout/stderr logs in %LOCALAPPDATA%\mcp-agent-mail\server.*.log.

    Windows PowerShell 5.1 compatible (no ??, ?., &&) so it runs under either hook shell.
#>
[CmdletBinding()]
param(
    [switch]$Stop,
    # The scheduled task's action only: launch the server from this process.
    [switch]$FromTask,
    [switch]$Quiet,
    [int]$Port = 8765,
    # -FromTask defaults to 60 s: a cold-boot start took about 10 s on 2026-09-24.
    [int]$WaitSeconds = 8
)

$taskPath = '\GSADUs\'
$taskName = 'mcp-agent-mail'
if ($FromTask -and -not $PSBoundParameters.ContainsKey('WaitSeconds')) { $WaitSeconds = 60 }

function Test-AgentMailPort {
    param([int]$Port)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async  = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        $ok     = $async.AsyncWaitHandle.WaitOne(300) -and $client.Connected
        $client.Close()
        return [bool]$ok
    } catch { return $false }
}

function Wait-AgentMailPort {
    param([int]$Port, [int]$Seconds)
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-AgentMailPort -Port $Port) { return $true }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

function Get-AgentMailExe {
    $candidates = @()
    if ($env:AGENT_MAIL_HOME) { $candidates += (Join-Path $env:AGENT_MAIL_HOME 'mcp-agent-mail.exe') }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\mcp-agent-mail\mcp-agent-mail.exe')
    $onPath = Get-Command mcp-agent-mail.exe -ErrorAction SilentlyContinue
    if ($onPath) { $candidates += $onPath.Source }
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    return $null
}

if ($Stop) {
    $procs = Get-Process -Name 'mcp-agent-mail' -ErrorAction SilentlyContinue
    if ($procs) { $procs | Stop-Process -Force; if (-not $Quiet) { "agent-mail: stopped pid(s) $($procs.Id -join ', ')" } }
    elseif (-not $Quiet) { "agent-mail: not running" }
    exit 0
}

if (Test-AgentMailPort -Port $Port) {
    if (-not $Quiet) { "agent-mail: already listening on 127.0.0.1:$Port" }
    exit 0
}

if (-not $FromTask) {
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Error "agent-mail: scheduled task $taskPath$taskName is not registered. Run Register-AgentMailTask.ps1 (see C:\GSADUs\.claude\hooks\agent-mail\README.md)."
        exit 2
    }
    if (($task.Actions | ForEach-Object Arguments) -notmatch '-FromTask') {
        Write-Error "agent-mail: $taskPath$taskName does not launch with -FromTask. Re-run Register-AgentMailTask.ps1."
        exit 2
    }
    # MultipleInstances IgnoreNew: a run already in progress (the at-logon start) absorbs this one.
    Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName
    if (Wait-AgentMailPort -Port $Port -Seconds $WaitSeconds) {
        if (-not $Quiet) { "agent-mail: started by task $taskPath$taskName on 127.0.0.1:$Port" }
        exit 0
    }
    Write-Error "agent-mail: server did not come up on 127.0.0.1:$Port within ${WaitSeconds}s of starting $taskPath$taskName - see Get-ScheduledTaskInfo and $env:LOCALAPPDATA\mcp-agent-mail\server.err.log"
    exit 1
}

# -FromTask: Task Scheduler runs this outside every app container.
# A server that is still starting holds the database lock, and a second one would fail on it.
if (-not (Get-Process -Name 'mcp-agent-mail' -ErrorAction SilentlyContinue)) {
    $exe = Get-AgentMailExe
    if (-not $exe) {
        Write-Error "agent-mail: mcp-agent-mail.exe not found. Set AGENT_MAIL_HOME or install to %LOCALAPPDATA%\Programs\mcp-agent-mail (see C:\GSADUs\.claude\hooks\agent-mail\README.md)."
        exit 2
    }

    # The server refuses to start when its default data parent is missing (fresh machine).
    $dataRoot = Join-Path $HOME '.local\share\mcp-agent-mail\git_mailbox_repo'
    New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
    $logDir = Join-Path $env:LOCALAPPDATA 'mcp-agent-mail'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null

    Start-Process -FilePath $exe -ArgumentList 'serve', '--no-tui' -WorkingDirectory $logDir -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir 'server.out.log') `
        -RedirectStandardError  (Join-Path $logDir 'server.err.log') | Out-Null
}

if (Wait-AgentMailPort -Port $Port -Seconds $WaitSeconds) {
    if (-not $Quiet) { "agent-mail: listening on 127.0.0.1:$Port" }
    exit 0
}
Write-Error "agent-mail: server did not come up on 127.0.0.1:$Port within ${WaitSeconds}s - see $env:LOCALAPPDATA\mcp-agent-mail\server.err.log"
exit 1
