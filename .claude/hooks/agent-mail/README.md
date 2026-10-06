# Agent Mail — server lifecycle and session delivery

The workspace rule (what every agent does with it) is `C:\GSADUs\AGENTS.md` → *Agent Mail*.
This folder holds the machine plumbing: how the server runs and how Claude Code sessions
receive their own unread mail. Adopted 2026-09-14 after a Codex agent and a Claude session spent a
day editing the same WebApp tree with no channel between them.

| Piece | Where |
|---|---|
| Binaries `mcp-agent-mail.exe` (server) and `am.exe` (operator CLI), v0.3.35, [Rust rewrite](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) | `%LOCALAPPDATA%\Programs\mcp-agent-mail\` (on the user PATH; upstream `install.ps1` default) |
| Server config (`HTTP_HOST=127.0.0.1`, `HTTP_PORT=8765`, `HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true`) | `~\.config\mcp-agent-mail\config.env` |
| Data: SQLite + Git mailbox archive | `~\.local\share\mcp-agent-mail\git_mailbox_repo\` |
| Server stdout/stderr (written only by the task; see *App containers*) | `%LOCALAPPDATA%\mcp-agent-mail\server.out.log`, `server.err.log` |
| MCP endpoint / owner inbox | `http://127.0.0.1:8765/mcp/` / `http://127.0.0.1:8765/mail/` |
| Claude Code client | `claude mcp add --scope user --transport http agent-mail http://127.0.0.1:8765/mcp/` (in `~\.claude.json`) |
| Codex client (app + CLI share it) | `codex mcp add agent_mail --url http://127.0.0.1:8765/mcp/` → `[mcp_servers.agent_mail]` in `~\.codex\config.toml` |

