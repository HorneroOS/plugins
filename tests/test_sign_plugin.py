import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from scripts.sign_plugin import payload_sha256


class PayloadHashTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.plugin = Path(self.temp.name)
        (self.plugin / "manifest.json").write_text(
            json.dumps({"files": ["z.qml", "a.qml", "a.qml"]}), encoding="utf-8"
        )
        (self.plugin / "z.qml").write_bytes(b"z")
        (self.plugin / "a.qml").write_bytes(b"a")

    def tearDown(self):
        self.temp.cleanup()

    def test_hashes_sorted_unique_paths_with_nul_framing(self):
        expected = hashlib.sha256(b"a.qml\0a\0z.qml\0z\0").hexdigest()
        self.assertEqual(payload_sha256(self.plugin), expected)

    def test_rejects_parent_path(self):
        manifest = {"files": ["../outside.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unsafe manifest path"):
            payload_sha256(self.plugin)

    def test_rejects_absolute_path(self):
        manifest = {"files": ["/etc/passwd"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unsafe manifest path"):
            payload_sha256(self.plugin)

    def test_rejects_symlink(self):
        target = self.plugin / "target.qml"
        target.write_bytes(b"target")
        (self.plugin / "link.qml").symlink_to(target)
        manifest = {"files": ["link.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not a regular file"):
            payload_sha256(self.plugin)

    def test_rejects_symlinked_parent_directory(self):
        target = self.plugin / "target"
        target.mkdir()
        (target / "plugin.qml").write_bytes(b"target")
        (self.plugin / "linked").symlink_to(target, target_is_directory=True)
        manifest = {"files": ["linked/plugin.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not a regular file"):
            payload_sha256(self.plugin)

    def test_rejects_non_string_file_list(self):
        manifest = {"files": [3]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "list of relative paths"):
            payload_sha256(self.plugin)


if __name__ == "__main__":
    unittest.main()
