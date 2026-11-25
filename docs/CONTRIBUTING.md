# Contributing an extension

## Shape of a plugin

One directory per plugin under `plugins/<id>/`:

- `manifest.json` — the shell manifest contract
  (`schema/plugin-manifest.schema.json`). The directory name must
  equal the manifest `id`.
- The QML `entrypoint` (plain `QtQuick` `Item`; keep imports minimal
  so your plugin also loads in a stock Quickshell).
- `README.md` — what it does, how to install, the trust note.
- `LICENSE` — your license. MIT/BSD/Apache preferred for official.

`placement` decides where the shell renders the entrypoint:
`background` (headless, default), `bar`, `dashboard`, `desktop`.

## Rules

- Original code only. If you port an idea from another desktop,
  credit it in the README and respect its license. GPL code cannot
  be relicensed into this repository's MIT first-party set.
- `capabilities.processCommands` lists exact executable basenames;
  `networkHosts` lists every host. Under-declaring is a rejection.
- No executable bits, symlinks, binaries, or files not listed in
  `files`. The payload is hash-verified; drift fails CI.
- Screenshots must be real captures of the running shell, labelled
  with the shell version. Generated art must be labelled artwork.

## Provenance (`inventory.yaml`)

Every official plugin and every upstream capability studied for
inspiration carries a provenance entry in `inventory.yaml`
(HorneroOS/plugins#33), enforced by `scripts/validate_plugins.py`:

- `origin` — `{project, url, license}`: the verified upstream link
  (https) and its license.
- `classification` — `inspiration`, `adapt-idea`, or `research-only`
  for researched upstream capabilities; `implemented` or
  `hornero-original` for first-party plugins under `plugins/`.
- `license_status` — `verified` only when the license was observed
  at the upstream source, with `license_evidence` recording where:
  the https URL of the upstream license file, or, for first-party
  plugins, `plugins/<id>/LICENSE` (the validator probes that file
  and checks it against the manifest license). Anything not
  verified must read `license: UNVERIFIED` with
  `license_status: unverified` — never claim a license silently.
- `inspiration_notes` — what was taken as an idea and what was not
  (no upstream code is copied; GPL upstreams are idea-only).

A new official plugin must add its implemented entry in the same
change; the validator fails without it. Credit upstream inspiration
with a separate researched entry, not by pointing a first-party
entry at the upstream repository.

## Workflow

```sh
cp -r templates/starter-plugin plugins/<your-id>
python3 scripts/validate_plugins.py     # payload + manifest gate
python3 scripts/gen_catalog.py          # regenerate the index
```

Then exercise it on a real shell:

```sh
horneroctl plugin validate ./plugins/<your-id>
horneroctl plugin catalog install <your-id> --yes   # after merge
qs ipc call plugins status
```

Open a PR. CI re-runs both scripts and verifies `catalog.json` is
fresh. A maintainer reviews source, capability honesty, and license
before the `official` trust label is granted.

## Tool routing (which gate catches what)

| Tool | Scope |
|---|---|
| `scripts/validate_plugins.py` | Static payload/manifest gates for this repo (no shell is run) |
| `horneroctl plugin validate <path>` | The shell-side contract gate (PluginKit API level, capabilities, surfaces) |
| `scripts/gen_catalog.py` | Regenerates `catalog.json`; `--check` is the CI freshness gate |
| `qs ipc call plugins status` | Live-shell state: loaded, failed, diagnostics |

## Catalogue client contract (v1, frozen)

`catalog.json` is `{schemaVersion: 1, generatedFrom, catalogSource: {repo, rev}, plugins: [...]}`.
`catalogSource.repo` is the canonical upstream and `rev` is the last
commit that touched `plugins/` when the catalogue was generated, so a
client can resolve `repo@rev` to verify any entry against its exact
source tree. Row fields (`id`, `version`, `sha256` over the payload
defined by the manifest `files` list, `pluginKit` when above the
baseline, `marketplace`, `screenshots`, `permissions`) only grow
additively within v1. Freshness never compares `rev` (squash merges
rewrite it).

## Local testing without the marketplace

`horneroctl plugin install <https-git-url> --dry-run` previews any
public plugin repo whose root carries a `manifest.json`; `--yes`
installs it inert. Enable only code you have read.
