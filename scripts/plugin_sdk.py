#!/usr/bin/env python3
"""Zero-ceremony local SDK and hot-reload harness for Hornero Shell plugins.

Subcommands:
  new <id>      Scaffold a valid schemaVersion 3 plugin (manifest.json, Main.qml,
                translations/es.json, README.md, LICENSE) that passes
                scripts/validate_plugins.py out of the box.
  check <dir>   Validate a single plugin directory in <1s (static validator +
                strict JSON/i18n checks + qmllint when available).
  watch <dir>   Watch a plugin directory for file changes, auto-validate, and
                trigger `qs ipc call plugins reload` when Quickshell is running.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import validate_plugins  # noqa: E402

ROOT = SCRIPTS_DIR.parent
PLACEMENTS = ("bar", "desktop", "dashboard", "background")


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def _default_name(plugin_id: str) -> str:
    return " ".join(part.capitalize() for part in plugin_id.split("-"))


def _mit_license(author: str) -> str:
    year = datetime.date.today().year
    return (
        f"MIT License\n\nCopyright (c) {year} {author}\n\n"
        "Permission is hereby granted, free of charge, to any person obtaining a copy\n"
        'of this software and associated documentation files (the "Software"), to deal\n'
        "in the Software without restriction, including without limitation the rights\n"
        "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n"
        "copies of the Software, and to permit persons to whom the Software is\n"
        "furnished to do so, subject to the following conditions:\n\n"
        "The above copyright notice and this permission notice shall be included in all\n"
        "copies or substantial portions of the Software.\n\n"
        'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n'
        'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
        'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n'
        "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n"
        "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n"
        "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n"
        "SOFTWARE.\n"
    )


def _starter_qml(plugin_id: str, name: str, placement: str) -> str:
    if placement == "background":
        return (
            "import QtQuick\n"
            "import Hornero.PluginKit\n\n"
            f"// {name} (PluginKit 3, background)\n"
            "Item {\n"
            "    id: root\n\n"
            f'    Translations {{ id: i18n; pluginId: "{plugin_id}" }}\n'
            '    Subscription { domain: "time" }\n'
            f'    Accessible.name: i18n.tr("{name}")\n'
            "}\n"
        )
    if placement in ("desktop", "dashboard"):
        return (
            "import QtQuick\n"
            "import Hornero.PluginKit\n\n"
            f"// {name} (PluginKit 3, Hornero Signal)\n"
            "Item {\n"
            "    id: root\n\n"
            "    implicitWidth: 220\n"
            "    implicitHeight: 96\n\n"
            f'    Translations {{ id: i18n; pluginId: "{plugin_id}" }}\n'
            '    Subscription { domain: "time" }\n\n'
            "    Column {\n"
            "        anchors.centerIn: parent\n"
            "        spacing: Theme.spacing.smaller\n\n"
            "        UiText {\n"
            "            role: \"label\"\n"
            f'            text: i18n.tr("{name}")\n'
            "        }\n\n"
            "        UiText {\n"
            "            role: \"value\"\n"
            '            text: Time.format("HH:mm")\n'
            "        }\n"
            "    }\n"
            "}\n"
        )
    return (
        "import QtQuick\n"
        "import Hornero.PluginKit\n\n"
        f"// {name} (PluginKit 3, Hornero Signal): shows HH:mm in the bar.\n"
        "Item {\n"
        "    id: root\n\n"
        "    implicitWidth: label.implicitWidth + Theme.spacing.small * 2\n"
        "    implicitHeight: label.implicitHeight\n\n"
        f'    Translations {{ id: i18n; pluginId: "{plugin_id}" }}\n'
        '    Subscription { domain: "time" }\n'
        f'    Accessible.name: i18n.tr("{name}")\n\n'
        "    UiText {\n"
        "        id: label\n\n"
        "        anchors.centerIn: parent\n"
        '        role: "value"\n'
        '        text: Time.format("HH:mm")\n'
        "    }\n"
        "}\n"
    )


def scaffold_plugin(
    plugin_id: str,
    target_dir: Path | None = None,
    *,
    name: str | None = None,
    author: str = "HorneroOS contributor",
    description: str | None = None,
    placement: str = "bar",
    license_id: str = "MIT",
) -> Path:
    """Create a valid schemaVersion 3 plugin directory and return its path."""
    if not validate_plugins.ID_RE.match(plugin_id):
        raise ValueError(
            f"invalid plugin id {plugin_id!r}; use lowercase letters, digits, and internal hyphens (1-48 chars)"
        )
    if placement not in PLACEMENTS:
        raise ValueError(f"invalid placement {placement!r}; choose from {', '.join(PLACEMENTS)}")
    if license_id != "MIT":
        raise ValueError("scaffold only generates MIT LICENSE text; use --license MIT and swap LICENSE manually if needed")
    plugin_name = (name or _default_name(plugin_id)).strip()
    plugin_author = author.strip()
    plugin_desc = (description or f"{plugin_name} Hornero Shell extension.").strip()
    if not plugin_name or not plugin_author or not plugin_desc:
        raise ValueError("name, author, and description must be non-empty")

    out_dir = (target_dir or (ROOT / "plugins" / plugin_id)).resolve()
    if out_dir.name != plugin_id:
        raise ValueError(f"target directory basename ({out_dir.name!r}) must equal plugin id ({plugin_id!r})")
    if out_dir.exists() or out_dir.is_symlink():
        raise FileExistsError(f"target directory already exists: {out_dir}")
    if not out_dir.parent.is_dir():
        raise FileNotFoundError(f"parent directory does not exist: {out_dir.parent}")

    manifest = {
        "schemaVersion": 3,
        "pluginKit": 3,
        "id": plugin_id,
        "name": plugin_name,
        "version": "0.1.0",
        "description": plugin_desc,
        "author": plugin_author,
        "license": license_id,
        "entrypoint": "Main.qml",
        "placement": placement,
        "translations": {
            "sourceLocale": "en",
            "locales": ["es"],
            "directory": "translations",
        },
        "files": [
            "Main.qml",
            "README.md",
            "LICENSE",
            "translations/es.json",
        ],
        "capabilities": {
            "processCommands": [],
            "networkHosts": [],
            "providers": ["time"],
            "settings": {},
        },
    }
    readme = (
        f"# {plugin_name}\n\n"
        f"{plugin_desc}\n\n"
        "QML plugins execute in-process inside Quickshell with your user privileges and are not sandboxed.\n\n"
        "## Validate locally\n\n"
        "```sh\n"
        f"python3 scripts/plugin_sdk.py check {out_dir}\n"
        "```\n"
    )
    translations_es = {
        plugin_name: plugin_name,
    }

    import tempfile

    with tempfile.TemporaryDirectory(dir=out_dir.parent, prefix=f".{plugin_id}.sdk-tmp-") as tmp_parent:
        stage = Path(tmp_parent) / plugin_id
        stage.mkdir(mode=0o755)
        os.chmod(stage, 0o755)
        (stage / "translations").mkdir(mode=0o755)
        os.chmod(stage / "translations", 0o755)

        files = {
            "manifest.json": json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
            "Main.qml": _starter_qml(plugin_id, plugin_name, placement),
            "translations/es.json": json.dumps(translations_es, indent=2, ensure_ascii=False) + "\n",
            "README.md": readme,
            "LICENSE": _mit_license(plugin_author),
        }
        for rel, content in files.items():
            target = stage / rel
            target.write_text(content, encoding="utf-8")
            os.chmod(target, 0o644)

        errors, _, _ = validate_plugins.validate_plugin_dir(stage)
        if errors:
            raise ValueError("generated scaffold failed validation: " + "; ".join(errors))
        stage.rename(out_dir)
    return out_dir


def _discover_shell_qml_import_dir() -> Path | None:
    candidate = ROOT.parent / "shell" / "plugin" / "qml"
    if candidate.is_dir():
        return candidate
    candidate_alt = ROOT.parent / "github.com" / "HorneroOS" / "shell" / "plugin" / "qml"
    if candidate_alt.is_dir():
        return candidate_alt
    return None


def _run_qmllint(plugin_dir: Path, qml_files: list[Path]) -> tuple[list[str], bool]:
    """Run qmllint on qml_files if available; returns (errors, qmllint_ran)."""
    qmllint = shutil.which("qmllint")
    if qmllint is None or not qml_files:
        return [], False
    cmd = [qmllint]
    import_dir = _discover_shell_qml_import_dir()
    if import_dir is not None:
        cmd.extend(["-I", str(import_dir)])
    cmd.extend(str(p) for p in qml_files)
    result = subprocess.run(cmd, cwd=plugin_dir, capture_output=True, text=True, check=False, timeout=15)
    if result.returncode == 0:
        return [], True
    detail = (result.stderr or result.stdout).strip() or f"qmllint exited {result.returncode}"
    return [f"{plugin_dir.name}: qmllint: {detail}"], True


def check_plugin(
    plugin_dir: Path,
    *,
    use_qmllint: bool = True,
    shell_path: Path | None = None,
) -> dict:
    """Validate one plugin directory and return a structured report."""
    started = time.monotonic()
    plugin_dir = plugin_dir.resolve()
    errors: list[str] = []
    if not plugin_dir.is_dir():
        return {
            "ok": False,
            "id": plugin_dir.name,
            "path": str(plugin_dir),
            "errors": [f"{plugin_dir.name}: plugin directory not found: {plugin_dir}"],
            "qmllint": False,
            "elapsed_ms": round((time.monotonic() - started) * 1000, 1),
        }

    manifest_path = plugin_dir / "manifest.json"
    if not manifest_path.is_file():
        errors.append(f"{plugin_dir.name}: manifest.json not found")
    else:
        try:
            json.loads(manifest_path.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{plugin_dir.name}: manifest.json JSON error: {exc}")

    # Enforce strict JSON duplicate-key check on all translation JSON files too.
    for json_file in sorted(plugin_dir.rglob("*.json")):
        if json_file.name == "manifest.json" or json_file.is_symlink():
            continue
        try:
            json.loads(json_file.read_text(encoding="utf-8"), object_pairs_hook=_unique_object)
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{plugin_dir.name}: {json_file.relative_to(plugin_dir)} JSON error: {exc}")

    val_errors, manifest, _ = validate_plugins.validate_plugin_dir(plugin_dir)
    for err in val_errors:
        if err not in errors:
            errors.append(err)

    qml_files = sorted(p for p in plugin_dir.rglob("*.qml") if p.is_file() and not p.is_symlink())
    qmllint_ran = False
    if use_qmllint:
        lint_errors, qmllint_ran = _run_qmllint(plugin_dir, qml_files)
        errors.extend(lint_errors)

    if shell_path is not None:
        validator = shell_path / "scripts" / "validate_plugin.py"
        if not validator.is_file():
            errors.append(f"shell validator not found: {validator}")
        else:
            res = subprocess.run(
                [sys.executable, str(validator), str(plugin_dir)],
                capture_output=True,
                text=True,
                check=False,
                timeout=20,
            )
            if res.returncode != 0:
                detail = (res.stdout + res.stderr).strip() or f"shell validator exited {res.returncode}"
                errors.append(f"{plugin_dir.name}: shell validator: {detail}")

    return {
        "ok": len(errors) == 0,
        "id": (manifest or {}).get("id", plugin_dir.name),
        "version": (manifest or {}).get("version", ""),
        "path": str(plugin_dir),
        "errors": errors,
        "qmllint": qmllint_ran,
        "elapsed_ms": round((time.monotonic() - started) * 1000, 1),
    }


def snapshot_tree(plugin_dir: Path) -> dict[str, tuple[int, int]]:
    """Return {relative_posix_path: (mtime_ns, size)} for regular non-hidden files."""
    state: dict[str, tuple[int, int]] = {}
    if not plugin_dir.is_dir():
        return state
    for path in sorted(plugin_dir.rglob("*")):
        rel_parts = path.relative_to(plugin_dir).parts
        if any(part.startswith(".") for part in rel_parts):
            continue
        if path.is_file() and not path.is_symlink():
            st = path.stat()
            state[path.relative_to(plugin_dir).as_posix()] = (st.st_mtime_ns, st.st_size)
    return state


def detect_changes(
    previous: dict[str, tuple[int, int]], current: dict[str, tuple[int, int]]
) -> list[str]:
    """Return sorted relative paths added, removed, or modified between snapshots."""
    changed = {
        key
        for key in set(previous) | set(current)
        if previous.get(key) != current.get(key)
    }
    return sorted(changed)


def trigger_reload(
    plugin_dir: Path,
    plugin_id: str,
    *,
    dry_run: bool = False,
    install_local: bool = False,
    out=None,
) -> bool:
    """Install locally (optional) and ask a running Quickshell instance to reload plugins."""
    out = sys.stdout if out is None else out
    if dry_run:
        if install_local:
            print(f"[dry-run] would install-local + trust + enable {plugin_id}", file=out)
        print("[dry-run] would run: qs ipc call plugins reload", file=out)
        return True

    if install_local:
        horneroctl = shutil.which("horneroctl")
        if horneroctl is None:
            print("note: horneroctl not found in PATH; skipping install-local", file=out)
        else:
            subprocess.run([horneroctl, "plugin", "validate", str(plugin_dir)], check=False, timeout=20)
            subprocess.run([horneroctl, "plugin", "install-local", str(plugin_dir), "--yes"], check=False, timeout=20)
            subprocess.run([horneroctl, "plugin", "trust", plugin_id, "--yes"], check=False, timeout=20)
            subprocess.run([horneroctl, "plugin", "enable", plugin_id, "--yes"], check=False, timeout=20)

    qs = shutil.which("qs")
    if qs is None:
        print("note: qs not found in PATH; skipping live shell reload", file=out)
        return False
    res = subprocess.run([qs, "ipc", "call", "plugins", "reload"], capture_output=True, text=True, check=False, timeout=10)
    if res.returncode == 0:
        print("reloaded plugins via `qs ipc call plugins reload`", file=out)
        return True
    detail = (res.stderr or res.stdout).strip()
    print(f"note: `qs ipc call plugins reload` did not succeed ({detail or f'exit {res.returncode}'})", file=out)
    return False


def watch_plugin(
    plugin_dir: Path,
    *,
    interval: float = 0.5,
    max_cycles: int | None = None,
    dry_run: bool = False,
    install_local: bool = False,
    use_qmllint: bool = True,
    on_cycle: Callable[[int, dict, list[str]], None] | None = None,
    out=None,
    err=None,
) -> int:
    """Validate initially, then poll for file changes and reload on valid saves."""
    out = sys.stdout if out is None else out
    err = sys.stderr if err is None else err
    plugin_dir = plugin_dir.resolve()
    prev = snapshot_tree(plugin_dir)
    report = check_plugin(plugin_dir, use_qmllint=use_qmllint)
    _print_check_report(report, out=out, err=err)
    if report["ok"]:
        trigger_reload(plugin_dir, report["id"], dry_run=dry_run, install_local=install_local, out=out)
    if on_cycle is not None:
        on_cycle(0, report, [])

    if max_cycles is not None and max_cycles <= 1:
        return 0 if report["ok"] else 1

    cycle = 1
    try:
        while max_cycles is None or cycle < max_cycles:
            time.sleep(interval)
            curr = snapshot_tree(plugin_dir)
            changed = detect_changes(prev, curr)
            if changed:
                print(f"changed: {', '.join(changed)}", file=out)
                report = check_plugin(plugin_dir, use_qmllint=use_qmllint)
                _print_check_report(report, out=out, err=err)
                if report["ok"]:
                    trigger_reload(
                        plugin_dir,
                        report["id"],
                        dry_run=dry_run,
                        install_local=install_local,
                        out=out,
                    )
                prev = curr
            if on_cycle is not None:
                on_cycle(cycle, report, changed)
            cycle += 1
    except KeyboardInterrupt:
        print("\nwatch stopped", file=out)
    return 0 if report["ok"] else 1


def _print_check_report(report: dict, *, out=None, err=None) -> None:
    out = sys.stdout if out is None else out
    err = sys.stderr if err is None else err
    if report["ok"]:
        lint_tag = "+qmllint" if report.get("qmllint") else "static"
        print(
            f"OK {report['id']} {report.get('version', '')} ({lint_tag}, {report['elapsed_ms']}ms)".strip(),
            file=out,
        )
    else:
        for message in report["errors"]:
            print(f"FAIL {message}", file=err)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p_new = sub.add_parser("new", help="scaffold a valid schemaVersion 3 plugin")
    p_new.add_argument("id", help="plugin id (lowercase letters, digits, hyphens)")
    p_new.add_argument("--name", default=None, help="display name")
    p_new.add_argument("--author", default="HorneroOS contributor", help="author name")
    p_new.add_argument("--description", default=None, help="short plugin description")
    p_new.add_argument("--placement", choices=PLACEMENTS, default="bar", help="default surface placement")
    p_new.add_argument("--license", default="MIT", help="license identifier (MIT)")
    p_new.add_argument("--dir", type=Path, default=None, help="target directory (default: plugins/<id>)")

    p_check = sub.add_parser("check", help="validate a single plugin directory in <1s")
    p_check.add_argument("dir", type=Path, help="plugin directory to validate")
    p_check.add_argument("--no-qmllint", action="store_true", help="skip qmllint even if installed")
    p_check.add_argument("--shell", type=Path, default=None, help="optional path to HorneroOS/shell checkout")
    p_check.add_argument("--json", action="store_true", help="emit JSON report")

    p_watch = sub.add_parser("watch", help="watch a plugin directory and hot-reload on changes")
    p_watch.add_argument("dir", type=Path, help="plugin directory to watch")
    p_watch.add_argument("--interval", type=float, default=0.5, help="poll interval in seconds (default: 0.5)")
    p_watch.add_argument("--once", action="store_true", help="run one check/reload pass and exit")
    p_watch.add_argument("--max-cycles", type=int, default=None, help="exit after N poll cycles")
    p_watch.add_argument("--dry-run", action="store_true", help="validate without calling horneroctl or qs")
    p_watch.add_argument("--install-local", action="store_true", help="also run horneroctl install-local/trust/enable")
    p_watch.add_argument("--no-qmllint", action="store_true", help="skip qmllint even if installed")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "new":
        try:
            out_dir = scaffold_plugin(
                args.id,
                args.dir,
                name=args.name,
                author=args.author,
                description=args.description,
                placement=args.placement,
                license_id=args.license,
            )
        except (OSError, ValueError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1
        print(f"created valid schemaVersion 3 plugin at {out_dir}")
        return 0

    if args.command == "check":
        report = check_plugin(
            args.dir,
            use_qmllint=not args.no_qmllint,
            shell_path=args.shell,
        )
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            _print_check_report(report)
        return 0 if report["ok"] else 1

    if args.command == "watch":
        max_cycles = 1 if args.once else args.max_cycles
        return watch_plugin(
            args.dir,
            interval=args.interval,
            max_cycles=max_cycles,
            dry_run=args.dry_run,
            install_local=args.install_local,
            use_qmllint=not args.no_qmllint,
        )

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
