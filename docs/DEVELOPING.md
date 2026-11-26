# Developing a Hornero Shell Plugin (SDK)

Developer guide for authors of Hornero Shell extensions targeting
**`schemaVersion: 3`** and **PluginKit 3–6** (Hornero Signal). Everything below
reflects the verified contract in `schema/plugin-manifest.schema.json`,
`scripts/validate_plugins.py`, `scripts/gen_catalog.py`, HorneroOS/shell
(`docs/PLUGINS.md`, `scripts/validate_plugin.py`,
`plugin/qml/Hornero/PluginKit/*.qml`), and HorneroOS/hornero (`horneroctl plugin`).

Read [CONTRIBUTING.md](CONTRIBUTING.md) for contribution workflow,
[SECURITY.md](SECURITY.md) for the security model, and
[SIGNING.md](SIGNING.md) for package signing and trust tiers.

## Security truth (read first)

- Plugin QML executes **in-process inside Quickshell** with the logged-in user's
  privileges. It is **not sandboxed**.
- `capabilities` declarations are **review metadata, not enforcement**. They
  support code review and the Control Center consent display.
- Static validators (`scripts/validate_plugins.py` and the shell validator) are
  review aids, not a security certification.
- Install copies inert data only. Enable is a separate explicit consent action
  (`--yes` on the CLI, or the Control Center consent dialog), re-required on
  every payload change.

## Package shape

One directory per plugin under `plugins/<id>/`; the directory name must equal
the manifest `id`:

- `manifest.json` — `schemaVersion: 3` manifest.
- The QML `entrypoint` file (and any surface entrypoints / helper `.qml` or `.js` files).
- `README.md` and `LICENSE` (required in `files`).
- Optional `translations/<locale>.json` catalogs (required when `translations` is declared).

No symlinks, executable bits, or binary suffixes (`.so`, `.o`, `.a`, `.bin`,
`.exe`, `.dll`, `.pyc`) are allowed, and the files on disk must match
`files` + `manifest.json` exactly.

## Manifest (`schemaVersion: 3`, PluginKit 3–6)

`schemaVersion: 1` and `2` are retired and rejected by the validator. New
extensions must declare `"schemaVersion": 3` and `"pluginKit": 3` (or `4`, `5`,
`6` when using higher-level features):

- **PluginKit 3** (baseline): Signal `Theme.palette.*` tokens, Hornero Glyphs,
  `capabilities.providers`, `surfaces` (`bar`, `dashboard`, `desktop`,
  `background`), JSON `translations`, typed v3 settings (`boolean`, `integer`,
  `number`, `string`, `enum`).
- **PluginKit 4**: `contributes` (`commands`, `quickSettings`, `panels`),
  `surfaces.desktop.instances: true`, and v4 settings (`colour`, `list`,
  `text`, `path`, `strings`, plus `title`, `group`, `unit`, `step`,
  `visibleWhen`, `hidden`).
- **PluginKit 5**: `surfaces.dashboardTab` and `contributes.dashboardTabs`.
- **PluginKit 6**: `dataOnly: true` packages with `contributes.companions` and
  `contributes.companionAddons`.

Minimal `schemaVersion: 3` manifest:

```json
{
  "schemaVersion": 3,
  "pluginKit": 3,
  "id": "example-clock",
  "name": "Example Clock",
  "version": "1.0.0",
  "description": "A sample clock indicator.",
  "author": "Example Author",
  "license": "MIT",
  "entrypoint": "Main.qml",
  "placement": "bar",
  "translations": {
    "sourceLocale": "en",
    "locales": ["es"],
    "directory": "translations"
  },
  "files": ["Main.qml", "README.md", "LICENSE", "translations/es.json"],
  "capabilities": {
    "processCommands": [],
    "networkHosts": [],
    "providers": ["time"],
    "settings": {}
  }
}
```

## Hornero Signal (`Theme.palette.*`) & Hornero Glyphs

Material-era tokens (`Theme.primary`, `Theme.onSurface`, `Theme.fontSize`,
`iconName`, `fill: 1`, etc.) were removed in PluginKit 3 and are rejected by
the validator:

