# Developing a Hornero Shell plugin (SDK)

Developer guide for authors of Hornero Shell extensions. Everything
below is the verified contract as implemented in this repository
(`schema/plugin-manifest.schema.json`, `scripts/validate_plugins.py`,
`scripts/gen_catalog.py`), in HorneroOS/shell (`docs/PLUGINS.md`,
`scripts/validate_plugin.py`, `plugin/qml/Hornero/PluginKit/*.qml` on
`main`), and in HorneroOS/hornero (`horneroctl plugin`, see
`cli/modules/hornero_cli/plugin_options.v`, `help.v`, `dispatch.v` on
`main`). Where the marketplace gate and the shell validator differ,
both are stated.

Read [CONTRIBUTING.md](CONTRIBUTING.md) for contribution workflow and
[SECURITY.md](SECURITY.md) / [SIGNING.md](SIGNING.md) for the security
and signing contracts. This document does not replace them.

## Security truth (read first)

- Plugin QML executes **in-process inside Quickshell** with the
  logged-in user's privileges. It is **not sandboxed**: filesystem,
  processes and network are reachable from QML regardless of what a
  manifest declares.
- `capabilities` declarations are **review metadata, not
  enforcement**. They support code review and the Control Center
  consent display; they are not an operating-system permission grant.
- The validators are static review aids. Passing validation is **not
  a security certification**, and the textual checks can be evaded by
  dynamic code.
- Install copies inert data only. Enable is a separate, explicit
  consent action (`--yes` on the CLI, or the Control Center consent
  dialog), re-required every time the payload changes.
