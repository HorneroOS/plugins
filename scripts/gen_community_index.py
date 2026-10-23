#!/usr/bin/env python3
"""Generate the deterministic, unsigned community index payload.

The generated JSON is signed separately with the human-maintained
registry key. This command never creates, reads, or stores a signing key.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from community_registry import RegistryError, build_index, json_text


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = ROOT / "community/index.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="write the unsigned JSON payload here")
    parser.add_argument("--check", action="store_true", help="fail if the output is missing or stale")
    args = parser.parse_args()
    try:
        text = json_text(build_index(ROOT))
    except RegistryError as exc:
        print(f"community index: {exc}", file=sys.stderr)
        return 1
    if args.check:
        try:
            current = args.output.read_text(encoding="utf-8")
        except OSError:
            current = None
        if current != text:
            print(f"{args.output} is stale; regenerate it with scripts/gen_community_index.py", file=sys.stderr)
            return 1
        print(f"community index payload OK: {args.output}")
        return 0
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text, encoding="utf-8")
    print(f"wrote unsigned community index payload: {args.output}")
    print("Do not publish it until a maintainer signs it with the separately held registry key.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
