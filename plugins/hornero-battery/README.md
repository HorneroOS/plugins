# Hornero Battery

Battery 3.0 (manifest v3, PluginKit 3 on Hornero Signal, HorneroOS/plugins#31): one package, two
surfaces over the shared PluginKit `Power` facade (`hasBattery`,
`percentage`, `charging`, `onBattery`, `stateText`; event-pushed
by UPower through a `Subscription { domain: "power" }` lease,
never polled by this package).

- **Bar** (`"placement": "bar"`, primary): a compact indicator —
  state glyph plus, on roomy horizontal bars, the 1.x label
  (`85% ⚡ Charging`). Activating it opens a host-owned
  `UiPopover` with charge, state, on-battery/charging flags and a
  low-battery chip.
- **Dashboard** (`surfaces.dashboard`, `size: "compact"`,
  `category: "System"`): the same state as a card; it always
  renders when the user opens the dashboard.

## Contextual visibility (issue #31)

1.x always showed a permanent "No battery" bar item on desktops.
2.0 takes **no bar space** when `Power.hasBattery` is false
unless the user opts in with the typed `showWhenNoBattery`
setting (default `false`; turning it on restores the permanent
1.x item). The dashboard card is unaffected: it shows an explicit
empty state when opened.

## Honest limits (PluginKit Power surface)

Verified against shell `docs/PLUGINS.md` and
`plugin/qml/Hornero/PluginKit/Power.qml` (PluginKit 3). Since
Hornero Signal the facade also exposes time to empty / full, the
energy rate, battery health and the power profile; 3.0 shows each
only when UPower reports it (an em dash otherwise) and invents
nothing else:

- **No capacity or cycle-count member** exists; none is shown.
- **No ready/valid or AC-online member**: `percentage` reads `0`
  when no battery is present (indistinguishable from a real 0%),
  `charging` is also true when fully charged (the detail states
  are carried by `stateText`), and "not on battery" is only ever
  reported as `onBattery == false`, never as a proven AC claim.
- `hasBattery == false` also covers UPower reporting no laptop
  battery for any reason; the UI says "no battery is reported",
  not that the machine is proven to be a desktop.
- Unknown `stateText` values (outside `charging`,
  `fully-charged`, `discharging`, `pending-charge` and empty)
  read as "Unknown" rather than being passed through or guessed.

Session/power actions (lock, suspend, shutdown) are native
shell-owned flows; PluginKit exposes no session facade to
extensions and this package adds no fake controls for them.

## Compatibility

- No settings existed before 2.0, so no stored values migrate.
  `showPercentage`/`showStateText` (boolean, default `true`)
  reproduce the 1.x label and `lowBatteryPercent` (integer,
  default `20`) only adds a chip. The one intentional default
  change is `showWhenNoBattery` (`false`), the issue #31
  acceptance behaviour above.
- Installing this package needs a shell with PluginKit 3 (Hornero Signal): it declares
  `schemaVersion: 3` and `capabilities.providers`, and earlier shells refuse or cannot render it.

Both surfaces use PluginKit `Ui*` primitives, host context,
host-owned tooltip/popover, accessible names, Theme tokens and
an Argentine Spanish catalog (`translations/es.json`). No
processes and no network. Original HorneroOS code, MIT licensed.
Plugin QML runs with your user privileges inside Quickshell; it
is not sandboxed.
