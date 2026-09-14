# agent-scrumban — design

Date: 2026-09-11
Status: draft, awaiting review

A native macOS board that mirrors a Jira scrumban, shows which coding agents are
genuinely alive, and drives Supacode through its CLI. It owns no terminal, no
worktree and no agent process. Delete it and Supacode is unchanged.

## Problem

Running ten Supacode worktrees in parallel, there is no reliable answer to
"what is actually running right now". Supacode's status icons show sessions as
busy long after the agent has stopped, so keeping track means clicking through
the sidebar. Separately, the work itself lives in a Jira scrumban that Supacode
knows nothing about, so the sidebar ordering has no relationship to the board
the work is planned on.

### Why the icons are wrong

Supacode's Claude Code hooks write state into the terminal byte stream. The hook
resolves a tty from the parent pid and emits an OSC 3008 escape sequence:

```sh
__ppid=$(ps -o ppid= -p $$)
__tty=$(ps -o tty= -p "$__ppid")   # else fall back to /dev/tty
printf '\033]3008;start=claude;event=busy...' > "$__tty"
```

`PreToolUse` and `UserPromptSubmit` emit `busy`; `PostToolUse` and `Stop` emit
`idle`. The transport is fire-and-forget with no timeout and no reconciliation,
so a single lost `idle` leaves the session busy forever. Events are lost
whenever the tty guess is wrong — notably when an extra shell level sits between
the hook and the terminal, which is also why an aliased launcher such as
`claudep` is never detected at all. Both symptoms have one cause.

Supacode exposes a socket (`SUPACODE_SOCKET_PATH`, `supacode socket`). The events
do not use it.

### Evidence

On 2026-09-11, `zmx list` reported 7 live sessions while `ps` found 2 live
`claude` processes. The sidebar disagreed with both.

## Non-goals

- No embedded terminal. See "Rejected: embedded terminal" below.
- No agent spawning of its own — every session is created by Supacode.
- No worktree management, merging, or PR flow. Supacode and `glab` already do these.
- No support for harnesses other than Claude Code in v1.

## Architecture

Three layers, each independently testable, each replaceable.

```
Jira Agile REST ──┐
                  ├──> mapping ──> board view ──> supacode CLI
zmx list + ps ────┘
```

### 1. Truth

The only layer that must be correct.

`zmx list` (binary bundled at
`/Applications/supacode.app/Contents/Resources/zmx/zmx`) returns one line per
Supacode session:

```
name=supa-<uuid>  pid=86482  clients=1  created=<epoch>  start_dir=<worktree path>  cmd=...
```

`start_dir` is the worktree path, which is the join key for everything else.

Agent state is derived from process truth, not from events:

| Signal | Source |
|---|---|
| session exists | `zmx list` |
| worktree path | `start_dir` |
| agent alive | a `claude` process among the **descendants of the session's pid** |
| agent age | process `etime` |
| last activity | mtime of the newest `~/.claude/projects/<encoded path>/*.jsonl` |

Aliveness walks the process tree from each session's `pid` using a single
`ps -axo pid=,ppid=,command=` call. This binds the agent to the *session* rather
than to a directory, so two sessions rooted in the same path are never confused,
and it avoids `lsof` entirely. Verified 2026-09-11: of 7 sessions, exactly the 2
with a live agent produced a `claude` descendant.

A session is **running** only when a live `claude` process is found. There is no
state that can stick: every poll recomputes from the process table. This is the
single behavioural difference from Supacode, and the reason the app exists.

Polled every 2 seconds while the window is visible, every 10 while it is not.
`zmx list` and `ps` are both cheap; there is no cache to go stale.

Hook payloads may later enrich this (which tool is running, last assistant
message) but are never the source of truth for aliveness.

### 2. Mapping

- Worktree path → branch (`git -C <path> branch --show-current`)
- Branch → issue key via `ABC-\d+`; the repo's branch convention
  (`f/ABC-XXX-<slug>`) guarantees a match
- Issue key → Jira issue → its status → the board column that status maps to

Unmatched items are shown, never dropped:

- A Jira issue with no worktree is a plain card.
- A worktree with no issue key (`f/storybook-deploy`) goes in an "unmapped" lane.

### 3. Jira sync

Read-only except for explicit transitions. No manual board setup.

