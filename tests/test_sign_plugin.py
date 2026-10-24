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
            json.dumps({"files": ["z.qml", "a.qml", "a.qml", "README.md", "LICENSE"]}),
            encoding="utf-8",
        )
        (self.plugin / "z.qml").write_bytes(b"z")
        (self.plugin / "a.qml").write_bytes(b"a")
        (self.plugin / "README.md").write_bytes(b"readme")
        (self.plugin / "LICENSE").write_bytes(b"license")

    def tearDown(self):
        self.temp.cleanup()

    def test_hashes_sorted_unique_paths_with_nul_framing(self):
        expected = hashlib.sha256(
            b"LICENSE\0license\0README.md\0readme\0a.qml\0a\0z.qml\0z\0"
        ).hexdigest()
        self.assertEqual(payload_sha256(self.plugin), expected)

    def test_rejects_parent_path(self):
        manifest = {"files": ["README.md", "LICENSE", "../outside.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unsafe manifest path"):
            payload_sha256(self.plugin)

    def test_rejects_windows_parent_path(self):
        manifest = {"files": ["README.md", "LICENSE", r"..\outside.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unsafe manifest path"):
            payload_sha256(self.plugin)

    def test_rejects_absolute_path(self):
        manifest = {"files": ["README.md", "LICENSE", "/etc/passwd"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unsafe manifest path"):
            payload_sha256(self.plugin)

    def test_rejects_symlink(self):
        target = self.plugin / "target.qml"
        target.write_bytes(b"target")
        (self.plugin / "link.qml").symlink_to(target)
        manifest = {"files": ["README.md", "LICENSE", "link.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not a regular file"):
            payload_sha256(self.plugin)

    def test_rejects_symlinked_parent_directory(self):
        target = self.plugin / "target"
        target.mkdir()
        (target / "plugin.qml").write_bytes(b"target")
        (self.plugin / "linked").symlink_to(target, target_is_directory=True)
        manifest = {"files": ["README.md", "LICENSE", "linked/plugin.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "not a regular file"):
            payload_sha256(self.plugin)

    def test_rejects_non_string_file_list(self):
        manifest = {"files": [3]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "list of relative paths"):
            payload_sha256(self.plugin)

    def test_rejects_noncanonical_path(self):
        manifest = {"files": ["README.md", "LICENSE", "./a.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "unsafe manifest path"):
            payload_sha256(self.plugin)

    def test_requires_package_documentation(self):
        manifest = {"files": ["a.qml", "z.qml"]}
        (self.plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "README.md and LICENSE"):
            payload_sha256(self.plugin)

    def test_rejects_non_object_manifest(self):
        (self.plugin / "manifest.json").write_text("null", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "JSON object"):
            payload_sha256(self.plugin)


if __name__ == "__main__":
    unittest.main()
