# Hornero AI Usage — Agent Deck

Agent Deck 4.0 (PluginKit 5): every coding-agent subscription this
machine is already signed into, in one native Hornero Signal place —
real quota windows with resets, plans, and token activity over the
normalized `horneroctl agent usage --json` schema-v2 records
(hornero#407). No provider registration: enable the extension and
discovered agents appear on their own.

- **Agents page** (`contributes.dashboardTabs`, `Agents.qml`): a
  top-level Dashboard tab next to Media/Performance (contributed
  through PluginKit 5, not hardcoded in the shell; it disappears when
  the extension is disabled). One instrument module per subscription:
  every reported window (5-hour, weekly, monthly, model-scoped,
  on-demand) as its own meter with percent remaining and a reset
  countdown, plan/billing chips, and token activity. Modules are
  ordered tightest verified quota first.
- **Bar** (`surfaces.bar`): a compact self-hiding indicator showing
  the tightest verified quota percent (never an average, never a
  summed token total), opening a quick popover with every account,
  a provider switcher, manual refresh, and **Open Agents**.
- **Dashboard card** (`"placement": "dashboard"`): the compact
  per-provider blocks in Dashboard › Extensions, as before.

All surfaces share `UsageData.qml`; `horneroctl` caches one
collection for every surface, so their timers never duplicate
provider traffic. Settings (Control Center › Extensions):
`refreshSeconds` (30–3600, default 180) and `warningPercent`
(50–99, default 80). Reset countdowns tick locally. English source
strings with an Argentine Spanish catalog.

## Honest limits

- **Normalized records only.** QML never parses a provider store,
  never reads credentials, and holds no network capability
  (`networkHosts: []`). Quota probing lives in `horneroctl` alone:
  first-party `muse usage --json`, Codex's recorded rollout windows,
  and — credential scope B — Anthropic's and Cursor's authenticated
  usage endpoints using the stored sign-in read-only in memory.
  Tokens are never seen, printed, or stored by this extension.
- **Unknown stays unknown.** A window is drawn only when the
  provider itself reported it; unsupported quotas are labelled
  unknown (never 0%), stale data is marked stale with its real fetch
  time, and account-wide figures (Cursor) are never added to this
  machine's activity. There is no cost field, so no costs are shown.
- **Providers degrade independently.** A missing, signed-out, or
  rate-limited provider is labelled with its reason beside the
  healthy ones; a failed refresh keeps last-known-good data and
  backs off.
- **No fake history.** The contract reports current windows and
  period aggregates, not a time series, so there are no trend charts.

## Compatibility

- Needs a PluginKit 5 shell (`pluginKit: 5`); older shells refuse the
  package plainly instead of loading it without its Agents page.
- A `horneroctl` with schema-v1 records still works (single legacy
  quota window); one too old for `agent usage` falls back to the
  pre-2.0 `assistant usage` aggregate as a single `javi-hermes`
  record.
- `refreshSeconds` default moved 60 → 180 s (quota endpoints
  rate-limit readily; the backend cache makes reads cheap either way).

Original HorneroOS code, MIT licensed. Plugin QML runs with your
user privileges inside Quickshell; it is not sandboxed.
