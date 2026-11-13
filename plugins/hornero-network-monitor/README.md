# Hornero Network Monitor

Network Monitor 2.0 (manifest v2): a dashboard card over the
shared PluginKit `Network` facade (`downloadSpeed`,
`uploadSpeed`, `downloadTotal`, `uploadTotal`; holding a
`Subscription { domain: "network" }` lease). The 1.x current
speeds and session totals are unchanged and keep their
B/KiB/MiB/GiB/TiB formatting. 2.0 adds an in-card session
history — speed samples taken while the card is loaded, drawn
as a download sparkline with download/upload peak readouts —
and a reporting/unavailable health chip.

The facade exposes aggregate speeds and totals only: no
interface list, addresses, link state or per-process traffic,
so none of that is shown. History covers only the time since
this card instance loaded, is capped at 30 samples, is never
persisted, and is labelled as such. Sampling reads the
already-live shared singleton; the shared `network` polling
timer exists once per shell however many extensions subscribe.

## Compatibility

- The plugin declared no settings before 2.0, so no stored
  values migrate. New typed settings default to the 1.x visible
  behaviour: `showSessionTotals` (boolean, default `true`),
  plus additive `showHistory` (boolean, default `true`) and
  `sampleSeconds` (integer 1–60, default `5`).
- Installing this manifest v2 package needs a shell /
  `horneroctl` that accepts `schemaVersion` 2, the dashboard
  surface hints, the `translations` declaration and the
  `marketplace` block.

## The 8 Hornero quality questions

1. **Unique value.** Retained speed history and peaks since the card loaded, next to the shell-session totals — evidence of what the connection actually did, not just what it is doing this second.
2. **Native overlap.** System Health shows the same instantaneous speeds as one health row, and the native shell shows current rates. This card's distinct value is the history/peaks and session totals in one place.
3. **Why an extension.** Keeping a local sample history is opt-in, per-user presentation over the shared facade; the native shell stays a current-rate display for everyone else.
4. **Surfaces.** One dashboard surface (`"placement": "dashboard"`, redeclared in `surfaces.dashboard` with `size: "standard"`, `category: "System"`).
5. **Actions.** No `horneroctl` broker actions and no network access of its own. One in-card button, "Clear history", forgets samples collected since the card loaded.
6. **Configuration.** Typed settings listed under Compatibility, read via PluginKit `Settings`.
7. **Missing-data behaviour.** When the service reports no usable speeds, the chip reads `Unavailable`, an empty state explains the connection may be down or starting, and totals stay as last reported instead of resetting to a fabricated zero history. Before two samples exist, history is a labelled collecting state.
8. **Disable behaviour.** Disabling the extension destroys the card, releases its `network` Subscription lease and discards the in-card history. The shell's own session totals are unaffected.

No processes and no network access of its own. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
