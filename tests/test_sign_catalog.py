from __future__ import annotations

import base64
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

import sign_catalog  # noqa: E402
import sign_plugin  # noqa: E402


# RFC 8032 Section 7.1 TEST 1 and TEST 2 official Ed25519 vectors.
RFC8032_VECTORS = [
    (
        bytes.fromhex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"),
        b"",
        bytes.fromhex(
            "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
            "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
        ),
    ),
    (
        bytes.fromhex("3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"),
        b"\x72",
        bytes.fromhex(
            "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da"
            "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
        ),
    ),
]


def _make_legacy_minisign_pair(pub32: bytes, sig64: bytes, key_id: bytes = b"\x01\x02\x03\x04\x05\x06\x07\x08") -> tuple[str, str]:
    pub_b64 = base64.b64encode(b"Ed" + key_id + pub32).decode("ascii")
    sig_b64 = base64.b64encode(b"Ed" + key_id + sig64).decode("ascii")
    return pub_b64, sig_b64


class Ed25519AndLegacyMinisignTests(unittest.TestCase):
    def test_rfc8032_vectors_pass_and_tampering_fails(self) -> None:
        for pub32, msg, sig64 in RFC8032_VECTORS:
            self.assertTrue(sign_catalog.ed25519_verify(pub32, msg, sig64))
            self.assertFalse(sign_catalog.ed25519_verify(pub32, msg + b"x", sig64))
            bad_sig = bytearray(sig64)
            bad_sig[0] ^= 0x01
            self.assertFalse(sign_catalog.ed25519_verify(pub32, msg, bytes(bad_sig)))

    def test_legacy_minisign_framing_matches_horneroctl_contract(self) -> None:
        pub32, msg, sig64 = RFC8032_VECTORS[1]
        pub_b64, sig_b64 = _make_legacy_minisign_pair(pub32, sig64)
        self.assertTrue(sign_catalog.verify_minisign_legacy_signature(pub_b64, sig_b64, msg))

        # Mismatched key ID must fail even with valid Ed25519 key+sig bytes.
        other_pub_b64, _ = _make_legacy_minisign_pair(pub32, sig64, key_id=b"\x99" * 8)
        self.assertFalse(sign_catalog.verify_minisign_legacy_signature(other_pub_b64, sig_b64, msg))

        # Prehashed `ED` algorithm tag must be rejected for legacy manifest signing.
        prehashed_sig = base64.b64encode(b"ED" + b"\x01\x02\x03\x04\x05\x06\x07\x08" + sig64).decode("ascii")
        self.assertFalse(sign_catalog.verify_minisign_legacy_signature(pub_b64, prehashed_sig, msg))


class CatalogProvenanceAndPayloadTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.plugin_dir = self.root / "plugins" / "sample-plugin"
        self.plugin_dir.mkdir(parents=True)
        (self.plugin_dir / "Main.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
        (self.plugin_dir / "README.md").write_text("# Sample\n", encoding="utf-8")
        (self.plugin_dir / "LICENSE").write_text("MIT\n", encoding="utf-8")
        manifest = {
            "schemaVersion": 3,
            "id": "sample-plugin",
            "name": "Sample Plugin",
            "version": "1.0.0",
            "description": "Sample",
            "author": "Test",
            "license": "MIT",
            "entrypoint": "Main.qml",
            "files": ["Main.qml", "README.md", "LICENSE"],
            "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        }
        (self.plugin_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        payload_hash = sign_catalog.gen_catalog.payload_sha256(self.plugin_dir, manifest)
        self.catalog_data = {
            "schemaVersion": 1,
            "generatedFrom": "a" * 40,
            "catalogSource": {
                "repo": sign_catalog.DEFAULT_REPO,
                "rev": "a" * 40,
            },
            "plugins": [
                {
                    "id": "sample-plugin",
                    "name": "Sample Plugin",
                    "version": "1.0.0",
                    "path": "plugins/sample-plugin",
                    "sha256": payload_hash,
                }
            ],
        }
        self.catalog_path = self.root / "catalog.json"
        self.catalog_path.write_text(json.dumps(self.catalog_data, indent=2) + "\n", encoding="utf-8")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_repo_catalog_passes_check(self) -> None:
        output = StringIO()
        with redirect_stdout(output):
            rc = sign_catalog.main(["--check", "--catalog", str(sign_catalog.DEFAULT_CATALOG)])
        self.assertEqual(rc, 0)
        self.assertIn("catalog check OK", output.getvalue())

    def test_check_catches_tampered_payload(self) -> None:
        (self.plugin_dir / "Main.qml").write_text("import QtQuick\nItem { width: 10 }\n", encoding="utf-8")
        errors = StringIO()
        with patch("sys.stderr", errors):
            rc = sign_catalog.main(["--check", "--catalog", str(self.catalog_path)])
        self.assertEqual(rc, 1)
        self.assertIn("payload SHA-256 mismatch", errors.getvalue())

    def test_check_catches_mismatched_catalog_source_rev(self) -> None:
        self.catalog_data["catalogSource"]["rev"] = "b" * 40
        self.catalog_path.write_text(json.dumps(self.catalog_data, indent=2) + "\n", encoding="utf-8")
        errors = StringIO()
        with patch("sys.stderr", errors):
            rc = sign_catalog.main(["--check", "--catalog", str(self.catalog_path)])
        self.assertEqual(rc, 1)
        self.assertIn("catalogSource.rev must match generatedFrom", errors.getvalue())

    def test_check_catches_duplicate_json_keys(self) -> None:
        self.catalog_path.write_text(
            '{"schemaVersion":1,"schemaVersion":1,"generatedFrom":"' + ("a" * 40) + '",'
            '"catalogSource":{"repo":"' + sign_catalog.DEFAULT_REPO + '","rev":"' + ("a" * 40) + '"},"plugins":[]}\n',
            encoding="utf-8",
        )
        errors = StringIO()
        with patch("sys.stderr", errors):
            rc = sign_catalog.main(["--check", "--catalog", str(self.catalog_path)])
        self.assertEqual(rc, 1)
        self.assertIn("duplicate JSON object key", errors.getvalue())

    def test_verify_parses_exact_snapshot_passed_to_minisign(self) -> None:
        sig_path = self.root / "catalog.json.minisig"
        pub_path = self.root / "catalog.pub"
        original_bytes = self.catalog_path.read_bytes()
        sig_path.write_text("untrusted comment: sig\ndetached\n", encoding="utf-8")
        pub_path.write_text("untrusted comment: pub\nRWtest\n", encoding="utf-8")

        def mutate_after_snapshot(cmd: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
            snap_catalog = Path(cmd[cmd.index("-m") + 1])
            self.assertEqual(snap_catalog.read_bytes(), original_bytes)
            # Mutate original path during verification to prove TOCTOU isolation.
            self.catalog_path.write_text('{"schemaVersion": 99}', encoding="utf-8")
            return subprocess.CompletedProcess(cmd, 0, "", "")

        output = StringIO()
        with (
            patch.object(sign_catalog.shutil, "which", return_value="/usr/bin/minisign"),
            patch.object(sign_catalog.subprocess, "run", side_effect=mutate_after_snapshot),
            redirect_stdout(output),
        ):
            rc = sign_catalog.main([
                "--verify",
                "--catalog", str(self.catalog_path),
                "--signature", str(sig_path),
                "--public-key", str(pub_path),
            ])
        self.assertEqual(rc, 0)
        self.assertIn("catalog signature and provenance verified: 1 plugins", output.getvalue())

    def test_verify_fails_closed_on_minisign_timeout(self) -> None:
        sig_path = self.root / "catalog.json.minisig"
        pub_path = self.root / "catalog.pub"
        sig_path.write_text("sig", encoding="utf-8")
        pub_path.write_text("pub", encoding="utf-8")
        errors = StringIO()
        with (
            patch.object(sign_catalog.shutil, "which", return_value="/usr/bin/minisign"),
            patch.object(
                sign_catalog.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired("minisign", 30),
            ),
            patch("sys.stderr", errors),
        ):
            rc = sign_catalog.main([
                "--verify",
                "--catalog", str(self.catalog_path),
                "--signature", str(sig_path),
                "--public-key", str(pub_path),
            ])
        self.assertEqual(rc, 1)
        self.assertIn("timed out", errors.getvalue())

    def test_plugin_verify_and_check_handle_unsigned_and_bad_signature(self) -> None:
        # --check allows unsigned plugins unless --require-signature is set.
        output = StringIO()
        with redirect_stdout(output):
            rc = sign_catalog.main(["--plugin", str(self.plugin_dir), "--check"])
        self.assertEqual(rc, 0)
        self.assertIn("plugin unsigned", output.getvalue())

        errors = StringIO()
        with patch("sys.stderr", errors):
            rc = sign_catalog.main(["--plugin", str(self.plugin_dir), "--verify"])
        self.assertEqual(rc, 1)
        self.assertIn("no signing block", errors.getvalue())

        # Present-but-invalid signature fails closed in both --check and --verify.
        manifest = json.loads((self.plugin_dir / "manifest.json").read_text(encoding="utf-8"))
        manifest["signing"] = {
            "publicKey": base64.b64encode(b"Ed" + b"\x01" * 8 + RFC8032_VECTORS[0][0]).decode("ascii"),
            "signature": base64.b64encode(b"Ed" + b"\x01" * 8 + RFC8032_VECTORS[0][2]).decode("ascii"),
        }
        (self.plugin_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        with patch("sys.stderr", errors):
            rc = sign_catalog.main(["--plugin", str(self.plugin_dir), "--check"])
        self.assertEqual(rc, 1)
        self.assertIn("bad-signature", errors.getvalue())

    def test_regular_file_reader_rejects_fifo(self) -> None:
        fifo = self.root / "pipe"
        os.mkfifo(fifo)
        with self.assertRaisesRegex(sign_catalog.SigningError, "not a regular file"):
            sign_catalog.read_regular_file(fifo, 1024)


class EphemeralMinisignIntegrationTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("minisign"), "minisign is installed in CI for ephemeral signing tests")
    def test_sign_and_verify_catalog_and_plugin_with_ephemeral_keys(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            plugin_dir = root / "plugins" / "ephemeral-plugin"
            plugin_dir.mkdir(parents=True)
            (plugin_dir / "Main.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
            (plugin_dir / "README.md").write_text("# Ephemeral\n", encoding="utf-8")
            (plugin_dir / "LICENSE").write_text("MIT\n", encoding="utf-8")
            manifest = {
                "schemaVersion": 3,
                "id": "ephemeral-plugin",
                "name": "Ephemeral",
                "version": "1.0.0",
                "description": "Test",
                "author": "CI",
                "license": "MIT",
                "entrypoint": "Main.qml",
                "files": ["Main.qml", "README.md", "LICENSE"],
                "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
            }
            (plugin_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

            secret = root / "test.key"
            public = root / "test.pub"
            subprocess.run(
                ["minisign", "-G", "-s", str(secret), "-p", str(public), "-W"],
                cwd=root,
                check=True,
                capture_output=True,
            )

            # 1. Author-sign the plugin files-only hash with -Sl and write manifest["signing"].
            rc = sign_catalog.main([
                "--plugin", str(plugin_dir),
                "--sign",
                "--secret-key", str(secret),
                "--public-key", str(public),
                "--write-manifest",
            ])
            self.assertEqual(rc, 0)
            self.assertEqual(sign_catalog.main(["--plugin", str(plugin_dir), "--verify"]), 0)

            # 2. Sign catalog.json with the signed manifest now included in catalog sha256.
            updated_manifest = json.loads((plugin_dir / "manifest.json").read_text(encoding="utf-8"))
            catalog_data = {
                "schemaVersion": 1,
                "generatedFrom": "a" * 40,
                "catalogSource": {"repo": sign_catalog.DEFAULT_REPO, "rev": "a" * 40},
                "plugins": [{
                    "id": "ephemeral-plugin",
                    "name": "Ephemeral",
                    "version": "1.0.0",
                    "path": "plugins/ephemeral-plugin",
                    "sha256": sign_catalog.gen_catalog.payload_sha256(plugin_dir, updated_manifest),
                }],
            }
            catalog_path = root / "catalog.json"
            sig_path = root / "catalog.json.minisig"
            catalog_path.write_text(json.dumps(catalog_data, indent=2) + "\n", encoding="utf-8")

            self.assertEqual(
                sign_catalog.main([
                    "--sign",
                    "--catalog", str(catalog_path),
                    "--signature", str(sig_path),
                    "--secret-key", str(secret),
                ]),
                0,
            )
            self.assertEqual(
                sign_catalog.main([
                    "--verify",
                    "--catalog", str(catalog_path),
                    "--signature", str(sig_path),
                    "--public-key", str(public),
                    "--check-payloads",
                ]),
                0,
            )

            # Tampering with a plugin file invalidates both --plugin --verify and --check-payloads.
            (plugin_dir / "Main.qml").write_text("import QtQuick\nItem { opacity: 0.5 }\n", encoding="utf-8")
            self.assertEqual(sign_catalog.main(["--plugin", str(plugin_dir), "--verify"]), 1)
            self.assertEqual(
                sign_catalog.main([
                    "--verify",
                    "--catalog", str(catalog_path),
                    "--signature", str(sig_path),
                    "--public-key", str(public),
                    "--check-payloads",
                ]),
                1,
            )

            # Tampering with catalog.json invalidates detached Minisign verification.
            catalog_path.write_text(
                catalog_path.read_text(encoding="utf-8").replace("1.0.0", "1.0.1"),
                encoding="utf-8",
            )
            self.assertEqual(
                sign_catalog.main([
                    "--verify",
                    "--catalog", str(catalog_path),
                    "--signature", str(sig_path),
                    "--public-key", str(public),
                ]),
                1,
            )


if __name__ == "__main__":
    unittest.main()