| Call | Purpose |
|---|---|
| `GET /rest/agile/1.0/board?projectKeyOrId=ABC` | discover the board |
| `GET /rest/agile/1.0/board/{id}/configuration` | columns and their mapped statuses |
| `GET /rest/agile/1.0/board/{id}/issue` | the cards |
| `GET /rest/api/3/issue/{key}/transitions` | available transitions |
| `POST /rest/api/3/issue/{key}/transitions` | apply one, on explicit confirm |

Columns come from the board configuration, so renaming a column in Jira changes
the app with no code or config change. The only configuration is an API token in
Keychain.

Poll on a slow cadence (5 minutes) and on window focus. Jira is not the hot path;
the truth layer polls far more often.

### 4. Actions

Every write goes through the Supacode CLI, verified present in 0.10.7:

| Card state | Action |
|---|---|
| issue, no worktree | `supacode repo worktree-new --repo <id> --branch f/<KEY>-<slug> --base devel --fetch` then `supacode tab new -w <wt> --input "claude '<prompt>'" --title "<KEY>"`, where `<prompt>` is the issue key, summary and description — the same handoff the existing `/jira` skill performs |
| has worktree | `supacode worktree focus -w <wt>` — Supacode comes forward |
| any | `supacode worktree appearance -w <wt> --color <state colour>` to tint the real sidebar |

Jira transitions sit behind an explicit Apply button. Dragging a card never
writes to Jira on its own; it stages a transition the user confirms. This is a
hard rule, not a preference: the board writes to a system other people read.

## UI

A single window, columns from the Jira board, plus a menubar item.

- Card: issue key, summary, agent badge, branch, diffstat, runtime
- Badge states: running, needs input, error, idle, no worktree
- Filter chips: "needs you", "running", "all"
- Menubar: count of sessions needing attention; click to open the board
- Click a card: focus it in Supacode (or create the worktree first)

Mirrors the Supacode sidebar tint via `worktree appearance`, so the fix is
visible even with the board closed.

## Milestones

| # | Deliverable | Estimate |
|---|---|---|
| M1 | Truth layer as a CLI that prints correct state for all worktrees | 0.5 d |
| M2 | Jira sync: board config → columns, issues → cards | 0.5 d |
| M3 | Board window: columns, cards, badges, filters | 1 d |
| M4 | Actions: focus, create worktree + launch, sidebar tint | 0.5 d |
| M5 | Menubar item and polish | 0.5 d |

≈ 3 days. M1 is independently useful and should be validated against a real day
of work before M3 is started.

## Risks

- **Supacode CLI is not a stable API.** Output formats may change between
  releases. Mitigation: parse in one adapter module; pin the tested version in
  the README. Issue #820 upstream asks for `--json`, which would remove this risk.
- **`zmx list` output is likewise unversioned.** Same mitigation, same module.
- **Jira board discovery** is assumed to work against the instance; the endpoint
  shapes are documented but were not called during design. M2 starts by verifying
  them.
- **Two apps tinting the sidebar** could fight if Supacode later sets colours
  itself. Make the tint opt-in.

## Rejected alternatives

- **Migrate to vibe-kanban.** Bloop shut down in April 2026; last commit
  2026-04-24. Also replaces the terminal, which is the part worth keeping.
- **Fork Supacode.** Legal under FSL-1.1-ALv2 for private use, but a board is a
  large addition to someone else's TCA state tree in an actively developed repo.
  Permanent rebase cost for a feature that does not need to live inside the app.
- **Fork claude-control.** Its reconciliation approach is sound and worth reading
  (MIT), but it is Electron/Next.js and the requirement is a native app.
- **Embedded terminal via `zmx attach`.** A second client must negotiate session
  size with Supacode's, which is exactly the failure behind Supacode issue #780
  (corrupted screen after re-attach at placeholder geometry). A careless probe
  during design already destroyed a live surface. Launching Supacode instead
  removes the risk entirely and makes the app disposable.

## Follow-ups, not in scope

Two upstream issues to file against `supabitapp/supacode`, drafted separately:

1. Agent state is lost because hook events go over the tty rather than the
   socket, with no reconciliation — covers both stuck-busy icons and undetected
   aliased launchers.
2. `worktree list --json` with agent state, extending the existing request in
   issue #820.

Also: Supacode 0.10.8 is the newest release (2026-08-03), but the fix for #780
landed 2026-08-10 and is unreleased. Currently running 0.10.7.
