# Hornero Port Watch

A dashboard card and desktop widget answering "what is on :3000?" (PluginKit 3,
`schemaVersion: 3`).

## What it shows (real data only)

One `ss -H -tulnp` run per refresh. Rows merge IPv4 and IPv6 for the same
protocol and port and show:

- the port, protocol, and how far the bind reaches: **this machine** (loopback),
  **LAN** (one interface), or **exposed** (all interfaces) (the one worth a second look);
- the owning process name and pid *when the kernel exposes them to your user*.
  Sockets owned by another account have no process information for an
  unprivileged user, so the row says so instead of guessing;
- **watched ports**: ports you list stay on the board as "free" when nothing
  listens.

It only reads the socket table. It cannot open, close or kill anything, and
makes no network connection. Reading pauses in the Gaming experience.

## Settings

`protocols` (`tcp` default, `udp`, `both`), `scope` (`all`, `exposed`, `local`),
`watchedPorts` (comma/space separated, up to 12), `maxRows` (3-30),
`refreshSeconds` (2-120), `showProcess`.

## Permissions

`capabilities.processCommands: ["ss"]`; no network hosts, no providers.

## Enable

```sh
horneroctl plugin catalog install hornero-port-watch --yes
horneroctl plugin enable hornero-port-watch --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed.

## PluginKit 3

Colours, type, spacing and glyphs come from the shared Theme tokens.
