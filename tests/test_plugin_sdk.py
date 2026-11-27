from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import plugin_sdk  # noqa: E402
import sign_plugin  # noqa: E402
import validate_plugins  # noqa: E402

SHELL_VALIDATOR = Path("/home/ulisesjcf/.ai-workspace/repos/github.com/HorneroOS/shell/scripts/validate_plugin.py")


class PluginSdkNewTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_new_scaffolds_valid_schemaversion3_plugin_across_placements(self) -> None:
        for placement in ("bar", "desktop", "dashboard", "background"):
            plugin_id = f"demo-{placement}"
            target = self.root / plugin_id
            output = StringIO()
            with redirect_stdout(output):
                rc = plugin_sdk.main([
                    "new",
                    plugin_id,
                    "--placement",
                    placement,
                    "--dir",
                    str(target),
                ])
            self.assertEqual(rc, 0)
            self.assertIn("schemaVersion 3", output.getvalue())

            expected_files = [
                "manifest.json",
                "Main.qml",
                "README.md",
                "LICENSE",
                "translations/es.json",
            ]
            for rel in expected_files:
                file_path = target / rel
                self.assertTrue(file_path.is_file(), f"missing {rel}")
                mode = stat.S_IMODE(file_path.stat().st_mode)
                self.assertEqual(mode & 0o133, 0, f"{rel} has forbidden executable/world-write mode {oct(mode)}")

            errors, manifest, _ = validate_plugins.validate_plugin_dir(target)
            self.assertEqual(errors, [], f"{placement} failed validate_plugin_dir: {errors}")
            self.assertEqual(manifest["schemaVersion"], 3)
            self.assertEqual(manifest["placement"], placement)

            # Canonical files-only payload hash must also succeed.
            digest = sign_plugin.payload_sha256(target)
            self.assertEqual(len(digest), 64)

            if SHELL_VALIDATOR.is_file():
                shell_res = subprocess.run(
                    [sys.executable, str(SHELL_VALIDATOR), str(target)],
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(shell_res.returncode, 0, shell_res.stdout + shell_res.stderr)

    def test_new_rejects_invalid_id_and_refuses_overwrite(self) -> None:
        errors = StringIO()
        with patch("sys.stderr", errors):
            rc = plugin_sdk.main(["new", "Bad_ID", "--dir", str(self.root / "Bad_ID")])
        self.assertEqual(rc, 1)
        self.assertIn("invalid plugin id", errors.getvalue())

        target = self.root / "demo-once"
        self.assertEqual(plugin_sdk.main(["new", "demo-once", "--dir", str(target)]), 0)
        errors2 = StringIO()
        with patch("sys.stderr", errors2):
            rc2 = plugin_sdk.main(["new", "demo-once", "--dir", str(target)])
        self.assertEqual(rc2, 1)
        self.assertIn("already exists", errors2.getvalue())


class PluginSdkCheckTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.plugin_dir = self.root / "check-demo"
        plugin_sdk.scaffold_plugin("check-demo", self.plugin_dir)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_check_passes_subsecond_and_emits_json(self) -> None:
        output = StringIO()
        with redirect_stdout(output):
            rc = plugin_sdk.main(["check", str(self.plugin_dir), "--json"])
        self.assertEqual(rc, 0)
        report = json.loads(output.getvalue())
        self.assertTrue(report["ok"])
        self.assertEqual(report["id"], "check-demo")
        self.assertLess(report["elapsed_ms"], 1000.0)

    def test_check_catches_bad_manifest_schema_version_and_drift(self) -> None:
        manifest_path = self.plugin_dir / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["schemaVersion"] = 2
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

        report = plugin_sdk.check_plugin(self.plugin_dir, use_qmllint=False)
        self.assertFalse(report["ok"])
        self.assertTrue(any("schemaVersion 2" in err for err in report["errors"]))

        # Fix schemaVersion, introduce duplicate JSON key in translations/es.json.
        manifest["schemaVersion"] = 3
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        (self.plugin_dir / "translations" / "es.json").write_text('{"a":"b","a":"c"}\n', encoding="utf-8")
        report2 = plugin_sdk.check_plugin(self.plugin_dir, use_qmllint=False)
        self.assertFalse(report2["ok"])
        self.assertTrue(any("duplicate" in err for err in report2["errors"]))

    @unittest.skipUnless(shutil.which("qmllint"), "qmllint installed for QML syntax check")
    def test_check_catches_broken_qml_with_qmllint(self) -> None:
        (self.plugin_dir / "Main.qml").write_text("import QtQuick\nItem { broken syntax\n", encoding="utf-8")
        report = plugin_sdk.check_plugin(self.plugin_dir, use_qmllint=True)
        self.assertFalse(report["ok"])
        self.assertTrue(report["qmllint"])
        self.assertTrue(any("qmllint" in err for err in report["errors"]))


class PluginSdkWatchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.plugin_dir = self.root / "watch-demo"
        plugin_sdk.scaffold_plugin("watch-demo", self.plugin_dir)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_watch_once_dry_run_valid_and_invalid(self) -> None:
        output = StringIO()
        with redirect_stdout(output):
            rc = plugin_sdk.main(["watch", str(self.plugin_dir), "--once", "--dry-run"])
        self.assertEqual(rc, 0)
        self.assertIn("OK watch-demo", output.getvalue())
        self.assertIn("[dry-run] would run: qs ipc call plugins reload", output.getvalue())

        (self.plugin_dir / "manifest.json").write_text("{invalid", encoding="utf-8")
        errors = StringIO()
        out2 = StringIO()
        with redirect_stdout(out2), patch("sys.stderr", errors):
            rc2 = plugin_sdk.main(["watch", str(self.plugin_dir), "--once", "--dry-run"])
        self.assertEqual(rc2, 1)
        self.assertIn("FAIL", errors.getvalue())
        self.assertNotIn("qs ipc call plugins reload", out2.getvalue())

    def test_watch_detects_file_changes_and_triggers_reload_when_valid(self) -> None:
        calls: list[list[str]] = []

        def fake_run(cmd, **_kwargs):
            calls.append(list(cmd))
            return subprocess.CompletedProcess(cmd, 0, "", "")

        # Modify Main.qml between cycle 0 and cycle 1 so detect_changes fires.
        def on_cycle(cycle: int, _report: dict, _changed: list[str]) -> None:
            if cycle == 0:
                qml = self.plugin_dir / "Main.qml"
                qml.write_text(qml.read_text(encoding="utf-8") + "// touched\n", encoding="utf-8")
                now = time.time_ns() + 1_000_000_000
                os.utime(qml, ns=(now, now))

        out = StringIO()
        err = StringIO()
        with (
            patch.object(plugin_sdk.shutil, "which", side_effect=lambda name: "/usr/bin/qs" if name == "qs" else None),
            patch.object(plugin_sdk.subprocess, "run", side_effect=fake_run),
        ):
            rc = plugin_sdk.watch_plugin(
                self.plugin_dir,
                interval=0.01,
                max_cycles=2,
                dry_run=False,
                use_qmllint=False,
                on_cycle=on_cycle,
                out=out,
                err=err,
            )

        self.assertEqual(rc, 0)
        self.assertIn("changed: Main.qml", out.getvalue())
        self.assertEqual(
            calls,
            [
                ["/usr/bin/qs", "ipc", "call", "plugins", "reload"],
                ["/usr/bin/qs", "ipc", "call", "plugins", "reload"],
            ],
        )


if __name__ == "__main__":
    unittest.main()
