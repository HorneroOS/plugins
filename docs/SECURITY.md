# Security model

## What a plugin can do

Everything your user can do. Plugin QML executes in-process inside
Quickshell: filesystem, processes and network are all reachable from
QML regardless of what a manifest declares. **Capability declarations
are review metadata, not enforcement.** Anyone who tells you otherwise
is selling a sandbox that does not exist.

## What the marketplace does about it

1. **Pinned, hashed payloads.** `catalog.json` records the git
   revision and a SHA-256 over each package payload. Installers
   verify the hash before the shell validator runs.
2. **Static validation.** The shell validator rejects malformed
   packages, symlinks, binaries, executable bits, path escapes and a
   conservative set of suspicious source patterns. Passing is not a
   security certification.
3. **Capability disclosure.** Manifests declare `processCommands`
   and `networkHosts` up front; the Control Center shows them before
   the enable consent. An empty declaration with code that spawns
   processes is a review failure.
4. **Explicit consent.** Install copies inert data. Enable is a
   separate action that requires `--yes` (CLI) or the consent dialog
   (Control Center), every time the payload changes.
5. **Receipts and rollback.** Every install writes a receipt (id,
   version, source, revision). Removing a plugin deletes its data
   directory and receipt; reinstalling a previous catalog revision is
   the supported rollback path.
6. **Review tiers.** `official` = maintainer-reviewed in this repo.
   `community` = listed, unreviewed, warning shown. There is no
   silent promotion between tiers.

## Author rules

- No credentials, tokens or personal configuration in a package.
- No compiled binaries, no bytecode, no `curl | bash`, ever.
- Declare every process you spawn and every host you contact.
- License your code; packages without a LICENSE file are rejected.

## Reporting

Open a private security advisory on this repository for anything that
could harm users: hash mismatches, validator bypasses, or an official
plugin exceeding its declared capabilities.
