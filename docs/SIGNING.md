# Extension signing design (shell#251)

Status: **design**. The local trust floor already ships
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

- Manifest gains optional `author` object:
  `{ "name": "...", "minisignPublicKey": "RW...", "signature": "..." }`
  where `signature` is the minisign signature over the payload hash
  hex string. Optional on purpose: unsigned community plugins remain
  installable (local trust still required); signed ones gain a
  *verified-author* trust state.
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

## Registry (phase 3, gated on the human registry key)

- Static `community/index.json` in this repo: id, repo URL, pinned
  revision, payload hash, author key fingerprint. Generated, never
  hand-edited (same rule as `catalog.json`), with a detached
  minisign signature by the registry key.
- Clients verify the index signature *before* trusting any entry;
  a bad or missing signature means "registry unavailable", never a
  silent fallback to unsigned data.
- Signing proves the registry published an entry; it does **not**
  mean HorneroOS reviewed the code. UI copy must keep that
  distinction forever.

## Non-goals

- Sandboxing or capability enforcement (declarations stay advisory).
- A hosted registry service or review-board tooling.
- Reusing the horneroctl release GPG key for plugins.