- Trust tiers, from `horneroctl plugin list` (see SIGNING.md):
  `official` (maintainer-reviewed in this repo, pinned by commit +
  SHA-256 in `catalog.json`) > `signed` (author minisign signature
  verifies against the manifest's declared key and the payload hash)
  > `trusted` (local hash pin recorded with `plugin trust`) >
  `untrusted` / `stale-trust`. A failing signature reports
  `bad-signature` and cannot be enabled until fixed or removed and
  local trust is recorded. `community` entries are listed for
  discovery, unreviewed, and shown with a warning; there is no silent
  promotion between tiers.

## Package shape

One directory per plugin. In this repo: `plugins/<id>/`; the
directory name must equal the manifest `id`. A package contains:

- `manifest.json` — the manifest contract below.
- The QML `entrypoint` file.
- Exactly the files listed in manifest `files` (plus `manifest.json`
  itself). `files` must include `README.md` and `LICENSE`.

## Manifest: `schemaVersion: 1`

The contract is `schema/plugin-manifest.schema.json` in this repo
(kept in sync with HorneroOS/shell; the shell copy is canonical).
`additionalProperties: false` — unknown top-level fields are
rejected. Required fields:

| Field | Constraint (schema) |
| --- | --- |
| `schemaVersion` | Must be exactly `1` (`const: 1`; shell validator also requires an integer). |
| `id` | `^[a-z0-9][a-z0-9-]{0,47}$` (max 48 chars); must equal the directory name. |
| `name` | Non-blank string, 1–64 chars. |
| `version` | Semver `MAJOR.MINOR.PATCH[-prerelease][+build]`, max 80 chars, no leading zeros. |
| `description` | Non-blank string, 1–280 chars. |
| `author` | Non-blank string, 1–120 chars. |
| `license` | Non-blank string, 1–80 chars. |
| `entrypoint` | Safe relative path ending in `.qml`, max 240 chars: no leading `/`, no `..` segments, no `//`. The shell validator additionally requires it to be listed in `files`. |
| `files` | Array, min 3 items, unique, each a safe relative path (same rules as `entrypoint`), never `manifest.json`; must contain `README.md` and `LICENSE`. |
| `capabilities` | Object with exactly `processCommands`, `networkHosts`, `settings` (see below). |

Optional fields:

| Field | Constraint |
| --- | --- |
| `homepage` | HTTPS URI only (`^https://…`), max 500 chars. |
| `placement` | One of `background`, `bar`, `dashboard`, `desktop`; default `background`. |
| `signing` | Object with required `publicKey` (40–80 chars, base64) and `signature` (80–120 chars, base64). Optional author minisign signature over the files-only payload hash; see SIGNING.md. Absence is fine. |

`capabilities`:

- `processCommands`: unique array of exact executable basenames
  matching `^[A-Za-z0-9_.+-]+$`. Shells and privilege tools are
  forbidden values: `sh`, `bash`, `dash`, `zsh`, `fish`, `sudo`,
  `doas`, `su` (case-insensitive in the schema pattern).
- `networkHosts`: unique array of hostnames (dot-separated labels,
  each 1–63 chars, alphanumeric and internal hyphens).
- `settings`: object whose keys match `^[a-z][a-zA-Z0-9]{0,47}$`.
  Each value is an object with required `type` and `default`, and
  optional `description` (max 160 chars). `type` is one of
  `boolean`, `integer`, `number`, `string`, and `default` must match
  the declared type.

Minimal manifest (from HorneroOS/shell `docs/PLUGINS.md`):

```json
{
  "schemaVersion": 1,
  "id": "example-clock",
  "name": "Example Clock",
  "version": "1.0.0",
  "description": "A sample clock card.",
  "author": "Example Author",
  "license": "MIT",
  "entrypoint": "Main.qml",
  "files": ["Main.qml", "README.md", "LICENSE"],
  "capabilities": {
    "processCommands": [],
    "networkHosts": [],
    "settings": {}
  }
}
```

### Placements

`placement` decides where the shell renders the entrypoint. Each
plugin gets its own `Loader` in the shell, so one plugin's failure
does not take down the shell or neighbouring extensions.

| Placement | Behaviour |
| --- | --- |
| `background` | Headless; the default when `placement` is omitted. |
| `bar` | Rendered in the bar's end group. |
| `dashboard` | Rendered as a card in the dashboard Extensions tab. |
| `desktop` | Rendered as a widget on each display's background layer, in one of nine named slots per display. Slot choice is made by the user in Control Center and persisted in the user's shell config; plugin code has no setter for it. Unrecognized displays and malformed slot data fall back to `bottom-right`. |

Unknown placement values are rejected by the validator and by the
runtime host.

## PluginKit API

The shell installs the stable `Hornero.PluginKit` QML module
(`plugin/qml/Hornero/PluginKit/qmldir` in HorneroOS/shell). Import
it as:

```qml
import Hornero.PluginKit
```

Members (exact names copied from the `.qml` sources on shell
`main`): `Theme`, `Notifications`, `Desktop`, `System`, `Network`,
`Media`, `Weather`, `Time` and `Power` are singletons; `Settings`
is a regular (instantiable) type. All data facades are read-only
except `Media` transport and `Settings.setValue`; they have no
setters, no `Process` and no shell execution. They wrap the shell's
existing `qs.services` singletons, plus Quickshell's `UPower`
service for `Power`. No AI quota is exposed by PluginKit.

### `Theme` (singleton)

Read-only properties: `light` (bool); colors `primary`, `onPrimary`,
`surface`, `surfaceContainer`, `onSurface`, `onSurfaceVariant`,
`error`, `background`, `onBackground`, `surfaceDim`,
`surfaceBright`, `surfaceContainerLowest`, `surfaceContainerLow`,
`surfaceContainerHigh`, `surfaceContainerHighest`, `surfaceVariant`,
`primaryContainer`, `onPrimaryContainer`, `secondary`,
`onSecondary`, `secondaryContainer`, `onSecondaryContainer`,
`tertiary`, `onTertiary`, `tertiaryContainer`,
`onTertiaryContainer`, `errorContainer`, `onErrorContainer`,
`onError`, `outline`, `outlineVariant`, `success`;
`fontFamily`, `monoFontFamily` (string); `fontSizeSmall`, `fontSize`,
`fontSizeLarge`, `spacingSmall`, `spacing`, `spacingLarge`,
`roundingSmall`, `rounding`, `roundingLarge` (int). Token names are
the compatibility contract; the internal palette may change.

### `Notifications` (singleton)

- `toast(summary: string, body: string, icon: string): void` —
  shows a bounded in-shell toast (empty summary is a no-op; summary
  is truncated to 120 chars, body to 500, default icon
  `"extension"`). It does not create a persistent desktop
  notification.

### `Desktop` (singleton)

- `position(pluginId: string, screenName: string): string` — reads
  the current named slot for a `desktop` plugin on a screen; returns
  `"bottom-right"` when the plugin has no `desktop` placement (and
  as the host fallback described above).

### `Settings` (instantiable)

```qml
Settings {
    id: pluginSettings
    pluginId: "example-clock"
}
```

- Property: `pluginId` (string).
- `value(key: string, fallback: var): var` — returns the stored
  value if its type matches the manifest declaration for `key`,
  otherwise the declaration's `default`; returns `fallback` for an
  invalid/un-declared key.
- `setValue(key: string, value: var): bool` — writes only declared
  keys with type-matching values (strings max 4096 chars; integers
  must be integral; numbers must be finite); returns success.
- Helpers also present in the source: `validKey(key)`,
  `validValue(value, type)`.

Declarations come from `capabilities.settings` in the manifest of
the ID named by `pluginId`; user values are stored under that ID in
`$XDG_CONFIG_HOME/hornero/shell.json`. The ID is a namespace
selector, not proof of the caller's identity and not an access
boundary between extensions. Extensions cannot write the canonical
shell config through this API.

### `System` (singleton, read-only)

`cpuPerc`, `cpuTemp`, `gpuPerc`, `gpuTemp`, `memUsed`, `memTotal`,
`memPerc`, `storagePerc` (real), and `disks` (var; a copied list).

### `Network` (singleton, read-only)

`downloadSpeed`, `uploadSpeed`, `downloadTotal`, `uploadTotal`
(real).

### `Media` (singleton)

Read-only: `hasPlayer` (bool), `identity`, `title`, `artist`
(string), `isPlaying` (bool). Mutating transport calls —
`playPause()`, `previous()`, `next()` — which act only when the
active player reports it can perform them. Call them only from a
user-initiated handler; PluginKit never auto-plays.

### `Weather` (singleton, read-only)

`ready`, `locationConfigured` (bool), `temp`, `description`
(string), `humidity` (int), `windSpeed` (real), `sunrise`, `sunset`,
`lastError` (string), `forecast` (var; a copied list).

### `Time` (singleton)

Read-only: `date` (date), `hours`, `minutes`, `seconds` (int),
`timeStr` (string). Plus `format(fmt: string): string`.

### `Power` (singleton, read-only)

`hasBattery` (bool), `percentage` (int, 0–100), `charging`,
`onBattery` (bool), `stateText` (string: `charging`,
`fully-charged`, `discharging`, `pending-charge`, or empty when no
battery or state is known). This facade delegates to Quickshell's
`UPower` service (`Quickshell.Services.UPower`, via
`UPower.displayDevice` / `UPower.onBattery`) rather than a
`qs.services` singleton.

Example (from HorneroOS/shell `examples/plugins/example-clock/`):

```qml
import QtQuick
import Hornero.PluginKit

Item {
    Settings {
        id: pluginSettings
        pluginId: "example-clock"
    }

    Text {
        text: Qt.formatDateTime(new Date(), pluginSettings.value("twentyFourHour", true) ? "ddd, HH:mm" : "ddd, h:mm ap")
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifications.toast("Example Clock", "This example uses the public PluginKit API.", "schedule")
    }
}
```

## Allowed imports and validator rules

### Allowed imports (shell validator)

The shell validator (`scripts/validate_plugin.py` in
HorneroOS/shell) scans every `.qml` file in the package and rejects
any import not in this exact list:

- `QtQuick`
- `QtQuick.Controls`
- `QtQuick.Layouts`
- `QtQml`
- `Quickshell`
- `Quickshell.Io`
- `Hornero.PluginKit`

Imports of Hornero's internal implementation and unknown PluginKit
submodules are rejected. (The starter template uses only `QtQuick`;
CONTRIBUTING.md asks you to keep imports minimal so a plugin also
loads in a stock Quickshell. Note the marketplace validator in this
repo does not itself check imports — the shell validator does.)

### Marketplace gate: `scripts/validate_plugins.py` (this repo)

Run from the repo root; it validates every directory under
`plugins/` and `community/` (community submissions pass the same
gate but are never catalogued). It checks:

- `manifest.json` parses; all required fields present;
  `schemaVersion` is `1`; `id` matches the pattern above; directory
  name equals `id`; `version` is semver.
- `files` includes `README.md` and `LICENSE`; every listed file
  exists; the files on disk are exactly `files` + `manifest.json`
  (payload drift fails).
- No symlinks, no executable bits, no binary suffixes
  (`.so`, `.o`, `.a`, `.bin`, `.exe`, `.dll`, `.pyc`).
- The `entrypoint` file exists.

### Shell validator: `scripts/validate_plugin.py <dir>` (HorneroOS/shell)

Stricter, and also run by `horneroctl plugin validate` and again at
enable time. In addition to the manifest rules above (including
unknown-field and duplicate-key rejection, the homepage check, and
settings type/default checks), it rejects:

- Unsafe paths (absolute, `..`, backslash, NUL), an `entrypoint`
  not listed in `files`, or `files` not exactly matching the
  package contents.
- Symlinks; setuid/setgid, executable or world-writable files;
  compiled/bytecode suffixes (`.so`, `.dll`, `.dylib`, `.exe`,
  `.pyc`).
- Disallowed imports (list above).
- Forbidden source markers: `sudo`/`doas`/`pkexec`, `su -`,
  `<shell> -c` for the forbidden shells, `.ssh` paths, `/etc` paths,
  `HOME`/`XDG_CONFIG_HOME` path joins.
- `Process {}` usage that is not a literal argv array
  (`command: ["exe", …]`), or whose executable basename is
  undeclared in `processCommands` or is a forbidden shell/privilege
  tool.
- Network API use (`XMLHttpRequest`, `WebSocket`, `NetworkRequest`,
  `TcpSocket`) with no declared `networkHosts`, and any literal
  `http(s)://` URL whose hostname is not declared in
  `networkHosts`.

These textual checks can be evaded by dynamic code; treat them as a
review aid, never as a sandbox.

## Lifecycle with `horneroctl plugin`

Verified against `plugin_options.v`, `help.v` and `dispatch.v` in
HorneroOS/hornero on `main`. Subcommands:
`new`, `install`, `install-local`, `remove`, `list`, `validate`,
`enable`, `disable`, `trust`, `catalog`, `community`.

General rules: mutation commands (`new`, `install`,
`install-local`, `remove`, `enable`, `disable`, and the catalog
mutations) require `--yes` to mutate; `--dry-run` never creates
files or clones and never loads QML. `list` and `validate` are
read-only and take no mutation flags. Installed packages are stored
below XDG data with ownership receipts under XDG state; plugins are
disabled by default when installed, and installation does not load
QML.

```sh
# Scaffold a new plugin (static MIT template).
# Requires --name, --author, --description, --license and --dir,
# and exactly one of --dry-run / --yes. --license currently only
# accepts MIT; other licenses are created manually.
horneroctl plugin new example-clock --name "Example Clock" \
  --author "Your Name" --description "A clock widget" \
  --license MIT --dir ./example-clock --dry-run

# Static contract validation of a package directory (read-only).
horneroctl plugin validate ./example-clock

# Install from a public git URL (HTTPS) — inert data only.
horneroctl plugin install https://github.com/example/my-plugin.git --dry-run
horneroctl plugin install https://github.com/example/my-plugin.git --yes

# Install from a local directory (no network; symlinked path
# components/entries and any .git are refused; the receipt revision
# is the payload SHA-256).
horneroctl plugin install-local ./example-clock --dry-run
horneroctl plugin install-local ./example-clock --yes

# List receipt-owned installed packages.
horneroctl plugin list
horneroctl plugin list --json

# Record explicit trust for the current payload hash of a
# non-official installed plugin. Never enables; any payload change
# invalidates it. Non-official plugins need recorded trust before
# they can be enabled (official-catalogue installs carry reviewed
# provenance instead).
horneroctl plugin trust example-clock --yes

# Enable / disable. Enable re-validates the installed payload
# first; on failure the plugin stays disabled.
horneroctl plugin enable example-clock --yes
horneroctl plugin disable example-clock --yes

# Remove only a package owned by a Hornero receipt.
horneroctl plugin remove example-clock --yes

# Official catalogue (this repository).
horneroctl plugin catalog [--json]
horneroctl plugin catalog install hornero-pomodoro [--revision <catalogue-commit>] [--dry-run|--yes]
horneroctl plugin catalog update <id> [--revision <catalogue-commit>] [--dry-run|--yes]
horneroctl plugin catalog rollback <id> [--dry-run|--yes]

# Signed community registry (read-only listing only).
horneroctl plugin community list [--json]
```

Notes:

- `--revision` is valid only with `catalog install` / `catalog
  update`, and pins the catalogue commit.
- Catalog install verifies the payload SHA-256 against
  `catalog.json` and the pinned revision before copying; update
  keeps the previous payload, and `catalog rollback` restores it.
- `plugin community list` fetches this repository, verifies the
  detached minisign signature against `/etc/hornero/registry.pub`,
  and fails closed when the key, signature, index or `minisign` is
  unavailable — there is no unsigned fallback. A registry signature
  proves publication by that registry, not code review or safety.
  (In the shell, the community pane is display-only; see shell
  `docs/PLUGINS.md`.)
- Inspect a running shell with `qs ipc call plugins status` and
  rediscover with `qs ipc call plugins reload`.

## Starting from the starter template

This repo ships `templates/starter-plugin/` (`Main.qml`,
`manifest.json`, `README.md`, MIT `LICENSE`): a `bar`-placement
label showing `HH:mm`, updated every 30 seconds, using only
`import QtQuick`.

```sh
cp -r templates/starter-plugin plugins/<your-id>
# rename: set manifest "id" to <your-id> (must equal the directory
# name), edit name/version/description/author, then write Main.qml
python3 scripts/validate_plugins.py
python3 scripts/gen_catalog.py   # see the two-commit flow below
```

The entrypoint root is a plain `QtQuick` `Item`; give it
`implicitWidth`/`implicitHeight` for visible placements (the
starter and the pomodoro in `plugins/hornero-pomodoro/` both do).
Alternatively scaffold outside this repo with
`horneroctl plugin new … --yes` (above).

Before opening a PR, exercise the package on a real shell:

```sh
horneroctl plugin validate ./plugins/<your-id>
horneroctl plugin catalog install <your-id> --yes   # after merge
qs ipc call plugins status
```

## Regenerating `catalog.json`: the two-commit flow

`catalog.json` is generated by `scripts/gen_catalog.py`; never edit
it by hand. It records, per plugin: identity, `placement`,
capability disclosure, `trust: "official"`, `path`, a pinned git
revision (`generatedFrom`: the last commit that touched `plugins/`)
and a SHA-256 over the payload (`manifest.json` + every file in
`files`, in sorted order, framed as `name NUL bytes NUL`).

Because `generatedFrom` is the last `plugins/` commit, the workflow
is two separate commits:

1. Commit the plugin sources first.
2. Then run `python3 scripts/gen_catalog.py` and commit
   `catalog.json` on its own. Never mix the two commits.

CI re-runs the validator and `gen_catalog.py --check`, which fails
if `catalog.json` is stale.
