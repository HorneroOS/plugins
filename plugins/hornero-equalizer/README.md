# Hornero Equalizer

A live spectrum analyser for the bar, in the spirit of Caelestia's audio
visualiser and equaliser. Only the concept is borrowed; no code or assets.

## What it is, and what it is not

It is an **analyser**: it shows the real PipeWire spectrum of your default
output (`Audio.spectrum`, the shell's shared `spectrum` provider). It is **not**
a sound equaliser. PluginKit gives extensions no way to filter or retune audio,
so there are no bass or treble sliders and none are faked. To change how
things sound, use an equaliser that sits in your audio graph (for example a
PipeWire filter-chain) and pair it with this view.

## Honest data

- Bands are real samples, clamped to 0 to 1. Nothing is drawn while nothing
  plays; there is no idle animation and no interpolated level.
- Fewer bands than the provider reports are averages of neighbouring real
  bands; more are never invented.
- The peak ticks in the popover are derived from the real samples with a fixed
  decay per sample and are labelled as such.

## Cost

The shared analyser only runs while some surface holds a `spectrum` lease.
By default this extension holds it only while a media player is playing
(`analyseWhen: playing`), so a silent desktop pays nothing. `always` also
covers sound from apps that publish no media player.

## Settings (Control Center, Extensions)

| Setting | Default | Meaning |
| --- | --- | --- |
| `barBands` | `8` | Bands in the bar indicator (4 to 12). |
| `popoverBands` | `16` | Bands in the popover (8 to 24). |
| `peakHold` | `true` | Peak ticks in the popover. |
| `analyseWhen` | `playing` | `playing` or `always`. |
| `whenSilent` | `glyph` | Keep the button (`glyph`) or `hide` it while silent. |
