#!/usr/bin/env python3
"""Run the shell's canonical validator over every schemaVersion 3 package.

usage: shell_parity.py <path-to-shell-checkout>

Official plugins and community packages with schemaVersion 3 must pass the
shell's scripts/validate_plugin.py unchanged. Packages still on schemaVersion
1/2 are skipped (they are refused by the shipped host and being ported,
HorneroOS/plugins#62); the count is printed so progress is visible.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main(argv) -> int:
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    validator = Path(argv[0]) / "scripts" / "validate_plugin.py"
    if not validator.is_file():
        print(f"shell validator not found: {validator}", file=sys.stderr)
        return 2
    failed, checked, legacy = [], 0, 0
    dirs = sorted(p for base in ("plugins", "community") if (ROOT / base).is_dir() for p in (ROOT / base).iterdir() if (p / "manifest.json").is_file())
    for plugin_dir in dirs:
        manifest = json.loads((plugin_dir / "manifest.json").read_text())
        if manifest.get("schemaVersion") != 3:
            legacy += 1
            continue
        checked += 1
        result = subprocess.run([sys.executable, str(validator), str(plugin_dir)], capture_output=True, text=True)
        if result.returncode != 0:
            failed.append(plugin_dir.name)
            print(f"FAIL {plugin_dir.name}\n{result.stdout}{result.stderr}", file=sys.stderr)
    print(f"shell validator: {checked} schemaVersion 3 packages checked, {len(failed)} failed, {legacy} legacy skipped")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
