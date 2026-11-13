# Hornero Now Playing

Now Playing 2.0 (manifest v2): one package, two surfaces over the
shared PluginKit `Media` facade (MPRIS, event-pushed; the surfaces
hold a `Subscription { domain: "media" }` lease and never poll).

- **Bar** (`"placement": "bar"`, primary): a compact indicator —
  one glyph button plus, on roomy horizontal bars, the elided track
  title and artist. Activating the indicator opens a host-owned
  `UiPopover` with player identity, playing/paused state, track,
  artist and previous / play-pause / next controls.
- **Dashboard** (`surfaces.dashboard`, `size: "standard"`,
  `category: "Media"`): the same metadata and transport as a card.

Both surfaces render with PluginKit `Ui*` primitives, host context
(`hostOrientation`/`hostCompact`/`hostAvailableWidth` via
`UiStack` and compact label-dropping), host-owned tooltips,
accessible names, Theme tokens and English source strings with an
Argentine Spanish catalog (`translations/es.json`, via PluginKit
`Translations`). Transport (`Media.previous()` / `playPause()` /
`next()`) runs only from user clicks.

## Why this is not the shell's native media component

The shell already ships a native bar media component with inline
transport that collapses to nothing while no player is active.
This extension's distinct value is that it is an opt-in,
removable indicator: it takes a single button of bar space
(instead of three inline transport buttons), can stay visible and
labelled in the no-player state so users can see why nothing is
playing, names the player and its playing/paused state explicitly
in its popover, and adds a dashboard card the native bar component
does not have. Users who keep the native component enabled do not
need this extension in the bar; its dashboard surface still works
on its own.

## Honest limits (PluginKit Media surface)

The PluginKit `Media` facade exposes exactly `hasPlayer`,
`identity`, `title`, `artist` and `isPlaying`, plus previous /
play-pause / next (shell `docs/PLUGINS.md`). It exposes **no**
player list or selection, album, artwork URL, track length,
playback position or seek — so this package does not invent them:

- **Player selection** stays with the shell's active-player
  choice; the popover and card name that player via `identity`.
- **Rich metadata** means identity + title + artist + playing
  state, the full facade surface. No artwork is shown because no
  artwork is exposed.
- **Seek** is not offered; a seek slider over invented positions
  would misrepresent playback. Previous / play-pause / next are
  the meaningful transport actions the facade provides.

Adding those needs a shell-side PluginKit Media expansion first;
until then they are tracked by the issue, not faked here.

## States

- **No player**: the bar stays labelled "No player" (the 1.x
  behaviour) unless the typed `showWhenNoPlayer` setting is turned
  off, in which case the indicator takes no bar space; the popover
  and dashboard card show an empty state explaining that starting
  playback in a media app will populate them.
- **Idle/stale player**: a player that reports neither title nor
  artist is named by identity and labelled as reporting no track
  information (it may be idle or stale), instead of showing blank
  fields as if they were a track.

## Compatibility

- The plugin declared no settings before 2.0, so no stored values
  migrate. The new typed settings default to the 1.x hardcoded
  behaviour: `showArtist` (boolean, default `true` — artist shown
  when reported), `showWhenNoPlayer` (boolean, default `true` —
  widget visible labelled "No player") and `maxTitleWidth`
  (integer 80–240, default `180` — the 1.x title width).
- 1.x kept transport inline in the bar; 2.0 moves it into the
  popover and dashboard card to keep the bar compact and avoid
  duplicating the shell's native inline controls (issue
  acceptance). Metadata display in the bar is unchanged.
- Installing this manifest v2 package needs a shell/`horneroctl`
  that accepts `schemaVersion` 2, the `translations` declaration
  and the `marketplace` block.

No processes and no network. Original HorneroOS code, MIT
licensed. Plugin QML runs with your user privileges inside
Quickshell; it is not sandboxed.
