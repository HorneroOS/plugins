# Community extensions (unreviewed)

This directory is the **submission intake** for third-party HorneroOS
Shell extensions. It is not the official catalogue:

- Community plugins are **not** in `catalog.json`, **not** shown as
  official in the Control Center catalogue, and **not** endorsed by
  HorneroOS maintainers. A merged submission means the package passed
  the automated contract gate and a basic safety read — nothing more.
- Plugin QML runs with the user's privileges and is **not
  sandboxed**. Review the source yourself before installing.
- Installing a community plugin today uses the author's own
  repository URL with `horneroctl plugin install <https-url> --yes`,
  and enabling it requires the explicit hash-pinned trust step
  (`horneroctl plugin trust <id> --yes`). Official catalogue plugins
  skip that step because their provenance is this repository's
  reviewed `plugins/` tree.

## Submit

1. One directory: `community/<your-plugin-id>/` with the same shape
   as an official plugin (`manifest.json`, entrypoint, `README.md`,
   `LICENSE`; see `docs/CONTRIBUTING.md` and
   `templates/starter-plugin/`).
2. Run `python3 scripts/validate_plugins.py` — community packages
   pass the exact same gate as official ones (schema, payload
   exactness, no symlinks/executables/binaries, honest capabilities).
3. Open a PR. State your repository URL, license, and what the
   plugin does. Original code only; ports must credit upstream and
   respect its license.
4. Updates are new PRs bumping `version` (semver). Users who
   installed your plugin will see `stale-trust` after any payload
   change and must re-trust — that is by design.

## Promotion to official

A community plugin may be proposed for `plugins/` (official) in a
separate PR. Promotion means maintainer review of every line,
HorneroOS ownership of future updates, and inclusion in
`catalog.json` with payload hashes. There is no automatic promotion.
