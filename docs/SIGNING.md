# Extension signing design (shell#251)

Status: **phase 2 shipped** (author signature verification in
HorneroOS/hornero#236, schema in HorneroOS/shell#286). Phase 3 now has
a strict source schema, deterministic index generator, detached-signature
verification tool, and ephemeral-key CI coverage. Production key
custody and client enforcement remain human and cross-repository gates.
The local trust floor already ships
(`horneroctl plugin trust`, hash-pinned, in HorneroOS/hornero).
Signing adds *author identity* on top of hashes; it never replaces
review, and it is never a sandbox.

## Decision: per-author minisign keys; registry key separate

- **Authors** sign the payload hash of their plugin with
  [minisign](https://jedisct1.github.io/minisign/) (Ed25519,
  single-purpose keys, text signatures that survive code review and
  git transport). GPG was rejected for *authors*: keyring management
  and identity ceremonies are too heavy for extension authors, and
  HorneroOS cannot vouch for author GPG identities anyway. (HorneroOS
  *release binaries* use GPG for makepkg `validpgpkeys` fit — a
  different problem, a different key, deliberately not reused here.)
- Author signatures cover a fixed 64-byte hexadecimal payload hash.
  The current `horneroctl` verifier supports Minisign's legacy `Ed`
  detached-signature framing for that small message, so authors must
  sign with `minisign -Sl`. The default prehashed `ED` format is not
  compatible with this verifier and must not be used for plugin
  manifests. The registry index uses ordinary detached Minisign files
  and is verified by the Minisign implementation.
- **The registry index** (a future signed `community/index.json`)
  is signed by a dedicated HorneroOS **registry key** — not the
  release key, not the AUR key. Custody is a human maintainer step,
  same pattern as `docs/RELEASE_SIGNING.md` in HorneroOS/hornero.
  Until that key exists, there is no signed index and community
  distribution stays author-URL + local trust.

## What gets signed

Exactly the payload hash already used everywhere
(`scripts/gen_catalog.py` framing: for each name in
sorted(`manifest.json` + `files`): `name NUL bytes NUL`, SHA-256).
Signing anything else (e.g. a hand-written manifest digest) would
fork the integrity story; one hash, three consumers: catalogue,
local trust, author signature.

## Manifest and receipt changes (phase 2)

- Manifest gains an optional top-level `signing` object:
  `{ "publicKey": "RW...", "signature": "..." }` (the manifest's
  existing `author` string stays the human-readable name). The
  signature covers the **files-only payload hash** — same framing
  over the manifest's `files` list, manifest.json itself excluded,
  because the manifest carries the signature and cannot sign itself.
  Optional on purpose: unsigned community plugins remain installable
  (local trust still required); signed ones gain a *verified-author*
  trust state. Shipped in HorneroOS/hornero#236 (verification) and
  HorneroOS/shell#286 (schema/validator).
- `horneroctl plugin list` trust states become:
  `official` > `signed` (signature verifies against the manifest's
  declared key *and* the payload hash) > `trusted` (local hash pin)
  > `untrusted` / `stale-trust`.
- A signature that fails verification is worse than none: the
  plugin reports `bad-signature` and cannot be enabled until the
  signature is fixed or removed and local trust is recorded.
- Key continuity is the author's problem, stated plainly: if an
  author rotates keys, previously trusted users see the new key as
  a new identity and must re-trust. No silent key substitution.

## Registry (phase 3)

- `community/registry-sources.json` is the reviewed publication
  allowlist. Each record contains the plugin id, HTTPS repository URL,
  full commit id, payload SHA-256, and the author's minisign public key.
  The generator validates these fields, rejects duplicate ids and
  mutable refs, and emits sorted records with the author's key
  fingerprint.
- Fingerprints are lowercase hex SHA-256 over the decoded 42-byte
  minisign public-key record (`Ed` algorithm tag + key id + Ed25519 key),
  formatted as `sha256:<64 hex characters>`. Clients derive this from
  the key in the pinned plugin manifest and compare it with the signed
  registry record.
- The JSON payload is deterministic and has a monotonically maintained
  `indexVersion`, schema version, and `generatedFrom` commit. Its schema
  is [`schema/community-registry-index.schema.json`](../schema/community-registry-index.schema.json).
  Generate it with `python3 scripts/gen_community_index.py`; the command
  writes unsigned JSON only and never accesses a signing key.
- A maintainer signs the generated payload with the dedicated registry
  key, held outside this repository:

  ```sh
  minisign -S -s /secure/path/hornero-registry.key \
    -m community/index.json -x community/index.json.minisig
  ```

- Verify the detached signature before parsing or using the index:

  ```sh
  python3 scripts/verify_community_index.py \
    --index community/index.json \
    --signature community/index.json.minisig \
    --public-key /etc/hornero/registry.pub
  ```

- CI creates an ephemeral test key and checks signature success and
  tamper rejection. Test keys are never published. No production key or
  signed production index is checked in until a maintainer completes key
  custody and public-key bootstrap review.
- Clients verify the index signature *before* trusting any entry;
  a bad or missing signature means "registry unavailable", never a
  silent fallback to unsigned data.
- Clients must persist the highest accepted `indexVersion`, reject a
  lower version, and enforce key revocation/rotation policy. The current
  verifier's `--minimum-version` is a maintainer/test guard, not a
  replacement for persistent client rollback protection.
- Signing proves the registry published an entry; it does **not**
  mean HorneroOS reviewed the code. UI copy must keep that
  distinction forever.

### Updating a published index

1. Review the plugin source and author signature separately. Add or
   update the allowlist record and increment `indexVersion`.
2. Commit `community/registry-sources.json` first. Generate
   `community/index.json` in a following commit so `generatedFrom`
   remains stable across CI's merge commit.
3. A maintainer signs the generated bytes with the dedicated key and
   commits the detached `.minisig` alongside the index. CI exercises the
   test-key path; the maintainer verifies the production signature
   before publication.

## Non-goals

- Sandboxing or capability enforcement (declarations stay advisory).
- A hosted registry service or review-board tooling.
- Reusing the horneroctl release GPG key for plugins.
