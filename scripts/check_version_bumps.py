#!/usr/bin/env python3
"""Fail when an extension's payload changed without a version bump.

`horneroctl plugin catalog update` refuses to touch an installed package
whose payload differs from the catalogue at the same version ("installed
payload differs from the official catalogue"), so a payload change that
keeps its version strands every installed copy. This compares each
plugins/<id> against the merge-base with the base ref (default
origin/main) and requires a different manifest version whenever any
shipped file (manifest.json or a path listed in `files`) changed.

Usage: python3 scripts/check_version_bumps.py [--base origin/main]
Skips (exit 0) when the base ref is unavailable, e.g. on a push to main.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=True).stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="origin/main")
    args = parser.parse_args()
    try:
        base = git("merge-base", "HEAD", args.base).strip()
    except subprocess.CalledProcessError:
        print(f"check_version_bumps: base {args.base} unavailable; skipped")
        return 0
    if base == git("rev-parse", "HEAD").strip():
        print("check_version_bumps: HEAD is the base; nothing to compare")
        return 0
    changed = [line for line in git("diff", "--name-only", f"{base}...HEAD", "--", "plugins").splitlines() if line]
    by_plugin: dict[str, list[str]] = {}
    for path in changed:
        parts = path.split("/", 2)
        if len(parts) == 3:
            by_plugin.setdefault(parts[1], []).append(parts[2])
    problems = []
    for plugin, files in sorted(by_plugin.items()):
        manifest_path = ROOT / "plugins" / plugin / "manifest.json"
        if not manifest_path.is_file():
            continue  # removed plugin
        head = json.loads(manifest_path.read_text(encoding="utf-8"))
        shipped = set(head.get("files", [])) | {"manifest.json"}
        touched = sorted(name for name in files if name in shipped)
        if not touched:
            continue
        try:
            before = json.loads(git("show", f"{base}:plugins/{plugin}/manifest.json"))
        except subprocess.CalledProcessError:
            continue  # new plugin
        if before.get("version") == head.get("version"):
            problems.append(f"{plugin}: {', '.join(touched)} changed but version stays {head.get('version')} "
                            f"(python3 scripts/bump_version.py {plugin} \"<note>\"; then scripts/gen_catalog.py)")
    for problem in problems:
        print(f"version bump required: {problem}", file=sys.stderr)
    if not problems:
        print("check_version_bumps: every changed payload bumps its version")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
