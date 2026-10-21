# Hornero Quiet Notes

A calm dashboard card for one short intention for this session.

Click the card, write one line (up to 140 characters), press Enter.
Esc cancels. That is the whole feature — on purpose.

## Privacy by construction

- In-memory only: the note lives in a QML property.
- No files, no processes, no network, no settings, no history.
- Closing or restarting the shell erases it. There is nothing to
  sync, leak, or clean up later.

## Placement

Dashboard card (`"placement": "dashboard"`), rendered by the shell
in its own Loader in the dashboard Extensions tab.

Original HorneroOS code, MIT licensed. Plugin QML runs with your
user privileges inside Quickshell; it is not sandboxed. This plugin
declares zero process commands and zero network hosts in its
manifest, and its source is short enough to review in one read.
