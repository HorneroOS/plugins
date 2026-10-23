#!/usr/bin/env python3
"""Verify a detached minisign signature before parsing the community index."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from community_registry import RegistryError, strict_json_loads, validate_index


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--signature", type=Path, required=True)
    parser.add_argument("--public-key", type=Path, required=True, help="bootstrapped registry public key file")
    parser.add_argument("--minimum-version", type=int, default=1, help="reject older index versions")
    args = parser.parse_args()
    for path in (args.index, args.signature, args.public_key):
        if not path.is_file() or path.is_symlink():
            print(f"community index: required regular file missing: {path}", file=sys.stderr)
            return 1
    minisign = shutil.which("minisign")
    if minisign is None:
        print("community index: minisign is required to verify the detached signature", file=sys.stderr)
        return 1
    result = subprocess.run(
        [minisign, "-V", "-m", str(args.index), "-x", str(args.signature), "-p", str(args.public_key)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "signature verification failed"
        print(f"community index: {detail}", file=sys.stderr)
        return 1
    try:
        index = strict_json_loads(args.index.read_text(encoding="utf-8"))
        if not isinstance(index, dict):
            raise RegistryError("index must contain a JSON object")
        validate_index(index)
    except (OSError, UnicodeError, json.JSONDecodeError, RegistryError) as exc:
        print(f"community index: signed payload is invalid: {exc}", file=sys.stderr)
        return 1
    if args.minimum_version < 1 or index["indexVersion"] < args.minimum_version:
        print(
            f"community index: version {index['indexVersion']} is older than required {args.minimum_version}",
            file=sys.stderr,
        )
        return 1
    print(f"community index signature and schema verified: version {index['indexVersion']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
