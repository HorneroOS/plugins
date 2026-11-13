# Hornero Quiet Notes

A calm dashboard card (`"placement": "dashboard"`) for one
short intention for **this session only**. It is the ephemeral
member of the notes family, labelled on the card itself
(“Session only — never saved”): Hornero Quick Notes is the one
that saves and restores your text, and Hornero Focus Card shows
rotating reminders. The three stay separate extensions
(reviewed under HorneroOS/plugins#29); no user text moves
between them, because silently persisting a Quiet Notes line —
or silently dropping a Quick Note — is exactly the failure the
split exists to prevent.

Tab to **Set intention**, write one line, press Enter (or the
**Accept** button). Esc (or **Cancel**) discards the edit and
keeps the previous line. **Clear** erases the current line.
That is the whole feature — on purpose.

## Persistence — the point is that there is none

- The intention lives in an in-memory QML property, as in 1.x.
  It is never written through PluginKit `Settings`, to a file,
  or anywhere else; there is no history.
- Closing or restarting the shell erases it, and so does
  disabling this extension. Nothing is migrated on upgrade
  because nothing was ever stored — upgrading cannot lose a
  saved note, only the current session's line ends with the
  session, exactly as promised.
- The manifest declares two Settings keys, `maxLength` and
  `showCounter`, and those are *display preferences only*
  (defaults reproduce 1.x: 140 characters, counter hint shown).
  Preferences persist in the shell settings store like every
  extension's; the intention text deliberately has no key.
  Review the source: search for `setValue` finds nothing.
- PluginKit offers no hook to warn before the shell exits, so
  there is no exit prompt; the on-card label is the contract,
  stated before you type, not after you lose text.

## Keyboard and theming

1.x opened its editor only from a mouse click on the card, with
hard-coded editor colours. 2.0 is keyboard-first: every action
is a `UiButton` tab stop with a tooltip and an accessible name,
the editor is a themed `TextField` (Enter accepts, Esc
cancels), accepting/cancelling returns focus to the edit
button, and all colours come from `Ui*` primitives / `Theme`
tokens. Text is normalized to a single line (whitespace runs
collapse, ends trimmed) and clamped to `maxLength`; the pure
`INTENTION-LOGIC` block is covered by
`tests/test_notes_focus_logic.py` under Node.

## PluginKit surface

Verified against the PluginKit QML in HorneroOS/shell:
`Settings.pluginId/value` (read-only here — preferences only),
`Translations.pluginId/tr/formatNumber`, `UiCard`, `UiText`,
`UiChip`, `UiButton`, `UiStack`, `Theme.spacingSmall/onSurface`
(via primitives where possible). No facade gap is worked
around: nothing in PluginKit is needed to *not* save text.

Only static probes have been run against this package (repo
validator, shell validator oracle, logic tests); rendering in
a live shell session has not been verified.

Original HorneroOS code, MIT licensed. Plugin QML runs with
your user privileges inside Quickshell; it is not sandboxed.
This plugin declares zero process commands and zero network
hosts in its manifest.
