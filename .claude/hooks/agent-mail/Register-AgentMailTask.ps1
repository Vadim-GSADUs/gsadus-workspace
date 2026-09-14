<#
.SYNOPSIS
    Register (or remove) the per-user at-logon Task Scheduler task that starts the MCP
    Agent Mail server: GSADUs\mcp-agent-mail. No admin rights needed.

.DESCRIPTION
    Action:  pwsh -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass
             -File C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1 -Quiet
    Trigger: at logon of the current user (30 s delay so the network stack is up).
    Runs interactively as the current user, limited privileges, no stored password.

    Usage:   pwsh -File C:\GSADUs\.claude\hooks\agent-mail\Register-AgentMailTask.ps1 [-Unregister]
    Check:   Get-ScheduledTask -TaskPath \GSADUs\ -TaskName mcp-agent-mail | Get-ScheduledTaskInfo
    Run now: Start-ScheduledTask -TaskPath \GSADUs\ -TaskName mcp-agent-mail
#>
[CmdletBinding()]
param([switch]$Unregister)

$taskPath = '\GSADUs\'
$taskName = 'mcp-agent-mail'
$script   = Join-Path $PSScriptRoot 'Start-AgentMail.ps1'

if ($Unregister) {
    Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    "removed $taskPath$taskName (if it existed)"
    exit 0
}

$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$action  = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Quiet"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = 'PT30S'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal -Force `
    -Description 'Starts the MCP Agent Mail server (mcp-agent-mail serve --no-tui on 127.0.0.1:8765) so Claude Code and Codex sessions can message each other. Script: C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1' | Out-Null

Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName | Select-Object TaskPath, TaskName, State
