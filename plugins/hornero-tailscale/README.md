# Hornero Tailscale

Tailscale VPN status pill and dashboard card for Hornero Shell (PluginKit 3,
`schemaVersion: 3`).

## What it shows

- Connection state (`Connected`, `Stopped`, `Needs login`, `Offline`)
- Tailnet name and this device's Tailscale IPv4 address
- Active exit node (when routed through one)
- Online peers count and peer list in the dashboard card
- One-click `Connect` / `Disconnect` toggle (`tailscale up` / `tailscale down`)

Status checks pause automatically in the Gaming experience.

## Settings

`refreshSeconds` (5-300), `showPeers`, `maxPeers` (1-20).

## Permissions

`capabilities.processCommands: ["tailscale"]`; no network hosts.

## Enable

```sh
horneroctl plugin catalog install hornero-tailscale --yes
horneroctl plugin enable hornero-tailscale --yes
```

Plugin QML runs with your user privileges inside Quickshell; it is not
sandboxed. Original HorneroOS code, MIT licensed.
