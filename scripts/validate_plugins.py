#!/usr/bin/env python3
"""Validate every plugins/*/ package against the Hornero Shell plugin
manifest schema plus marketplace rules, without third-party deps.

Checks: manifest parses, required fields, id pattern, semver, files
listed exist and are exactly the payload (manifest.json + files),
README.md and LICENSE present, no symlinks/executables/binaries, and
the entrypoint exists. Schema-level validation also runs in the shell
repository's validator at install time; this is the marketplace gate.
"""
import json
import re
import stat
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,47}$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$")
REQUIRED = ["schemaVersion", "id", "name", "version", "description", "author", "license", "entrypoint", "files", "capabilities"]
BINARY_SUFFIXES = {".so", ".o", ".a", ".bin", ".exe", ".dll", ".pyc"}


def main() -> int:
    errors = []
    # Official plugins (plugins/) feed catalog.json. Community
    # submissions (community/) pass the exact same contract gate but
    # are never catalogued, endorsed, or distributed as official.
    plugin_dirs = sorted(p for p in (ROOT / "plugins").iterdir() if p.is_dir())
    community_root = ROOT / "community"
    if community_root.is_dir():
        plugin_dirs += sorted(p for p in community_root.iterdir() if p.is_dir())
    for plugin_dir in plugin_dirs:
        tag = plugin_dir.name
        try:
            manifest = json.loads((plugin_dir / "manifest.json").read_text())
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{tag}: manifest.json unreadable: {exc}")
            continue
        for field in REQUIRED:
            if field not in manifest:
                errors.append(f"{tag}: missing required field {field}")
        if manifest.get("schemaVersion") != 1:
            errors.append(f"{tag}: schemaVersion must be 1")
        if not ID_RE.match(str(manifest.get("id", ""))):
            errors.append(f"{tag}: id does not match {ID_RE.pattern}")
        if manifest.get("id") != plugin_dir.name:
            errors.append(f"{tag}: directory name must equal manifest id")
        if not SEMVER_RE.match(str(manifest.get("version", ""))):
            errors.append(f"{tag}: version is not semver")
        files = manifest.get("files", [])
        if "README.md" not in files or "LICENSE" not in files:
            errors.append(f"{tag}: files must include README.md and LICENSE")
        for name in files:
            path = plugin_dir / name
            if not path.is_file():
                errors.append(f"{tag}: listed file missing: {name}")
        on_disk = {
            str(p.relative_to(plugin_dir))
            for p in plugin_dir.rglob("*")
            if p.is_file() and not p.is_symlink()
        }
        if on_disk != set(files) | {"manifest.json"}:
            errors.append(f"{tag}: payload drift, on disk {sorted(on_disk)} vs manifest {sorted(set(files) | {'manifest.json'})}")
        for path in plugin_dir.rglob("*"):
            if path.is_symlink():
                errors.append(f"{tag}: symlink not allowed: {path.relative_to(plugin_dir)}")
            elif path.is_file():
                mode = path.stat().st_mode
                if mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH):
                    errors.append(f"{tag}: executable file not allowed: {path.relative_to(plugin_dir)}")
                if path.suffix in BINARY_SUFFIXES:
                    errors.append(f"{tag}: binary file not allowed: {path.relative_to(plugin_dir)}")
        entry = plugin_dir / str(manifest.get("entrypoint", ""))
        if not entry.is_file():
            errors.append(f"{tag}: entrypoint missing: {manifest.get('entrypoint')}")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("plugins valid:", ", ".join(sorted(p.name for p in (ROOT / "plugins").iterdir() if p.is_dir())))
    if community_root.is_dir():
        community = sorted(p.name for p in community_root.iterdir() if p.is_dir())
        print("community valid (unreviewed, not catalogued):", ", ".join(community) or "none")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
