# Hornero Network Monitor

Network Monitor 3.0 (manifest v3, PluginKit 3 on Hornero Signal): a dashboard card over the
shared PluginKit `Network` facade (`downloadSpeed`,
`uploadSpeed`, `downloadTotal`, `uploadTotal`; holding a
`Subscription { domain: "network" }` lease). The 1.x current
speeds and session totals keep their B/KiB/MiB/GiB/TiB
formatting. 3.0 draws the history as Hornero Signal instruments:
a `cue`-toned download oscilloscope from the shared `Telemetry`
history (scale stated in the eyebrow, previous window as
persistence), an upload trace and download/upload peak readouts,
plus a reporting/unavailable context label.

The facade exposes aggregate speeds and totals only: no
interface list, addresses, link state or per-process traffic,
so none of that is shown. History is the shared Telemetry window (120 samples,
not persisted). Sampling reads the
already-live shared singleton; the shared `network` polling
timer exists once per shell however many extensions subscribe.

## Compatibility

- Typed settings: `showSessionTotals` (boolean, default `true`)
  and `showHistory` (boolean, default `true`: oscilloscope, upload
  trace and peaks). 3.0 removes `sampleSeconds`: history is the
  shared 120-sample `Telemetry` window, so a stored value is ignored.
- Installing this package needs a shell with PluginKit 3 (Hornero Signal): it declares
  `schemaVersion: 3` and `capabilities.providers`, and earlier shells refuse or cannot render it.

## The 8 Hornero quality questions

1. **Unique value.** Retained speed history and peaks since the card loaded, next to the shell-session totals — evidence of what the connection actually did, not just what it is doing this second.
2. **Native overlap.** System Health shows the same instantaneous speeds as one health row, and the native shell shows current rates. This card's distinct value is the history/peaks and session totals in one place.
3. **Why an extension.** Keeping a local sample history is opt-in, per-user presentation over the shared facade; the native shell stays a current-rate display for everyone else.
4. **Surfaces.** One dashboard surface (`"placement": "dashboard"`, redeclared in `surfaces.dashboard` with `size: "standard"`, `category: "System"`).
5. **Actions.** No `horneroctl` broker actions and no network access of its own. No controls: the card is read-only.
6. **Configuration.** Typed settings listed under Compatibility, read via PluginKit `Settings`.
7. **Missing-data behaviour.** When the service reports no usable speeds, the chip reads `Unavailable`, an empty state explains the connection may be down or starting, and totals stay as last reported instead of resetting to a fabricated zero history. Before two shared samples exist, the oscilloscope shows its labelled collecting state.
8. **Disable behaviour.** Disabling the extension destroys the card, releases its `network` Subscription lease and stops reading the shared history. The shell's own session totals are unaffected.

No processes and no network access of its own. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
