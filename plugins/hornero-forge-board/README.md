# Hornero Forge Board

CI and pull-request status for the GitHub repositories you name, as a
dashboard card and a desktop widget (PluginKit 3, `schemaVersion: 3`).

## What it shows (real data only)

Per `owner/name`: the latest workflow run (passing, failing, running, none) with
its branch and title, and your open pull requests with draft, review and
check state. Two read-only `gh` calls per repository per refresh
(`gh run list`, `gh pr list --author @me`).

## Credentials, honestly

This extension has no token field and never reads or stores a token. It runs
the `gh` CLI you installed and signed into yourself (`gh auth login`), exactly
as a terminal would; the credential stays in gh's own store. If `gh` is
missing or signed out the card says so. Declared capabilities:
`processCommands: ["gh"]`, `networkHosts: ["api.github.com"]` (the requests are
made by `gh`, not by QML). Repository names are validated against
`owner/name` before they reach a command line, so a setting cannot inject a
flag. It never comments, merges, reruns or edits anything. Requests pause in
the Gaming experience.

## Settings

`repositories`, `maxRepositories` (1-6), `refreshMinutes` (2-60),
`showPullRequests`, `maxPullRequests` (1-5).

## Enable

```sh
gh auth login
horneroctl plugin catalog install hornero-forge-board --yes
horneroctl plugin enable hornero-forge-board --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed.

## PluginKit 3

Colours, type, spacing and glyphs come from the shared Theme tokens.
