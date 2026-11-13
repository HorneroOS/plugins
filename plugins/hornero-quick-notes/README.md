# Hornero Quick Notes

Dashboard card (`"placement": "dashboard"`) with one
**persistent** note. This is the persistent member of the notes
family: Hornero Quiet Notes keeps a session-only line that is
never saved, and Hornero Focus Card shows rotating reminders you
do not edit. The three stay separate extensions (reviewed under
HorneroOS/plugins#29) because their persistence semantics are
opposites; merging them would hide exactly the distinction that
keeps user text safe. No user data moves between them.

## Persistence — read this before typing

- Stored through the PluginKit `Settings` API (`pluginId`
  `hornero-quick-notes`, declared string setting `note`, default
  `""`, max 4096 characters), in the shell-owned settings store
  (`$XDG_CONFIG_HOME/hornero/shell.json`, per PluginKit docs).
  The key and namespace are unchanged from 1.x, so **upgrading
  keeps your existing note with no migration**.
- Loaded on start, saved debounced (typed `autoSaveDelayMs`,
  default 600 as in 1.x). `Ctrl+S` in the editor or **Save now**
  saves immediately, and disabling/unloading the extension
  flushes any pending edit first, so the debounce window cannot
  eat your last keystrokes. Disabling keeps the stored note; it
  comes back when the extension loads again.
- Text past 4096 characters is clamped before saving (1.x
  behaviour) and the clamp is announced in the card. A refused
  Settings write shows a **Save failed** chip instead of looking
  saved; the text stays in the editor — edit or save again to
  retry. Clearing asks for confirmation because erasing the
  stored note cannot be undone (there is no history or trash).

## Keyboard

The editor is a normal tab stop. Inside it: typing edits,
`Ctrl+S` saves now; standard text keys (selection, copy/paste,
undo in the field) are the toolkit's. **Save now**, **Clear**,
**Confirm clear** and **Cancel** are `UiButton`s: Tab to them,
Enter/Space activates, and each carries a tooltip and an
accessible name. Nothing here needs a mouse.

## Settings

Declared in the manifest and read through PluginKit `Settings`
at load (changes apply from the next reload): `note` (your
text), `autoSaveDelayMs` (integer 200–5000, default 600),
`showCounts` (boolean, default `true`, the 1.x count line).

## PluginKit surface, and its gaps

Verified against the PluginKit QML in HorneroOS/shell:
`Settings.pluginId/value/setValue` (including the boolean
refusal return checked above), `Translations.pluginId/tr/
formatNumber`, `UiCard`, `UiText`, `UiChip`, `UiButton`,
`UiStack` and `Theme.spacingSmall/surfaceContainer/onSurface/…`
via those primitives. PluginKit exposes **no clipboard, file,
export or multi-note/history store**, so Quick Notes 2.0 has no
export, backup or second note rather than inventing one: if you
need the text elsewhere, select it and copy with the toolkit
keys. A saved-state timestamp is also not shown, because
`Settings` reports no per-key write time.

Native theming comes from the `Ui*` primitives and `Theme`
tokens; no colours are hard-coded. Static probes only have been
run against this package (repo validator, shell validator oracle
and the Node-checked `NOTE-LOGIC` tests in
`tests/test_notes_focus_logic.py`); rendering in a live shell
session has not been verified.

No processes, no network. Original HorneroOS code, MIT licensed.
Plugin QML runs with your user privileges inside Quickshell; it
is not sandboxed.
