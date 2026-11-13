# Hornero AI Usage

AI Usage 2.0 (manifest v2): one package, two surfaces over the
normalized `horneroctl agent usage --json` records (hornero#407).

- **Dashboard** (`"placement": "dashboard"`, primary): one block per
  provider — status, freshness, total/input/output tokens, sessions,
  API calls, per-model breakdown, measured period, balance when the
  provider records one, and quota usage/reset only when the
  provider's own record carries an official quota snapshot.
- **Bar** (`surfaces.bar`): a compact self-hiding indicator (it
  takes no bar space until at least one provider reports usage)
  opening a popover with a provider switcher and per-provider
  detail.

Both surfaces share `UsageData.qml`, refresh on the typed
`refreshSeconds` setting (integer, 15–3600, default 60 — the same
cadence the 1.x card hardcoded), and render with PluginKit `Ui*`
primitives, host context (`hostOrientation`/`hostCompact` via
`UiStack`), accessible names, host-owned tooltips, Theme tokens and
English source strings with an Argentine Spanish catalog
(`translations/es.json`, via PluginKit `Translations`).

## Honest limits

- **Normalized records only.** QML never parses a provider's raw
  store and never reads credentials; the `horneroctl` collectors own
  provider specifics. There is no cost field in the contract, so no
  costs are shown.
- **Quota is usually unknown.** It is displayed only when a
  provider's own record carries an official quota (today: a Codex
  rollout's latest `rate_limits`); otherwise the UI says so instead
  of inventing a limit, a reset clock arithmetic, or a percentage.
  The reset shown is the timestamp the provider recorded.
- **Providers degrade independently.** A missing or failed collector
  is labelled unavailable/error with its reason, beside the healthy
  providers; no-data is never zero usage, and a total CLI failure
  shows an error state instead of fabricated zeros.
- **No trends yet.** The normalized contract reports period
  aggregates, not a time series, so this package shows the measured
  period rather than inventing trend data.

## Compatibility

- A `horneroctl` too old for `agent usage` falls back to the pre-2.0
  `horneroctl assistant usage --json` aggregate, mapped to a single
  `javi-hermes` record (`source: assistant-usage-legacy`), so older
  installs keep working with their previous numbers.
- The plugin declared no settings before 2.0, so no stored values
  migrate; `refreshSeconds` starts at the previous hardcoded 60 s.
- Installing this manifest v2 package needs a shell/`horneroctl`
  that accepts `schemaVersion` 2 and the `translations`
  declaration.

Original HorneroOS code, MIT licensed. Plugin QML runs with your
user privileges inside Quickshell; it is not sandboxed.
