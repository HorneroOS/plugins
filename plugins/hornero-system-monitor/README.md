# Hornero System Monitor

System Monitor 3.0 (manifest v3, PluginKit 3 on Hornero Signal): a dashboard card over the
shared PluginKit `System` facade (`cpuPerc`, `cpuTemp`,
`gpuPerc`, `gpuTemp`, `memPerc`, `storagePerc`; the card holds a
`Subscription { domain: "system" }` lease). The 1.x CPU /
memory / GPU / storage bars and temperature readouts are
unchanged in meaning. 3.0 redraws them as Hornero Signal
instruments: a CPU oscilloscope from the shared `Telemetry`
history (real samples, the previous window as persistence),
segmented meter rows that cross to `signal` at the user's
threshold, and CPU/memory peak and CPU average readouts over the
same window.

History is deliberately modest and honest: it covers only the
time since this card instance loaded, is capped at 30 samples,
is never persisted, and is labelled as such in the card.
Sampling reads the already-live shared singleton on the sample
tick; the shared `system` polling timer exists once per shell
however many extensions subscribe (shell `docs/PLUGINS.md`,
shared providers). PluginKit exposes no per-process or per-core
data to extensions, so no process diagnostics are shown or
implied; pair the peak/average readouts with the shell's own
tools for that.

## Compatibility

- Typed settings: `showTemperatures` (boolean, default `true`),
  `showHistory` (boolean, default `true`: the oscilloscope and
  peak/average readouts) and `warnPercent` (integer 50–100,
  default `90`). 3.0 removes `sampleSeconds`: history is the
  shared 120-sample `Telemetry` window, sampled by the shell at
  the experience cadence, so a stored `sampleSeconds` is ignored.
- Installing this package needs a shell with PluginKit 3 (Hornero Signal): it declares
  `schemaVersion: 3` and `capabilities.providers`, and earlier shells refuse or cannot render it.

## The 8 Hornero quality questions

1. **Unique value.** A CPU oscilloscope with peak/average readouts and a threshold crossing over live CPU/GPU/memory/storage usage, so a transient spike stays visible after it passes.
2. **Native overlap.** The shell's native Performance view already presents the same instantaneous percentages. This card deliberately does not try to replace it; its distinct value is the retained in-card history and alert that the native view does not keep for extensions.
3. **Why an extension.** History retention and alert thresholds are user-tunable, opt-in presentation over the shared facade; keeping them in a removable extension avoids growing the native Performance view for everyone.
4. **Surfaces.** One dashboard surface (`"placement": "dashboard"`, redeclared in `surfaces.dashboard` with `size: "standard"`, `category: "System"` so the System Insight cards group together). No bar surface: the native bar already carries resource indicators.
5. **Actions.** No `horneroctl` broker actions and no processes. No controls: the card is read-only.
6. **Configuration.** Typed settings listed under Compatibility, read via PluginKit `Settings`. No other configuration.
7. **Missing-data behaviour.** A facade value that is missing or not a finite number reads `Unavailable` (and its bar sits at zero) instead of a fabricated percentage; before two shared samples exist the oscilloscope shows its labelled collecting state. Facade zeros before the first shared sample are shown as reported.
8. **Disable behaviour.** Disabling the extension destroys the card, which releases its `system` Subscription lease and stops this card's reads of the shared history. Nothing is written while disabled.

No processes and no network access of its own. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
