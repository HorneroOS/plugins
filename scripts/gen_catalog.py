#!/usr/bin/env python3
"""Generate or check catalog.json from plugins/*/manifest.json.

The per-plugin manifest.json stays authoritative (same pattern as
Noctalia's generated catalog). catalog.json is an index for discovery:
identity, placement, capability disclosure, the git revision it was
generated at, and a SHA-256 over the package payload (manifest.json +
every file listed in manifest.files, in sorted order, framed as
name NUL bytes NUL) so installers can verify integrity before the
shell validator even runs.

Usage:
  python3 scripts/gen_catalog.py           # write catalog.json
  python3 scripts/gen_catalog.py --check   # fail if stale or invalid
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGINS = ROOT / "plugins"
CATALOG = ROOT / "catalog.json"
CATEGORIES = {
    "hornero-pomodoro": "productivity",
    "hornero-dual-clock": "utilities",
    "hornero-focus-card": "utilities",
    "hornero-quiet-notes": "productivity",
}


def payload_sha256(plugin_dir: Path, manifest: dict) -> str:
    h = hashlib.sha256()
    names = sorted(set(["manifest.json", *manifest.get("files", [])]))
    for name in names:
        data = (plugin_dir / name).read_bytes()
        h.update(name.encode())
        h.update(b"\0")
        h.update(data)
        h.update(b"\0")
    return h.hexdigest()


def build() -> dict:
    entries = []
    for plugin_dir in sorted(p for p in PLUGINS.iterdir() if p.is_dir()):
        manifest = json.loads((plugin_dir / "manifest.json").read_text())
        entries.append(
            {
                "id": manifest["id"],
                "name": manifest["name"],
                "version": manifest["version"],
                "description": manifest["description"],
                "author": manifest["author"],
                "license": manifest["license"],
                "homepage": manifest.get("homepage", ""),
                "placement": manifest.get("placement", "background"),
                "category": CATEGORIES.get(manifest["id"], "utilities"),
                "capabilities": manifest.get("capabilities", {}),
                "trust": "official",
                "path": f"plugins/{plugin_dir.name}",
                "sha256": payload_sha256(plugin_dir, manifest),
            }
        )
    # Revision of the commit that generated this catalog (HEAD),
    # stable across repeated --check runs in CI because checking
    # never moves HEAD. Re-run the generator after plugin changes
    # and commit catalog.json with the sources it describes.
    rev = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT, capture_output=True, text=True,
    ).stdout.strip()
    return {"schemaVersion": 1, "generatedFrom": rev, "plugins": entries}


def main() -> int:
    check = "--check" in sys.argv
    catalog = build()
    text = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    if check:
        if not CATALOG.exists() or CATALOG.read_text() != text:
            print("catalog.json is stale; run scripts/gen_catalog.py", file=sys.stderr)
            return 1
        print(f"catalog OK: {len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]}")
        return 0
    CATALOG.write_text(text)
    print(f"wrote catalog.json: {len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
