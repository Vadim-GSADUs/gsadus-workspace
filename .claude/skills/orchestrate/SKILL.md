---
name: orchestrate
description: Act as the owner's orchestrator for the GSADUs board — take the owner's updates, decisions and ideas, keep the Vault board's thread notes current, send work to the right existing session or open a new one, and brief the owner. Use when the owner asks what's on the board, what's waiting on them, who should take a piece of work, or for a morning brief or weekly board review.
---

# orchestrate — the board's books, not the work

The owner talks to one pinned session at `C:\GSADUs`. It keeps the board and routes work to
specialist sessions; it never implements. It edits only `Board.md` and the thread notes, never
repo code (owner decision 2026-10-05).

- **Board:** `Vault\Board.md`, a Kanban board: the lane is a thread's state, the card's place
  its rank. One note per thread in `Vault\board\threads\`. Schema and rules: `Vault\AGENTS.md`
  → Board.
- **Activity:** `Vault\wiki\auto\activity.md`, written by the vault scan: commits per repo,
  quiet threads, threads whose sources changed after `touched`.
- **Sessions:** the desktop session tools list, read, message, rename and archive Code tab
  sessions on this machine. The other PC: Remote Control, or `ssh` (hostnames in
  `Vault\wiki\curated\key-locations.md`).

## Rules

1. **Only the owner opens a thread.** Agent suggestions (yours, a worker's, an old
   transcript's) are proposals: name, project, next step, doc link, then wait for a yes.
2. **GSADUs only.** Sessions and folders outside `C:\GSADUs` are not the board's business.
3. **One worker per thread per machine.** Parallel work on one repo goes in worktrees.
4. **Link, never copy.** Repo detail stays in the repo; a note points at its doc.
5. **A worker runs in its thread's repo** (owner 2026-10-06). The session starts at
   `C:\GSADUs\<repo>`: the note's `project`, at its path in the workspace tree (`PNGTools` is
   `PostProcess\PNGTools`). That way the repo's own `AGENTS.md`, skills (`/handoff`), hooks and
   project memory load, and the sidebar groups the session with its repo. Only `Workspace`
   threads and cross-repo work start at `C:\GSADUs`. A worktree goes under
   `<repo>\.claude\worktrees\`; a workspace worktree can't edit sub-repo files.

## Intake: every owner message is one of these

| Message | Do |
|---|---|
| News about a thread | Update its note (`next`, `blocker`, `asks`, `touched`; `intent` only if the purpose changed); move its card if the state changed |
| A new piece of work | Propose a thread (rule 1); on yes, write the note, its `intent` in plain English and `planned_in` set to the session where the owner shaped it, and add its card where the owner says |
| An order change ("put X above Y") | Move the cards; ranks are the owner's alone |
| An answer to an ask | Remove the ask, send the answer to the thread's worker |
| An idea | On yes, a Parked card and note; otherwise `Vault\wiki\curated\big-ideas.md` |

## Routing

1. Find the worker: the thread's `workers` entry for this machine, if that session still
   exists and is not archived.
2. Reuse it: send a self-contained brief (thread, goal, links to the docs, what done looks like)
   and ask to be told when it goes idle. If it is deep in another slice, ask the owner to run
   `/compact` there first; you cannot compact another session. If the worker is running at
   `C:\GSADUs` but its thread is single-repo, have it `change_directory` to its repo first
   (rule 5).
3. No usable worker: offer a new-session chip titled with the thread name
   (`WebApp · switch day`), with `cwd` set to the thread's repo (rule 5). Without `cwd` the
   chip starts here, at the workspace. Once it exists, add it to `workers` as
   `MACHINE · session-id`.
4. When a worker reports back, check that its `/handoff` updated the note; fix the note if not.

## Morning brief (on request, or the owner's first message of the day)

Ten lines at most: Now, one line each; Waiting on you; quiet or drifted threads from
`activity.md`; sessions that ended on an unanswered question or left uncommitted work; board
review due.

## Weekly review (15 minutes, with the owner)

Walk Now, then Next, then Parked: reorder cards, move finished ones to Done, park what has
stalled, deprecate plans older than three months (workspace rule 7). Suggest archiving
the sessions of `done` threads; each archive waits for the owner's yes. Commit the review as
`board: weekly review` (`--allow-empty` when nothing changed); the hook dates the next one from it.

## Committing

Stage the notes you changed by explicit path, commit in the Vault as
`board: <thread> — <change>`, then push (`git -C C:\GSADUs\Vault pull --rebase --autostash` if
the push is rejected). Never commit other files you find changed in the Vault.
