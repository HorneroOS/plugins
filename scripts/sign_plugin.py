#!/usr/bin/env python3
"""Print the files-only payload hash an author signs (docs/SIGNING.md).

The author signature covers this hash -- never the catalogue payload
hash, which includes manifest.json (the manifest carries the
signature and cannot sign itself). Framing matches horneroctl's
plugin_files_sha256 exactly: for each name in sorted(manifest
"files"): name NUL bytes NUL, SHA-256 hex.

Usage: scripts/sign_plugin.py <plugin-dir>
Then sign the printed hash with minisign and paste the block:
    printf %s "<hash>" > /tmp/hash.txt
    minisign -Sl -s ~/.minisign/hornero.key -m /tmp/hash.txt
    # public key: the RW... line of your .pub file
    # signature:  the second line of /tmp/hash.txt.minisig

The explicit -l selects Minisign's legacy Ed25519 framing for the
fixed 64-byte hash text. horneroctl verifies this exact framing.
"""
import argparse
import hashlib
import json
import pathlib
import sys


def payload_sha256(plugin: pathlib.Path) -> str:
    """Hash declared payload files using horneroctl's NUL-delimited framing."""
    manifest_path = plugin / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    files = manifest.get("files")
    if not isinstance(files, list) or not all(isinstance(name, str) for name in files):
        raise ValueError("manifest files must be a list of relative paths")

    names = sorted(set(files))
    digest = hashlib.sha256()
    for name in names:
        relative = pathlib.PurePosixPath(name)
        if relative.is_absolute() or ".." in relative.parts or not name:
            raise ValueError(f"unsafe manifest path: {name!r}")
        path = plugin.joinpath(*relative.parts)
        current = plugin
        has_symlink = False
        for part in relative.parts:
            current = current / part
            has_symlink |= current.is_symlink()
        if has_symlink or not path.is_file():
            raise ValueError(f"manifest file is missing or not a regular file: {name}")
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plugin_dir", nargs="?", type=pathlib.Path, default=pathlib.Path("."))
    args = parser.parse_args()
    try:
        digest = payload_sha256(args.plugin_dir)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(digest)
    print()
    print("Manifest block (after signing the hash above):")
    print(json.dumps({"signing": {"publicKey": "RW<your minisign public key>",
                                  "signature": "<base64 signature from minisign>"}}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
