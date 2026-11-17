# Hornero Device Battery

Battery charge of wireless peripherals, as a dashboard card and a desktop
widget (PluginKit 3, `schemaVersion: 3`).

## What it shows (real data only)

One `upower -d` run per refresh. Devices of kind game controller, mouse,
keyboard, headset, headphones, touchpad, tablet, pen, phone and media player
are listed with their model, state and a segmented charge meter. Lowest charge
first. A device that reports no percentage is listed with its state only,
without a meter; nothing is estimated. Laptop and UPS batteries are hidden by
default because the shell's native battery indicator covers them; turn on
`includeInternal` to list them.

## Settings

`lowPercent` (5-50, default 20), `includeInternal`, `showModel`, `sortBy`
(`lowest` or `kind`), `refreshSeconds` (15-600, default 60).

## Permissions

`capabilities.processCommands: ["upower"]`; no network hosts. The shell's
`Power` facade only exposes the laptop battery, which is why peripherals need
`upower` directly (see the catalogue audit for the API wish).

## Enable

```sh
horneroctl plugin catalog install hornero-device-battery --yes
horneroctl plugin enable hornero-device-battery --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed.

## PluginKit 3

Colours, type, spacing and glyphs come from the shared Theme tokens.