- **Palette roles**: `Theme.palette.ground`, `sunken`, `base`, `panel`,
  `raised`, `lifted`, `ink`, `inkMuted`, `inkFaint`, `rule`, `ruleStrong`,
  `focus`, `signal`, `onSignal`, `signalWell`, `onSignalWell`, `cue`, `onCue`,
  `phosphor`, `onPhosphor`, `alert`, `onAlert`, etc.
- **Typography & spacing**: `Theme.font.family.sans`, `Theme.font.family.mono`,
  `Theme.font.size.{small,smaller,normal,larger,large,extraLarge}`,
  `Theme.spacing.{small,smaller,normal,larger,large}`,
  `Theme.padding.*`, `Theme.rounding.*`, `Theme.duration(name)`.
- **Icons**: Use Hornero Glyph kebab-case names listed in
  `schema/hornero-glyphs.names` via `UiIcon { name: "clock" }` or
  `glyph: "clock"` on `UiButton`, `UiCard`, `UiChip`, `UiDetailRow`, and
  `UiActionRow`. Do not use raw emoji for chrome icons.

## Translations (JSON catalogs, not `qsTr()`)

The shell installs no `QTranslator` for extension catalogs, so `qsTr()` and
`qsTrId()` are rejected by the validator. Instead:

1. Declare `"translations": { "sourceLocale": "en", "locales": ["es"], "directory": "translations" }`
   in `manifest.json` and include `translations/es.json` in `files`.
2. Instantiate `Translations { id: i18n; pluginId: "<your-id>" }` in QML and
   wrap visible strings with `i18n.tr("...")` (preserving `%1`/`%2` placeholders).

## Allowed imports & static security rules

`scripts/validate_plugins.py` scans every `.qml`, `.js`, and `.mjs` file in the
package and enforces:

- **Allowed QML imports**: `QtQuick`, `QtQuick.Controls`, `QtQuick.Layouts`,
  `QtQml`, `Quickshell`, `Quickshell.Io`, `Hornero.PluginKit`.
- **Forbidden dynamic execution**: `Quickshell.execDetached`,
  `Qt.createQmlObject`, `Qt.createComponent`, `eval(`, and `Function(`.
- **Process commands**: `Process {}` must use a double-quoted literal `command: ["exe", ...]`
  array whose basename is declared in `capabilities.processCommands`. Shells,
  privilege escalators, and script interpreters (`sh`, `bash`, `dash`, `zsh`,
  `fish`, `sudo`, `doas`, `su`, `pkexec`, `python*`, `perl`, `ruby`, `node`,
  `curl`, `wget`) are forbidden.
- **Network hosts**: Every `http(s)://` host literal and every network API
  (`XMLHttpRequest`, `WebSocket`, `NetworkRequest`, `TcpSocket`) requires a
  matching entry in `capabilities.networkHosts` and a plain-language reason in
  `catalog-permissions.json`.
- **Timers**: Gate sub-second and polling `Timer` instances on active/visible
  state (e.g. `running: root.running && root.visible`) so idle or hidden
  plugins do not wake the shell unnecessarily.

## Local development & hot-reload (`scripts/dev_preview.sh`)

Start from `templates/starter-plugin/`:

```sh
cp -r templates/starter-plugin plugins/<your-id>
```

Use `scripts/dev_preview.sh` to validate, install locally, and reload the
running shell on every save:

```sh
# One-shot validate + install-local + reload
scripts/dev_preview.sh plugins/<your-id>

# Watch mode: re-validates and reloads Quickshell on every file change
scripts/dev_preview.sh plugins/<your-id> --watch
```

## Version bumps & regenerating `catalog.json`

Every payload change requires a version bump so `horneroctl plugin catalog update`
can detect it:

```sh
python3 scripts/bump_version.py <id> "Short changelog note"
python3 scripts/validate_plugins.py
python3 -m unittest discover -s tests
```

Because `catalog.json` records `generatedFrom` (the last commit touching
`plugins/`), commit plugin source changes first, then regenerate and commit
`catalog.json`:

```sh
python3 scripts/gen_catalog.py
python3 scripts/gen_catalog.py --check
```
