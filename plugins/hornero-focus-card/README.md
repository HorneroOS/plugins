# Hornero Focus Card

A dashboard card (`"placement": "dashboard"`) with the date
and a rotating original one-line focus reminder. It is the
read-mostly member of the notes family, kept distinct under
HorneroOS/plugins#29: Hornero Quick Notes persists a note you
type, Hornero Quiet Notes holds a session line that is never
saved, and this card stores **no note at all** — its lines ship
with the extension, so there is nothing of yours for an upgrade
or a disable to lose. The only stored values are the typed
preferences below.

## What changed in 2.0 (and what deliberately did not)

- Date from the shared PluginKit `Time` facade behind a
  `Subscription` lease (`domain: "time"`), formatted in the
  resolved locale via `Translations.formatDateTime`. 1.x used
  its own `Date` and a hard-coded Spanish layout
  (`dddd d 'de' MMMM`) in every locale; the un-translated `de`
  token is dropped, so other locales read natively while
  Spanish keeps the same weekday/day/month order.
- Keyboard-first: **Previous**/**Next** `UiButton`s and a
  **Pause rotation** `UiToggle` replace the 1.x card-wide mouse
  click (the only way to advance). Every control is a tab stop
  with a tooltip and an accessible name; the card announces the
  current line (`Focus: …`) and its position (`Line x of y`).
- Native theming: `UiCard`/`UiText`/`UiChip`/`UiStack` and
  `Theme` tokens; 1.x `palette.windowText` is gone.
- Rotation index and pause stay in memory, as in 1.x: a reload
  restarts the rotation from the first line. Nothing about your
  session is written for them.

## Settings

Declared in the manifest, read through PluginKit `Settings` at
load (changes apply from the next reload); every default
reproduces 1.x: `rotateSeconds` (integer 5–600, default 30),
`showDate` (boolean, default `true`), and `customLine` (string,
max 140, default `""`). Setting `customLine` in the extension
settings puts your own line first in the rotation; empty —
the default, and the whole of 1.x — rotates only the five
built-in reminders. There is no in-card editor for it on
purpose: typing text to keep is Quick Notes' job, and
duplicating a persistent editor here would blur the family
split.

## PluginKit surface

Verified against the PluginKit QML in HorneroOS/shell:
`Time.date`, `Subscription.domain`, `Settings.pluginId/value`,
`Translations.pluginId/tr/formatDateTime/formatNumber`,
`UiCard`, `UiText`, `UiChip`, `UiButton` (including its
`ghost` variant), `UiToggle.value/checked` with `toggled()`,
`UiStack`, and `Theme.spacingSmall` via the primitives. No
facade gap affects this card; line wrapping/index math is the
pure `FOCUS-LOGIC` block covered by
`tests/test_notes_focus_logic.py` under Node.

Only static probes have been run against this package (repo
validator, shell validator oracle, logic tests); rendering in
a live shell session has not been verified.

No processes, no network. Original HorneroOS code, MIT
licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
