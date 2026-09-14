# agent-scrumban

A macOS board that puts your Jira issues and your [Supacode](https://supacode.ai) worktrees on the
same screen. Each card is a Jira issue; under it sit the worktrees that carry its issue key, and for
each worktree a live line on what its coding agent is doing right now — working, waiting on you, or
idle. Click a session to focus it in Supacode. Move a card to transition the issue in Jira.

It is a companion to Supacode, not a replacement. Supacode still owns the worktrees, the terminals
and the agents; agent-scrumban only reads them and reports back.

## Requirements

- macOS 14 or later
- Supacode installed, with its CLI on your path
- A Jira Cloud account and an [API token](https://id.atlassian.com/manage-profile/security/api-tokens)

## Install

Download `AgentScrumban.zip`, unzip it, and drag `AgentScrumban.app` into `/Applications`.

The app is ad-hoc signed, so Gatekeeper blocks the first launch. Right-click the app and choose
**Open**, then confirm — once. If you would rather do it from a terminal:

```
xattr -d com.apple.quarantine /Applications/AgentScrumban.app
```

## Configure

Open **Settings** (⌘,) and fill in:

- **Site** — your Jira URL, for example `https://example.atlassian.net`
- **Email** — the account the API token belongs to
- **Project key** — the project whose board you want, for example `ABC`
- **Filter (JQL)** — which issues to show, default `assignee = currentUser()`
- **Token** — paste your Jira API token and press Save
- **Path** — the repository Supacode creates worktrees in
- **Base branch** and **Branch name** — used when you start work on an issue

The token goes into your login keychain under the service `agent-scrumban`, keyed by the email above.
The app never writes it to disk. Settings shows whether a token is stored, and clears it on request.

## Build from source

Needs [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```
make release   # produces dist/AgentScrumban.zip
make test      # Core, app and UI test bundles
```