Localhost-only bind, no bearer token: anything on this PC can read the mailbox, which is the
point (the owner's browser, both harnesses, git hooks). Nothing leaves the machine.

## Start / stop

```powershell
pwsh -File C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1          # start via the task if not listening (idempotent)
pwsh -File C:\GSADUs\.claude\hooks\agent-mail\Start-AgentMail.ps1 -Stop    # stop
Invoke-RestMethod http://127.0.0.1:8765/healthz                            # {"status":"alive"}
```

**The per-user Task Scheduler task `\GSADUs\mcp-agent-mail` is the only launcher.** It runs
`Start-AgentMail.ps1 -FromTask` hidden, 30 s after logon and whenever `Start-AgentMail.ps1`
runs without `-FromTask` (the hook, the owner, an agent). That mode starts the task and waits
for the port. No admin rights, no stored password. `Register-AgentMailTask.ps1` registers
the task and runs it once; `-Unregister` removes it. Check with
`Get-ScheduledTask -TaskPath \GSADUs\ | Get-ScheduledTaskInfo`. Never pass `-FromTask` by
hand: it launches the server from the calling process.

In `-FromTask` mode the script resolves the binary from `$env:AGENT_MAIL_HOME`, then the
install default, then PATH, so nothing machine-specific is committed. It creates the data
directory, which the server refuses to create on a fresh machine. It waits up to 60 s, and
never launches a second server while one is still starting.

## App containers: why every start goes through the task (2026-09-25)

The Claude and Codex desktop apps are MSIX packages. A process started from inside one joins
that app's job and file-system container. That includes a hook or an agent's tool shell;
the Claude app's Terminal panel runs outside it (checked 2026-10-05). Windows kills the
process when the app restarts or updates. New AppData folders the process creates land in
`%LOCALAPPDATA%\Packages\<package>\LocalCache\`. AppData rules:
`C:\GSADUs\Tools\ShellProfile\README.md` → *Desktop app containers*. Full root cause:
`C:\GSADUs\Tools\ShellProfile\SETUP-VERIFICATION.md` → *Docker repair*.

Before this change, the `SessionStart` hook ran `Start-AgentMail.ps1`, which launched the
server with `Start-Process`. So any server a hook self-healed lived inside that session's
app. On-disk evidence, 2026-09-25:

- **The live server (PID 25460) came from the task.** The task ran at 08:16:48 on 9/24 (boot
  08:16:03). The server's log is in the real `%LOCALAPPDATA%\mcp-agent-mail\`, and it survived
  the 14:29 Claude update. The task still recorded result 1: a cold start took about 10 s,
  and the old script gave up after 8 s.
- **A Claude session's hook started a second server** inside the Claude app during those
  seconds. It exited at once, because the first server held the database lock and the port.
  Its log went to
  `Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local\mcp-agent-mail\server.err.log`. That folder
  dates from the 9/14 install, which also started the server from a Claude session.
- **Inside the Claude app, that LocalCache copy shadows the real log.** Reading
  `%LOCALAPPDATA%\mcp-agent-mail\server.err.log` from a Claude agent shell shows the dead
  duplicate's 9/24 "database locked" error, not the live log. Read the live log from outside
  the app, for example
  `wsl -e tail /mnt/c/Users/<user>/AppData/Local/mcp-agent-mail/server.err.log`.
- **No data split.** The database, Git archive and config are under `~\.local\share` and
  `~\.config`, outside AppData, so they are never redirected. WSL (outside every container)
  shows all delivery state in the real `%LOCALAPPDATA%\mcp-agent-mail\delivery\`, and neither
  app's LocalCache has a `delivery` folder. Hook writes into that existing real folder stay
  real. A new top-level folder does not: a probe folder created from a Claude agent shell
  landed in the Claude LocalCache, while the same write run through a scheduled task landed
  in the real `%LOCALAPPDATA%`.

Had the hook won that race, the only server would have lived in the Claude app. It would
have died with the next update and restarted inside whichever app opened the next session.

**Fix.** `Start-AgentMail.ps1` no longer launches the server itself. It runs the task
(`Start-ScheduledTask`), which Task Scheduler starts outside every app.
`MultipleInstances IgnoreNew` folds concurrent requests into the run in progress.
`Register-AgentMailTask.ps1` runs the task at registration, so the real
`%LOCALAPPDATA%\mcp-agent-mail` exists before any hook runs. Otherwise, on a fresh machine,
the first hook's `mkdir` would give Claude and Codex separate private delivery-state
folders. The script refuses a task whose action lacks `-FromTask`: re-run
`Register-AgentMailTask.ps1` once on every machine after pulling this change. Explorer, the
route `Start-DockerDesktop.ps1` uses, was not chosen. It cannot pass `serve --no-tui`,
redirect the logs, or hide the console, and the task already existed.

**Leftover:** `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local\mcp-agent-mail\`
holds only the dead duplicate's logs. Removing it ends the shadowing; this awaits the
owner's approval.

## Shared delivery hooks

`delivery.mjs` is the single implementation for Claude Code and Codex (Node.js 18+, no npm
dependencies). It replaces the original hook that scanned every Claude identity in a repo.
Only sessions under `C:\GSADUs` participate. Mailbox bindings and delivery bookkeeping live
in `%LOCALAPPDATA%\mcp-agent-mail\delivery\`; nothing is written into application repos.

| Event | Behavior |
|---|---|
| `SessionStart` | Self-heal the server through the scheduled task, bind a new session to its own server-assigned identity, announce the identity and check mail (also after a failed start). Resumes keep the binding. |
| `UserPromptSubmit` | Check for new mail, including existing sessions whose startup hook was missed. |
| `PostToolUse` | Check mail while the agent works, at most once per five seconds per session. |
| `Stop` | Deliver new pending mail before finishing; permit at most one forced continuation. |

The identity key is harness + exact session ID. Worktrees use their main checkout's project
key. Child-agent events carrying `agent_id` do not read the parent's inbox. The hook returns
only the bound mailbox's new messages. It never sends messages, executes message text,
marks mail read, acknowledges it, or switches the session's permissions. The agent handles
mail under the user authorization in `AGENTS.md`.

Each check reads up to 100 unread messages and delivers up to five, oldest first within that
page; body previews are capped at 1,600 characters. Full bodies and larger backlogs remain
available through `fetch_inbox`. Delivered IDs prevent repeat tool notifications. Failed
requests do not advance delivery state. Checks time out and fail open so a mail outage does
not stop coding. Duplicate concurrent hooks use a per-session lock; abandoned locks expire.
The hook records emission, not proof that a model processed it; read/ack receipts are separate.

### Install / update

Review the proposed files, then apply:

```powershell
node C:\GSADUs\.claude\hooks\agent-mail\install-delivery.mjs
node C:\GSADUs\.claude\hooks\agent-mail\install-delivery.mjs --apply
```

The installer preserves unrelated hooks/settings, removes the superseded Agent Mail handler,
and merges identical definitions into workspace `.claude/settings.json`, user
`~/.claude/settings.json`, and user `~/.codex/hooks.json`. Changed files receive timestamped
backups. Re-running it makes no changes. No repo-local `.codex` directory is created.

**Codex hook trust:** new definitions must be reviewed and trusted using `/hooks` or the host's
hook-management interface. Merely writing `hooks.json` does not enable untrusted hooks.
Existing sessions may need to reload/resume after configuration changes. A manual invocation
of the script proves the handler, not that a desktop session has loaded it.

### Bind an existing conversation

New sessions get distinct identities automatically. To keep a previously registered identity,
explicitly bind its real session ID (do not copy someone else's binding):

```powershell
node C:\GSADUs\.claude\hooks\agent-mail\delivery.mjs bind claude-code 15fdc049-16e1-42a3-bc9f-bfef788636e0 C:\GSADUs\WebApp RoseMoose
node C:\GSADUs\.claude\hooks\agent-mail\delivery.mjs status
```

Binding validates the harness and refuses a mailbox already assigned to another session.
An explicitly bound existing conversation may use its historical project key even when its
cwd differs (the original installer ran at the workspace root but registered in WebApp).

### Verification and limits (2026-09-14)

```powershell
node --test C:\GSADUs\.claude\hooks\agent-mail\delivery.test.mjs
```

Tests cover per-session isolation, adoption, deduplication, throttling, read-state preservation,
bounded previews, outage retry, bounded stop continuation, worktree normalization and safe
idempotent configuration merges. The direct local MCP transport is checked separately.

The original real Claude/Codex exchange is [thread 6](http://127.0.0.1:8765/mail/c-gsadus-webapp/thread/6):
messages 6–9 proved bidirectional communication with explicit active polling. That test did
not prove lifecycle delivery or idle wakeup.

Installed locally on 2026-09-14: all 14 tests pass; Codex `hooks/list` reports all four handlers
enabled/trusted with no errors or warnings. Trust was granted through the CLI `/hooks` review
interface, not by bypass flags or manufactured hashes. A real-mail handler probe delivered
message 10 and suppressed duplicate output using separate temporary state; the real task's
notification remains pending for a fresh-turn loading check. An existing Claude session has
already recorded a `PostToolUse` check through the installed hook. The original RoseMoose
session has a follow-up probe (message 11) waiting for its next normal activity. Neither a
manual handler probe nor hook registration alone is evidence of idle wakeup.

**Idle wakeup is not installed.** Codex background hooks do not start idle turns. The installed
Windows CLI (0.144.6) reports that managed app-server daemon lifecycle is Unix-only; its desktop
worker uses stdio. No supported external attachment to that live worker was established.
Claude documents `asyncRewake` and channel notifications, but the original session has neither
enabled. A continuously running hook/channel would need its own bounded lifecycle and live
verification before it can be called a wakeup bridge.

References: [Codex hooks](https://learn.chatgpt.com/docs/hooks),
[Codex App Server](https://learn.chatgpt.com/docs/app-server),
[Claude hooks](https://code.claude.com/docs/en/hooks),
[Claude channels](https://code.claude.com/docs/en/channels-reference).

## Upgrading

Download the next `mcp-agent-mail-x86_64-pc-windows-msvc.zip` + `.sha256` from the GitHub
release, verify, stop the server, replace both exes in the install folder, start it. The
data directory survives; `am doctor check` afterwards.

## Second machine (vg-home)

Same steps, same paths: install the binaries, run `Register-AgentMailTask.ps1` (it starts the
server) before any hook is installed, then `claude mcp add` and `codex mcp add` as above,
and copy the hook entry into `~\.claude\settings.json`. The workspace
files arrive with `unwip-all`; run `install-delivery.mjs --apply` and review Codex hook trust
there too. Mailboxes and session bindings are per machine — they are not synced.

## Evening continuation / home rollout (2026-09-14)

Owner intends to continue from home and SSH into this work PC. Home is currently powered
off; no connection attempt or home-machine changes were made. Finish verification on work
before repeating the installation at home.

- Work: `gsadus-vadim`, account `Vadim`, home directory `C:\Users\Vadim`.
- Home: `vg-home`, account `User`, home directory `C:\Users\User`.
- From home, `ssh Vadim@gsadus-vadim` runs on work and uses work's existing localhost Agent
  Mail server. A locally running home agent will use home's separate mailbox after enrollment.
- For unattended SSH use `-o BatchMode=yes -o ConnectTimeout=10`. For commands with variables
  or expressions, copy a small script, execute it with `pwsh -NoProfile -File`, verify, then
  remove that exact temporary script; avoid nested quoting across shells.

### Finish here first

1. Reload/resume this Codex desktop task. A fresh user turn after installation still left
   its binding at `lastCheck: 0`; the existing host has not loaded the new hooks despite
   their persisted trusted/enabled status. Do not mistake a manual inbox read for delivery.
2. Check that `delivery.mjs status` now records a hook event for session
   `01a0a20c-ec5e-7932-8ccf-b6afabf810ee` (TealDesert) and that test message 10 appears as
   automatic hook context. Message 10 was deliberately left unread.
3. Resume the original Claude conversation (`15fdc049-16e1-42a3-bc9f-bfef788636e0`, RoseMoose)
   and verify message 11 arrives at a normal lifecycle event and its reply reaches Codex.
   A different active Claude session already executes the installed hook successfully.
4. Treat idle wakeup as separate unfinished work; no idle-session push bridge is installed.

### Then enroll home

1. On the receiving home PC run `unwip-all` (workspace root first, missing repos cloned,
   then the remaining repos). Do not replace this with a single-repo pull for a workspace sync.
2. Install the verified Agent Mail release and loopback-only server config under the home
   user's paths. Register its at-logon task with `Register-AgentMailTask.ps1` (it starts the
   server outside every app) and verify health, before step 3 installs any hook.
3. Add the MCP endpoint to both home harnesses using the commands above, then run
   `install-delivery.mjs --apply` locally. It resolves home-user settings paths automatically.
4. Review/trust the four new Codex hooks and reload the harnesses. Register distinct home
   session identities; do not copy work's bindings, database, tokens or account credentials.
5. Repeat the real-message tool-boundary test there. Mailbox history does not travel through
   git or `wip`; shared cross-machine delivery would be an additional design decision.

Only this workspace repository's committed changes are pushed for this handoff. Untracked
files and other repos' work are not included; this is not a substitute for an owner-run
`wip-all` when moving all in-progress work between PCs.
