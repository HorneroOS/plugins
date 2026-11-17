# Hornero Audio Deck

A desktop instrument for Hornero Signal, built on PluginKit 3
(`placement: "desktop"`, `schemaVersion: 3`). The shell host draws the module
frame and owns position, size and edit mode (`qs ipc call plugins
editDesktop`); this package lays out the content.

## What it shows (real data only)

- **Spectrum**: the shell's PipeWire visualiser analysis of the default
  output (`Audio.spectrum`, provider domain `spectrum`), one vertical VU strip
  per band (`UiSegmentMeter` with `vu`, `phosphor`). It moves only while sound
  plays; with nothing playing every segment is off. There is no idle animation
  and no simulated level.
- **Now playing** from MPRIS (`Media`): title, artist and album, and the
  playing/paused state in the module header.
- **Output volume** as a segmented meter and the output device name.

The `spectrum` domain runs the shared visualiser only while some surface holds
a lease. This widget holds one while loaded; set `showSpectrum` to `false` to
release it (the spectrum area hides and the visualiser can stop). The `media`
and `audio` domains are event-driven. The widget has no controls: it shows
state, transport and volume stay in the shell. The host suspends desktop
widgets in the `gaming` experience.

## Settings

`showSpectrum` (default `true`), `showArtist` (default `true`), `bandCount` (4-24, default `24`; fewer bands
average neighbouring real bands, more are never invented).

## Enable

```sh
horneroctl plugin catalog install hornero-audio-deck --yes
horneroctl plugin enable hornero-audio-deck --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed. No processes, no network.

## PluginKit 3

This package targets PluginKit 3 on Hornero Signal (`schemaVersion: 3`):
colours, type, spacing and glyphs come from the shared Theme tokens and the
shared data domains it reads are declared in `capabilities.providers`.
