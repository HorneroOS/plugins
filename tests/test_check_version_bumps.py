import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "check_version_bumps.py"


def git(root, *args):
    subprocess.run(["git", "-C", str(root), "-c", "user.email=t@t", "-c", "user.name=t", *args],
                   check=True, capture_output=True)


class VersionBumpGate(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="bump-gate-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        (self.tmp / "scripts").mkdir()
        shutil.copy(SCRIPT, self.tmp / "scripts" / SCRIPT.name)
        plugin = self.tmp / "plugins" / "demo"
        plugin.mkdir(parents=True)
        (plugin / "manifest.json").write_text(json.dumps({"id": "demo", "version": "1.0.0", "files": ["Main.qml", "README.md"]}))
        (plugin / "Main.qml").write_text("Item {}\n")
        (plugin / "README.md").write_text("demo\n")
        (plugin / "notes.txt").write_text("not shipped\n")
        git(self.tmp, "init", "-q", "-b", "main")
        git(self.tmp, "add", "-A")
        git(self.tmp, "commit", "-qm", "base")
        git(self.tmp, "checkout", "-qb", "topic")

    def run_gate(self):
        return subprocess.run([sys.executable, str(self.tmp / "scripts" / SCRIPT.name), "--base", "main"],
                              capture_output=True, text=True)

    def test_payload_change_without_bump_fails(self):
        (self.tmp / "plugins" / "demo" / "Main.qml").write_text("Item { width: 1 }\n")
        git(self.tmp, "commit", "-qam", "edit")
        result = self.run_gate()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("demo", result.stderr)

    def test_bump_passes(self):
        (self.tmp / "plugins" / "demo" / "Main.qml").write_text("Item { width: 1 }\n")
        manifest = self.tmp / "plugins" / "demo" / "manifest.json"
        data = json.loads(manifest.read_text())
        data["version"] = "1.0.1"
        manifest.write_text(json.dumps(data))
        git(self.tmp, "commit", "-qam", "edit")
        self.assertEqual(self.run_gate().returncode, 0)

    def test_unshipped_file_change_passes(self):
        (self.tmp / "plugins" / "demo" / "notes.txt").write_text("changed\n")
        git(self.tmp, "commit", "-qam", "notes")
        self.assertEqual(self.run_gate().returncode, 0)


if __name__ == "__main__":
    unittest.main()
