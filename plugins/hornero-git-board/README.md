# Hornero Git Board

A read-only status board for the repositories you name, as a dashboard card
and a desktop widget (PluginKit 3, `schemaVersion: 3`).

## What it shows (real data only)

Per repository: branch (or detached HEAD), ahead/behind of its upstream,
counts of staged, changed, untracked and conflicted entries, and the last
commit subject and age. Colour follows state on a thin accent rail: phosphor
clean, signal dirty, cue unsynced, alert conflicted or unreadable. A path git
cannot read is an explicit error row, never "clean".

## How it reads

Only `git status --porcelain=v2 --branch` and `git log -1`, one repository at
a time, with `--no-optional-locks` and `core.fsmonitor=false`. It never
fetches, pulls, pushes, commits, or touches the network, so "behind" means
behind the last fetch you ran yourself. Paths must be absolute; relative
paths, `..` and control characters are dropped. Scanning pauses in the Gaming
experience.

## Settings

`repositories` (semicolon-separated absolute paths, empty scans nothing),
`maxRepositories` (1-8, default 5), `refreshSeconds` (10-600, default 30),
`sortBy` (`attention` or `path`), `showLastCommit`, `showCleanDetails`.

## Permissions

`capabilities.processCommands: ["git"]`, no network hosts, no providers.

## Enable

```sh
horneroctl plugin catalog install hornero-git-board --yes
horneroctl plugin enable hornero-git-board --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed.

## PluginKit 3

Colours, type, spacing and glyphs come from the shared Theme tokens.
