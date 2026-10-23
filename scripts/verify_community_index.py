#!/usr/bin/env python3
"""Verify a detached minisign signature before parsing the community index."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from community_registry import RegistryError, strict_json_loads, validate_index


MAX_INDEX_BYTES = 16 * 1024 * 1024
MAX_SIGNATURE_BYTES = 4 * 1024
MAX_PUBLIC_KEY_BYTES = 1024
MINISIGN_TIMEOUT_SECONDS = 30


def _read_regular_file(path: Path, maximum: int) -> bytes:
    """Read one bounded, non-symlink regular file snapshot."""
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    try:
        descriptor = os.open(path, flags)
        with os.fdopen(descriptor, "rb") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                raise RegistryError(f"required path is not a regular file: {path}")
            content = stream.read(maximum + 1)
    except OSError as exc:
        raise RegistryError(f"cannot read regular file {path}: {exc}") from exc
    if len(content) > maximum:
        raise RegistryError(f"file exceeds the {maximum}-byte limit: {path}")
    return content


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--signature", type=Path, required=True)
    parser.add_argument("--public-key", type=Path, required=True, help="bootstrapped registry public key file")
    parser.add_argument("--minimum-version", type=int, default=1, help="reject older index versions")
    args = parser.parse_args()
    try:
        index_bytes = _read_regular_file(args.index, MAX_INDEX_BYTES)
        signature_bytes = _read_regular_file(args.signature, MAX_SIGNATURE_BYTES)
        public_key_bytes = _read_regular_file(args.public_key, MAX_PUBLIC_KEY_BYTES)
    except RegistryError as exc:
        print(f"community index: {exc}", file=sys.stderr)
        return 1
    minisign = shutil.which("minisign")
    if minisign is None:
        print("community index: minisign is required to verify the detached signature", file=sys.stderr)
        return 1
    # Verify private snapshots, then parse `index_bytes` below. Never ask
    # Minisign and the JSON parser to reopen a mutable caller-controlled path.
    with tempfile.TemporaryDirectory(prefix="hornero-community-index-") as temp_dir:
        snapshot_dir = Path(temp_dir)
        index_snapshot = snapshot_dir / "index.json"
        signature_snapshot = snapshot_dir / "index.minisig"
        public_key_snapshot = snapshot_dir / "registry.pub"
        index_snapshot.write_bytes(index_bytes)
        signature_snapshot.write_bytes(signature_bytes)
        public_key_snapshot.write_bytes(public_key_bytes)
        try:
            result = subprocess.run(
                [minisign, "-V", "-m", str(index_snapshot), "-x", str(signature_snapshot), "-p", str(public_key_snapshot)],
                capture_output=True,
                text=True,
                check=False,
                timeout=MINISIGN_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            print("community index: minisign signature verification timed out", file=sys.stderr)
            return 1
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "signature verification failed"
            print(f"community index: {detail}", file=sys.stderr)
            return 1
    try:
        index = strict_json_loads(index_bytes.decode("utf-8"))
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
