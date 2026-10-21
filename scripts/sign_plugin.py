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
    minisign -S -s ~/.minisign/hornero.key -m /tmp/hash.txt
    # public key: the RW... line of your .pub file
    # signature:  the second line of /tmp/hash.txt.sig
"""
import hashlib
import json
import pathlib
import sys

plugin = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
manifest = json.loads((plugin / "manifest.json").read_text())
names = sorted(set(manifest.get("files", [])))
acc = b""
for name in names:
    acc += name.encode() + b"\0" + (plugin / name).read_bytes() + b"\0"
digest = hashlib.sha256(acc).hexdigest()
print(digest)
print()
print("Manifest block (after signing the hash above):")
print(json.dumps({"signing": {"publicKey": "RW<your minisign public key>",
                              "signature": "<base64 signature from minisign>"}}, indent=2))
