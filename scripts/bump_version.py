#!/usr/bin/env python3
"""Bump an extension's patch version and prepend a changelog entry.

Usage: python3 scripts/bump_version.py <plugin-id> "<changelog note>"

A payload change without a version bump is refused by `horneroctl plugin
catalog update` ("installed payload differs from the official catalogue"),
so every payload change ships with a bump. Run scripts/gen_catalog.py after.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    plugin_id, note = sys.argv[1], sys.argv[2]
    path = ROOT / "plugins" / plugin_id / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", manifest["version"])
    if not match:
        print(f"{plugin_id}: version {manifest['version']!r} is not plain semver", file=sys.stderr)
        return 1
    major, minor, patch = (int(part) for part in match.groups())
    version = f"{major}.{minor}.{patch + 1}"
    manifest["version"] = version
    marketplace = manifest.setdefault("marketplace", {})
    marketplace["changelog"] = [{"version": version, "notes": note}] + list(marketplace.get("changelog", []))[:19]
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{plugin_id}: {version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
