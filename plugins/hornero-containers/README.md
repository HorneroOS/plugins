# Hornero Containers

A read-only container roster for Podman and Docker, as a dashboard card and a
desktop widget (PluginKit 3, `schemaVersion: 3`).

## What it shows (real data only)

`podman ps --all --format json` and/or `docker ps --all --format '{{json .}}'`,
normalised to name, image, state (running, paused, restarting, exited, dead),
status text ("Up 2 hours") and published ports. Running containers sort first.
If no runtime answers (not installed, service stopped, socket not reachable)
the card shows an error state; it never shows an empty list as if all were
well.

It never starts, stops, restarts, removes, builds or pulls anything and makes
no network request itself. Querying pauses in the Gaming experience.

Note: reaching the Docker socket is itself a privileged capability on most
systems. This card only reads, but rootless Podman is the safer default.

## Settings

`runtime` (`auto` tries Podman then Docker; `podman`; `docker`; `both`),
`showStopped`, `showPorts`, `maxRows` (3-20), `refreshSeconds` (5-300).

## Permissions

`capabilities.processCommands: ["podman", "docker"]`; no network hosts.

## Enable

```sh
horneroctl plugin catalog install hornero-containers --yes
horneroctl plugin enable hornero-containers --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed.

## PluginKit 3

Colours, type, spacing and glyphs come from the shared Theme tokens.
