<#
.SYNOPSIS
    Ensure the MCP Agent Mail server (mcp-agent-mail.exe serve --no-tui) is listening on
    127.0.0.1:8765; start it hidden if it is not. -Stop ends it.

.DESCRIPTION
    One entry point for every launcher on this machine:
      - the at-logon scheduled task  GSADUs\mcp-agent-mail   (Register-AgentMailTask.ps1)
      - the shared Claude Code / Codex SessionStart handler  (delivery.mjs)
      - the owner, by hand:  pwsh -File C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1 [-Stop]

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
    [switch]$Quiet,
    [int]$Port = 8765,
    [int]$WaitSeconds = 8
)

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

$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
    if (Test-AgentMailPort -Port $Port) {
        if (-not $Quiet) { "agent-mail: started $exe on 127.0.0.1:$Port" }
        exit 0
    }
    Start-Sleep -Milliseconds 250
}
Write-Error "agent-mail: server did not come up on 127.0.0.1:$Port within ${WaitSeconds}s - see $logDir\server.err.log"
exit 1
