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
import re
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
    # Revision of the last commit that touched plugins/ at generation
    # time. It is provenance for the snapshot, not freshness: a squash
    # merge rewrites that commit, so --check must not compare it (see
    # catalog_is_current). Generation still stamps the current value.
    rev = subprocess.run(
        ["git", "log", "-1", "--format=%H", "--", "plugins/"],
        cwd=ROOT, capture_output=True, text=True,
    ).stdout.strip()
    return {"schemaVersion": 1, "generatedFrom": rev, "plugins": entries}


def catalog_is_current(existing_text: str, built: dict) -> bool:
    """Freshness compares plugin entries, never the generatedFrom stamp.

    Squash merges rewrite the commit that last touched plugins/, so a
    byte comparison would report a just-merged catalog as stale forever.
    The stamp must still be present and be a full commit id.
    """
    try:
        existing = json.loads(existing_text)
    except json.JSONDecodeError:
        return False
    if not isinstance(existing, dict):
        return False
    stamp = existing.get("generatedFrom")
    if not isinstance(stamp, str) or not re.fullmatch(r"[0-9a-f]{40}([0-9a-f]{24})?", stamp):
        return False
    return (
        existing.get("schemaVersion") == built["schemaVersion"]
        and existing.get("plugins") == built["plugins"]
    )


def main() -> int:
    check = "--check" in sys.argv
    catalog = build()
    text = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    if check:
        if not CATALOG.exists() or not catalog_is_current(CATALOG.read_text(), catalog):
            print("catalog.json is stale; run scripts/gen_catalog.py", file=sys.stderr)
            return 1
        print(f"catalog OK: {len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]}")
        return 0
    CATALOG.write_text(text)
    print(f"wrote catalog.json: {len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
