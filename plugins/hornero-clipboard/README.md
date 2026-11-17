# Hornero Clipboard

A private clipboard history for the launcher, built on PluginKit 4.

- **Launcher:** `>clipboard` lists what you copied recently (newest first);
  `>clipboard word` filters it. Enter copies the entry back and closes the
  launcher. Needs a Hornero Shell with multi-row launcher results (shell
  docs/LAUNCHER.md, "Several rows").
- **Commands** (`>do clipboard`, or IPC / your own key binding):
  `pause`, `resume` and `clear`, e.g.
  `qs ipc call plugincommands run hornero-clipboard clear`.
- **Card:** the recorder's honest state with Pause and Clear. It never shows
  clipboard contents.

## Privacy by design

- **Memory only.** History is held by the shell process and is erased on shell
  restart, when the extension is disabled and by Clear. Nothing is written to
  disk, to `shell.json` or to a log. Persisting history would need a
  host-owned private store with 0600 permissions that PluginKit does not offer
  yet; until it does, there is nothing to opt into and nothing to leak.
- **Text only.** Images and other types are ignored.
- **Secrets are skipped.** An offer that a password manager marks with
  `x-kde-passwordManagerHint` is not recorded (`skipSensitive`, default on).
  Apps that do not set the hint cannot be told apart: add words to
  `excludeWords` or pause recording while you handle secrets.
- **Limits you set.** Entries over `maxChars` or containing an excluded word
  are never recorded; entries expire after `retentionMinutes`.
- **Honest start-up.** `wl-paste --watch` reports the clipboard that already
  exists when it starts; the first half second is ignored so a value copied
  before you enabled recording is not captured.
- **No network.** `networkHosts` is empty. The processes are `wl-paste` (the
  watcher and two short reads per change) and `echo` (the watcher's trigger).

## Settings (Control Center, Extensions)

| Setting | Default | Meaning |
| --- | --- | --- |
| `recording` | `true` | Off stops the `wl-paste` watcher entirely. |
| `maxEntries` | `25` | Entries held at most (5 to 100). |
| `retentionMinutes` | `60` | Erase after this many minutes; 0 keeps until restart. |
| `maxChars` | `2000` | Longest copy recorded (50 to 20000). |
| `excludeWords` | empty | Comma-separated words that block recording. |
| `skipSensitive` | `true` | Skip password-manager secrets. |

A very large text copy is read before it is rejected for its length; keep
`maxChars` modest if you copy huge files as text.

The idea comes from Caelestia's Stowaway (a clipboard and emoji launcher); no
code or data of Stowaway is used. Emoji search is the companion extension
`hornero-emoji`.
