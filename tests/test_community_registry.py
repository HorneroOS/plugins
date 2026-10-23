from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

from community_registry import RegistryError, build_index, json_text, load_sources  # noqa: E402
import verify_community_index  # noqa: E402


class CommunityRegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "community").mkdir()
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.email", "registry-test@example.invalid"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.name", "Registry Test"], cwd=self.root, check=True)
        self.sources = self.root / "community/registry-sources.json"
        self.write_sources({"schemaVersion": 1, "indexVersion": 1, "plugins": []})
        self.commit_sources()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_sources(self, value: dict) -> None:
        self.sources.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

    def commit_sources(self) -> str:
        subprocess.run(["git", "add", "community/registry-sources.json"], cwd=self.root, check=True)
        subprocess.run(["git", "commit", "-qm", "registry source fixture"], cwd=self.root, check=True)
        return subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=self.root, check=True, capture_output=True, text=True
        ).stdout.strip()

    @staticmethod
    def source_entry(plugin_id: str, key_byte: int = 1) -> dict:
        import base64

        raw_key = b"Ed" + bytes([key_byte]) * 8 + bytes([key_byte + 1]) * 32
        return {
            "id": plugin_id,
            "repository": f"https://github.com/example/{plugin_id}.git",
            "revision": "a" * 40,
            "sha256": "b" * 64,
            "authorPublicKey": base64.b64encode(raw_key).decode("ascii"),
        }

    def test_build_is_sorted_and_binds_full_revision_hash_and_author_fingerprint(self) -> None:
        source = {"schemaVersion": 1, "indexVersion": 7, "plugins": [
            self.source_entry("zulu"), self.source_entry("alpha", 2)
        ]}
        self.write_sources(source)
        revision = self.commit_sources()

        index = build_index(self.root)

        self.assertEqual(index["generatedFrom"], revision)
        self.assertEqual(index["indexVersion"], 7)
        self.assertEqual([entry["id"] for entry in index["plugins"]], ["alpha", "zulu"])
        self.assertEqual(index["plugins"][0]["revision"], "a" * 40)
        self.assertEqual(index["plugins"][0]["sha256"], "b" * 64)
        self.assertRegex(index["plugins"][0]["authorKeyFingerprint"], r"^sha256:[0-9a-f]{64}$")
        self.assertEqual(json_text(index), json_text(build_index(self.root)))

    def test_duplicate_ids_are_rejected(self) -> None:
        self.write_sources({"schemaVersion": 1, "indexVersion": 1, "plugins": [
            self.source_entry("same"), self.source_entry("same", 2)
        ]})
        with self.assertRaisesRegex(RegistryError, "unique"):
            load_sources(self.sources)

    def test_duplicate_json_object_keys_are_rejected(self) -> None:
        self.sources.write_text(
            '{"schemaVersion":1,"indexVersion":1,"indexVersion":999,"plugins":[]}\n',
            encoding="utf-8",
        )
        with self.assertRaisesRegex(RegistryError, "duplicate JSON object key: indexVersion"):
            load_sources(self.sources)

    def test_generator_refuses_uncommitted_source_bytes(self) -> None:
        source = {"schemaVersion": 1, "indexVersion": 2, "plugins": []}
        self.write_sources(source)
        with self.assertRaisesRegex(RegistryError, "differs from its committed revision"):
            build_index(self.root)

    def test_mutable_or_abbreviated_revisions_are_rejected(self) -> None:
        entry = self.source_entry("moving")
        entry["revision"] = "main"
        self.write_sources({"schemaVersion": 1, "indexVersion": 1, "plugins": [entry]})
        with self.assertRaisesRegex(RegistryError, "full lowercase"):
            load_sources(self.sources)
        entry["revision"] = "a" * 12
        self.write_sources({"schemaVersion": 1, "indexVersion": 1, "plugins": [entry]})
        with self.assertRaisesRegex(RegistryError, "full lowercase"):
            load_sources(self.sources)

    def test_unknown_fields_and_untrusted_repository_hosts_are_rejected(self) -> None:
        source = {"schemaVersion": 1, "indexVersion": 1, "plugins": [self.source_entry("plugin")]}
        source["plugins"][0]["branch"] = "main"
        self.write_sources(source)
        with self.assertRaisesRegex(RegistryError, "exactly"):
            load_sources(self.sources)
        entry = self.source_entry("plugin")
        entry["repository"] = "https://attacker.example/plugin"
        self.write_sources({"schemaVersion": 1, "indexVersion": 1, "plugins": [entry]})
        with self.assertRaisesRegex(RegistryError, "github.com, codeberg.org, or gitlab.com"):
            load_sources(self.sources)

    def test_invalid_index_version_and_public_key_are_rejected(self) -> None:
        self.write_sources({"schemaVersion": 1, "indexVersion": True, "plugins": []})
        with self.assertRaisesRegex(RegistryError, "positive integer"):
            load_sources(self.sources)
        entry = self.source_entry("plugin")
        entry["authorPublicKey"] = "RWinvalid"
        self.write_sources({"schemaVersion": 1, "indexVersion": 1, "plugins": [entry]})
        with self.assertRaisesRegex(RegistryError, "canonical minisign public key"):
            load_sources(self.sources)

    def test_verifier_parses_the_exact_bytes_passed_to_minisign(self) -> None:
        index_path = self.root / "index.json"
        signature_path = self.root / "index.json.minisig"
        public_key_path = self.root / "registry.pub"
        original = json_text({
            "schemaVersion": 1,
            "indexVersion": 5,
            "generatedFrom": "a" * 40,
            "plugins": [],
        }).encode("utf-8")
        index_path.write_bytes(original)
        signature_path.write_text("detached signature", encoding="utf-8")
        public_key_path.write_text("trusted public key", encoding="utf-8")

        def replace_caller_file(command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
            verified_snapshot = Path(command[command.index("-m") + 1])
            self.assertEqual(verified_snapshot.read_bytes(), original)
            index_path.write_text(
                json_text({
                    "schemaVersion": 1,
                    "indexVersion": 999,
                    "generatedFrom": "b" * 40,
                    "plugins": [],
                }),
                encoding="utf-8",
            )
            return subprocess.CompletedProcess(command, 0, "", "")

        output = StringIO()
        with (
            patch.object(verify_community_index.shutil, "which", return_value="/usr/bin/minisign"),
            patch.object(verify_community_index.subprocess, "run", side_effect=replace_caller_file),
            patch.object(sys, "argv", [
                "verify_community_index.py",
                "--index", str(index_path),
                "--signature", str(signature_path),
                "--public-key", str(public_key_path),
            ]),
            redirect_stdout(output),
        ):
            result = verify_community_index.main()

        self.assertEqual(result, 0)
        self.assertIn("version 5", output.getvalue())

    def test_regular_file_reader_does_not_block_on_a_fifo(self) -> None:
        fifo = self.root / "index.fifo"
        os.mkfifo(fifo)

        with self.assertRaisesRegex(RegistryError, "not a regular file"):
            verify_community_index._read_regular_file(fifo, 1024)

    def test_verifier_fails_closed_when_minisign_times_out(self) -> None:
        index_path = self.root / "index.json"
        signature_path = self.root / "index.json.minisig"
        public_key_path = self.root / "registry.pub"
        index_path.write_text(json_text({
            "schemaVersion": 1,
            "indexVersion": 5,
            "generatedFrom": "a" * 40,
            "plugins": [],
        }), encoding="utf-8")
        signature_path.write_text("detached signature", encoding="utf-8")
        public_key_path.write_text("trusted public key", encoding="utf-8")
        errors = StringIO()

        with (
            patch.object(verify_community_index.shutil, "which", return_value="/usr/bin/minisign"),
            patch.object(
                verify_community_index.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired("minisign", 30),
            ),
            patch.object(sys, "argv", [
                "verify_community_index.py",
                "--index", str(index_path),
                "--signature", str(signature_path),
                "--public-key", str(public_key_path),
            ]),
            patch("sys.stderr", errors),
        ):
            result = verify_community_index.main()

        self.assertEqual(result, 1)
        self.assertIn("signature verification timed out", errors.getvalue())

    @unittest.skipUnless(shutil.which("minisign"), "minisign is installed in CI for detached-signature tests")
    def test_detached_signature_is_verified_before_payload_is_accepted(self) -> None:
        index_path = self.root / "index.json"
        signature_path = self.root / "index.json.minisig"
        secret_key = self.root / "registry.key"
        public_key = self.root / "registry.pub"
        (self.root / "community/registry-sources.json").write_text(
            json_text({"schemaVersion": 1, "indexVersion": 3, "plugins": []}), encoding="utf-8"
        )
        self.commit_sources()
        index_path.write_text(json_text(build_index(self.root)), encoding="utf-8")
        subprocess.run(["minisign", "-G", "-s", str(secret_key), "-p", str(public_key), "-W"], cwd=self.root, check=True, capture_output=True)
        subprocess.run(["minisign", "-S", "-s", str(secret_key), "-m", str(index_path), "-x", str(signature_path)], cwd=self.root, check=True, capture_output=True)
        verifier = Path(__file__).resolve().parents[1] / "scripts/verify_community_index.py"
        valid = subprocess.run([
            sys.executable, str(verifier), "--index", str(index_path), "--signature", str(signature_path),
            "--public-key", str(public_key), "--minimum-version", "3"
        ], capture_output=True, text=True)
        self.assertEqual(valid.returncode, 0, valid.stderr)

        other_secret_key = self.root / "other.key"
        other_public_key = self.root / "other.pub"
        subprocess.run(["minisign", "-G", "-s", str(other_secret_key), "-p", str(other_public_key), "-W"], cwd=self.root, check=True, capture_output=True)
        unknown_key = subprocess.run([
            sys.executable, str(verifier), "--index", str(index_path), "--signature", str(signature_path),
            "--public-key", str(other_public_key)
        ], capture_output=True, text=True)
        self.assertNotEqual(unknown_key.returncode, 0)

        signature_path.unlink()
        missing_signature = subprocess.run([
            sys.executable, str(verifier), "--index", str(index_path), "--signature", str(signature_path),
            "--public-key", str(public_key)
        ], capture_output=True, text=True)
        self.assertNotEqual(missing_signature.returncode, 0)
        subprocess.run(["minisign", "-S", "-s", str(secret_key), "-m", str(index_path), "-x", str(signature_path)], cwd=self.root, check=True, capture_output=True)

        duplicate_key_payload = '{"schemaVersion":1,"schemaVersion":1,"indexVersion":3,"generatedFrom":"' + build_index(self.root)["generatedFrom"] + '","plugins":[]}\n'
        index_path.write_text(duplicate_key_payload, encoding="utf-8")
        signature_path.unlink(missing_ok=True)
        subprocess.run(["minisign", "-S", "-s", str(secret_key), "-m", str(index_path), "-x", str(signature_path)], cwd=self.root, check=True, capture_output=True)
        duplicate_key = subprocess.run([
            sys.executable, str(verifier), "--index", str(index_path), "--signature", str(signature_path),
            "--public-key", str(public_key)
        ], capture_output=True, text=True)
        self.assertNotEqual(duplicate_key.returncode, 0)
        self.assertIn("duplicate JSON object key", duplicate_key.stderr)

        index_path.write_text(json_text(build_index(self.root)), encoding="utf-8")
        signature_path.unlink(missing_ok=True)
        subprocess.run(["minisign", "-S", "-s", str(secret_key), "-m", str(index_path), "-x", str(signature_path)], cwd=self.root, check=True, capture_output=True)
        index_path.write_text(index_path.read_text(encoding="utf-8").replace('"indexVersion": 3', '"indexVersion": 2'), encoding="utf-8")
        tampered = subprocess.run([
            sys.executable, str(verifier), "--index", str(index_path), "--signature", str(signature_path),
            "--public-key", str(public_key)
        ], capture_output=True, text=True)
        self.assertNotEqual(tampered.returncode, 0)

        index_path.write_text(json_text(build_index(self.root)), encoding="utf-8")
        stale = subprocess.run([
            sys.executable, str(verifier), "--index", str(index_path), "--signature", str(signature_path),
            "--public-key", str(public_key), "--minimum-version", "4"
        ], capture_output=True, text=True)
        self.assertNotEqual(stale.returncode, 0)


if __name__ == "__main__":
    unittest.main()
