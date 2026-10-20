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

## Local testing without the marketplace

`horneroctl plugin install <https-git-url> --dry-run` previews any
public plugin repo whose root carries a `manifest.json`; `--yes`
installs it inert. Enable only code you have read.
