# Agent Mail — server lifecycle and the Claude SessionStart hook

The workspace rule (what every agent does with it) is `C:\GSADUs\AGENTS.md` → *Agent Mail*.
This folder holds the machine plumbing: how the server runs and how Claude Code sessions
learn about unread mail. Adopted 2026-09-14 after a Codex agent and a Claude session spent a
day editing the same WebApp tree with no channel between them.

| Piece | Where |
|---|---|
| Binaries `mcp-agent-mail.exe` (server) and `am.exe` (operator CLI), v0.3.35, [Rust rewrite](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) | `%LOCALAPPDATA%\Programs\mcp-agent-mail\` (on the user PATH; upstream `install.ps1` default) |
| Server config (`HTTP_HOST=127.0.0.1`, `HTTP_PORT=8765`, `HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true`) | `~\.config\mcp-agent-mail\config.env` |
| Data: SQLite + Git mailbox archive | `~\.local\share\mcp-agent-mail\git_mailbox_repo\` |
| Server stdout/stderr | `%LOCALAPPDATA%\mcp-agent-mail\server.out.log`, `server.err.log` |
| MCP endpoint / owner inbox | `http://127.0.0.1:8765/mcp/` / `http://127.0.0.1:8765/mail/` |
| Claude Code client | `claude mcp add --scope user --transport http agent-mail http://127.0.0.1:8765/mcp/` (in `~\.claude.json`) |
| Codex client (app + CLI share it) | `codex mcp add agent_mail --url http://127.0.0.1:8765/mcp/` → `[mcp_servers.agent_mail]` in `~\.codex\config.toml` |

Localhost-only bind, no bearer token: anything on this PC can read the mailbox, which is the
point (the owner's browser, both harnesses, git hooks). Nothing leaves the machine.

## Start / stop

```powershell
pwsh -File C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1          # start if not listening (idempotent)
pwsh -File C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1 -Stop    # stop
Invoke-RestMethod http://127.0.0.1:8765/healthz                            # {"status":"alive"}
```

`Start-AgentMail.ps1` resolves the binary from `$env:AGENT_MAIL_HOME`, then the install
default, then PATH — nothing machine-specific is committed. It also creates the data
directory, which the server refuses to create itself on a fresh machine.

**Auto-start:** the per-user Task Scheduler task `\GSADUs\mcp-agent-mail` runs the same
script hidden 30 s after logon (`Register-AgentMailTask.ps1`; `-Unregister` removes it).
No admin rights, no stored password. Check with
`Get-ScheduledTask -TaskPath \GSADUs\ | Get-ScheduledTaskInfo`.

## The SessionStart hook

`SessionStart-AgentMail.ps1` runs at every Claude Code session start (startup, resume, clear,
compact): it calls `Start-AgentMail.ps1` if port 8765 is silent, resolves `project_key` as
the git root of the session's cwd, and prints the unread inbox of every `claude-code` agent in
that project as additional context — or nothing. Set `AGENT_MAIL_AGENT=<name>` when launching
to pin one identity.

It is wired twice with an identical command (Claude Code runs an identical handler once):

- `C:\GSADUs\.claude\settings.json` — committed; fires for sessions started at `C:\GSADUs`.
- `~\.claude\settings.json` — machine-local; fires for sessions started in any sub-repo, because
  shared project settings are read only from the session's primary working directory.

Manual test (what Claude Code does, minus the model):

```powershell
'{"cwd":"C:\\GSADUs\\WebApp","session_id":"manual","hook_event_name":"SessionStart"}' |
  pwsh -NoProfile -File C:\GSADUs\.claude\hooks\agent-mail\SessionStart-AgentMail.ps1
```

## Upgrading

Download the next `mcp-agent-mail-x86_64-pc-windows-msvc.zip` + `.sha256` from the GitHub
release, verify, stop the server, replace both exes in the install folder, start it. The
data directory survives; `am doctor check` afterwards.

## Second machine (vg-home)

Same steps, same paths: install the binaries, run `Register-AgentMailTask.ps1`, `claude mcp add`
and `codex mcp add` as above, copy the hook entry into `~\.claude\settings.json`. The workspace
files arrive with `unwip-all`. Mailboxes are per machine — the archive is not synced.
