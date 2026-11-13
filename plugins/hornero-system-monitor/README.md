# Hornero System Monitor

System Monitor 2.0 (manifest v2): a dashboard card over the
shared PluginKit `System` facade (`cpuPerc`, `cpuTemp`,
`gpuPerc`, `gpuTemp`, `memPerc`, `storagePerc`; the card holds a
`Subscription { domain: "system" }` lease). The 1.x CPU /
memory / GPU / storage bars and temperature readouts are
unchanged. 2.0 adds what a one-shot percentage cannot tell you:
an in-card session history — samples of the facade values taken
while the card is loaded, drawn as a sparkline with CPU/memory
peak and CPU average readouts — and a high-load alert chip when
a row crosses the user's threshold.

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

- The plugin declared no settings before 2.0, so no stored
  values migrate. New typed settings default to the 1.x visible
  behaviour: `showTemperatures` (boolean, default `true`),
  plus additive `showHistory` (boolean, default `true`),
  `warnPercent` (integer 50–100, default `90`) and
  `sampleSeconds` (integer 1–60, default `5`).
- Installing this manifest v2 package needs a shell /
  `horneroctl` that accepts `schemaVersion` 2, the dashboard
  surface hints, the `translations` declaration and the
  `marketplace` block.

## The 8 Hornero quality questions

1. **Unique value.** Session history (sparkline, peaks, average) and a threshold alert over live CPU/GPU/memory/storage usage, so a transient spike stays visible after it passes.
2. **Native overlap.** The shell's native Performance view already presents the same instantaneous percentages. This card deliberately does not try to replace it; its distinct value is the retained in-card history and alert that the native view does not keep for extensions.
3. **Why an extension.** History retention and alert thresholds are user-tunable, opt-in presentation over the shared facade; keeping them in a removable extension avoids growing the native Performance view for everyone.
4. **Surfaces.** One dashboard surface (`"placement": "dashboard"`, redeclared in `surfaces.dashboard` with `size: "standard"`, `category: "System"` so the System Insight cards group together). No bar surface: the native bar already carries resource indicators.
5. **Actions.** No `horneroctl` broker actions and no processes. One in-card button, "Clear history", forgets the samples collected since the card loaded; it runs only on click and touches nothing outside the card.
6. **Configuration.** Typed settings listed under Compatibility, read via PluginKit `Settings`. No other configuration.
7. **Missing-data behaviour.** A facade value that is missing or not a finite number reads `Unavailable` (and its bar sits at zero) instead of a fabricated percentage; before two samples exist the history area is a labelled collecting state. Facade zeros before the first shared sample are shown as reported.
8. **Disable behaviour.** Disabling the extension destroys the card, which releases its `system` Subscription lease and discards the in-card history. Nothing is written while disabled.

No processes and no network access of its own. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
