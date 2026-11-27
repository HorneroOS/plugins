#!/usr/bin/env python3
"""Minisign signing and verification for HorneroOS catalog.json and plugins.

Supports two complementary contracts used by HorneroOS/plugins and horneroctl:

1. Official catalogue (`catalog.json` + detached `catalog.json.minisig`):
   - Signs and verifies the exact `catalog.json` bytes using standard detached
     Minisign signatures (`minisign -S` / `minisign -V`).
   - Validates `generatedFrom`, `catalogSource` (`repo` and `rev`), strict
     JSON (rejecting duplicate object keys), and every entry's canonical
     payload SHA-256 (`manifest.json` + sorted `files`, NUL-framed, matching
     `scripts/gen_catalog.py:payload_sha256` and `horneroctl`'s
     `plugin_payload_sha256`).

2. Author plugin signatures (`plugins/<id>/manifest.json["signing"]`):
   - Signs the files-only payload hash (`scripts/sign_plugin.py:payload_sha256`,
     matching `horneroctl`'s `plugin_files_sha256`) using `minisign -Sl` legacy
     Ed25519 framing (`Ed` + 8-byte key id + 64-byte signature).
   - Verifies `manifest.json["signing"]` in pure Python stdlib (matching
     `horneroctl`'s `minisign_verify`) with zero external dependencies.

Usage:
  python3 scripts/sign_catalog.py --check
  python3 scripts/sign_catalog.py --sign --secret-key path/to/catalog.key
  python3 scripts/sign_catalog.py --verify --public-key path/to/catalog.pub
  python3 scripts/sign_catalog.py --plugin plugins/my-plugin --verify
  python3 scripts/sign_catalog.py --plugin plugins/my-plugin --sign --secret-key author.key
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from community_registry import RegistryError, strict_json_loads  # noqa: E402
import gen_catalog  # noqa: E402
import sign_plugin  # noqa: E402

ROOT = SCRIPTS_DIR.parent
DEFAULT_CATALOG = ROOT / "catalog.json"
DEFAULT_REPO = "https://github.com/HorneroOS/plugins"

COMMIT_RE = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

MAX_CATALOG_BYTES = 16 * 1024 * 1024
MAX_SIGNATURE_BYTES = 4 * 1024
MAX_PUBLIC_KEY_BYTES = 1024
MINISIGN_TIMEOUT_SECONDS = 30

# RFC 8032 Ed25519 curve constants for verifying Minisign legacy `Ed` signatures
# in pure Python stdlib (matching horneroctl's `minisign_verify`).
_Q = 2**255 - 19
_L = 2**252 + 27742317777372353535851937790883648493
_D = (-121665 * pow(121666, _Q - 2, _Q)) % _Q
_I = pow(2, (_Q - 1) // 4, _Q)
_BY = (4 * pow(5, _Q - 2, _Q)) % _Q
_BX_SQ = ((_BY * _BY - 1) * pow(_D * _BY * _BY + 1, _Q - 2, _Q)) % _Q
_BX = pow(_BX_SQ, (_Q + 3) // 8, _Q)
if (_BX * _BX - _BX_SQ) % _Q != 0:
    _BX = (_BX * _I) % _Q
if _BX % 2 != 0:
    _BX = _Q - _BX
_BASE_POINT = (_BX, _BY, 1, (_BX * _BY) % _Q)


class SigningError(ValueError):
    """Raised when catalog or signature verification fails."""


def _edwards_add(
    p: tuple[int, int, int, int], q: tuple[int, int, int, int]
) -> tuple[int, int, int, int]:
    x1, y1, z1, t1 = p
    x2, y2, z2, t2 = q
    a = ((y1 - x1) * (y2 - x2)) % _Q
    b = ((y1 + x1) * (y2 + x2)) % _Q
    c = (2 * t1 * t2 * _D) % _Q
    d = (2 * z1 * z2) % _Q
    e = (b - a) % _Q
    f = (d - c) % _Q
    g = (d + c) % _Q
    h = (b + a) % _Q
    return ((e * f) % _Q, (g * h) % _Q, (f * g) % _Q, (e * h) % _Q)


def _edwards_double(p: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x1, y1, z1, _ = p
    a = (x1 * x1) % _Q
    b = (y1 * y1) % _Q
    c = (2 * z1 * z1) % _Q
    h = (a + b) % _Q
    e = (h - ((x1 + y1) * (x1 + y1)) % _Q) % _Q
    g = (a - b) % _Q
    f = (c + g) % _Q
    return ((e * f) % _Q, (g * h) % _Q, (f * g) % _Q, (e * h) % _Q)


def _scalarmult(p: tuple[int, int, int, int], e: int) -> tuple[int, int, int, int]:
    acc = (0, 1, 1, 0)
    addend = p
    while e > 0:
        if e & 1:
            acc = _edwards_add(acc, addend)
        addend = _edwards_double(addend)
        e >>= 1
    return acc


def _decode_point(encoded: bytes) -> tuple[int, int, int, int] | None:
    if len(encoded) != 32:
        return None
    y = int.from_bytes(encoded, "little") & ((1 << 255) - 1)
    if y >= _Q:
        return None
    sign = (encoded[31] >> 7) & 1
    u = (y * y - 1) % _Q
    v = (_D * y * y + 1) % _Q
    xx = (u * pow(v, _Q - 2, _Q)) % _Q
    x = pow(xx, (_Q + 3) // 8, _Q)
    if (v * x * x - u) % _Q != 0:
        x = (x * _I) % _Q
        if (v * x * x - u) % _Q != 0:
            return None
    if x == 0 and sign == 1:
        return None
    if (x & 1) != sign:
        x = _Q - x
    return (x, y, 1, (x * y) % _Q)


def _encode_point(p: tuple[int, int, int, int]) -> bytes:
    zinv = pow(p[2], _Q - 2, _Q)
    x = (p[0] * zinv) % _Q
    y = (p[1] * zinv) % _Q
    out = bytearray(y.to_bytes(32, "little"))
    out[31] |= (x & 1) << 7
    return bytes(out)


def ed25519_verify(public_key: bytes, message: bytes, signature: bytes) -> bool:
    """Verify an RFC 8032 Ed25519 signature using Python stdlib only."""
    if len(public_key) != 32 or len(signature) != 64:
        return False
    a_point = _decode_point(public_key)
    r_bytes = signature[:32]
    r_point = _decode_point(r_bytes)
    if a_point is None or r_point is None:
        return False
    s = int.from_bytes(signature[32:], "little")
    if s >= _L:
        return False
    digest = hashlib.sha512(r_bytes + public_key + message).digest()
    k = int.from_bytes(digest, "little") % _L
    lhs = _encode_point(_scalarmult(_BASE_POINT, s))
    rhs = _encode_point(_edwards_add(r_point, _scalarmult(a_point, k)))
    return lhs == rhs


def extract_minisign_public_key(pub_text: str) -> str:
    """Extract the RW... base64 public key line from a Minisign .pub file or string."""
    for raw_line in pub_text.splitlines():
        line = raw_line.strip()
        if line and not line.startswith("untrusted comment:"):
            return line
    raise SigningError("minisign public key text is empty")


def parse_minisign_public_key(public_key_b64: str) -> tuple[bytes, bytes]:
    """Decode a canonical 42-byte Minisign Ed public key into (key_id, pub32)."""
    try:
        raw = base64.b64decode(public_key_b64, validate=True)
    except ValueError as exc:
        raise SigningError(f"invalid base64 in minisign public key: {exc}") from exc
    if len(raw) != 42 or raw[:2] != b"Ed" or base64.b64encode(raw).decode("ascii") != public_key_b64:
        raise SigningError("minisign public key must encode 42 bytes starting with 'Ed'")
    return raw[2:10], raw[10:]


def extract_minisign_signature_line(minisig_text: str) -> str:
    """Extract the base64 signature line (line 2) from a .minisig file."""
    lines = minisig_text.splitlines()
    if len(lines) < 2 or not lines[0].startswith("untrusted comment:"):
        raise SigningError("malformed .minisig file")
    return lines[1].strip()


def verify_minisign_legacy_signature(public_key_b64: str, signature_b64: str, message: bytes) -> bool:
    """Verify a Minisign legacy `Ed` signature (horneroctl `minisign_verify` contract)."""
    try:
        key_id, pub32 = parse_minisign_public_key(public_key_b64)
        sig_raw = base64.b64decode(signature_b64, validate=True)
    except (SigningError, ValueError):
        return False
    if len(sig_raw) != 74 or sig_raw[:2] != b"Ed":
        return False
    if base64.b64encode(sig_raw).decode("ascii") != signature_b64:
        return False
    if sig_raw[2:10] != key_id:
        return False
    return ed25519_verify(pub32, message, sig_raw[10:])


def read_regular_file(path: Path, maximum: int) -> bytes:
    """Read one bounded, non-symlink regular file snapshot."""
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    try:
        descriptor = os.open(path, flags)
        with os.fdopen(descriptor, "rb") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                raise SigningError(f"required path is not a regular file: {path}")
            content = stream.read(maximum + 1)
    except OSError as exc:
        raise SigningError(f"cannot read regular file {path}: {exc}") from exc
    if len(content) > maximum:
        raise SigningError(f"file exceeds the {maximum}-byte limit: {path}")
    return content


def validate_catalog_data(catalog: dict, expected_repo: str = DEFAULT_REPO) -> None:
    """Validate catalog.json structure, generatedFrom, catalogSource, and entry fields."""
    if catalog.get("schemaVersion") != 1:
        raise SigningError(f"unsupported catalog schemaVersion: {catalog.get('schemaVersion')!r}")
    generated_from = catalog.get("generatedFrom")
    if not isinstance(generated_from, str) or not COMMIT_RE.fullmatch(generated_from):
        raise SigningError("generatedFrom must be a full lowercase commit id")
    source = catalog.get("catalogSource")
    if not isinstance(source, dict) or set(source) != {"repo", "rev"}:
        raise SigningError("catalogSource must contain exactly repo and rev")
    if source.get("repo") != expected_repo:
        raise SigningError(f"catalogSource.repo must equal {expected_repo!r}, got {source.get('repo')!r}")
    if source.get("rev") != generated_from:
        raise SigningError("catalogSource.rev must match generatedFrom")
    plugins = catalog.get("plugins")
    if not isinstance(plugins, list):
        raise SigningError("catalog plugins must be a JSON array")
    seen_ids: set[str] = set()
    for index, entry in enumerate(plugins):
        where = f"plugins[{index}]"
        if not isinstance(entry, dict):
            raise SigningError(f"{where} must be a JSON object")
        pid = entry.get("id")
        if not isinstance(pid, str) or not pid:
            raise SigningError(f"{where}.id must be a non-empty string")
        if pid in seen_ids:
            raise SigningError(f"duplicate catalog plugin id: {pid}")
        seen_ids.add(pid)
        rel_path = entry.get("path")
        if not isinstance(rel_path, str) or rel_path != f"plugins/{pid}":
            raise SigningError(f"{where}.path must equal plugins/{pid}")
        digest = entry.get("sha256")
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            raise SigningError(f"{where}.sha256 must be a lowercase 64-char SHA-256 hex digest")


def verify_catalog_payloads(catalog: dict, root: Path) -> int:
    """Verify every catalog entry's canonical payload SHA-256 against plugins/ on disk."""
    plugins = catalog["plugins"]
    for entry in plugins:
        pid = entry["id"]
        plugin_dir = root / entry["path"]
        if not plugin_dir.is_dir():
            raise SigningError(f"{pid}: plugin directory missing at {entry['path']}")
        manifest_path = plugin_dir / "manifest.json"
        if manifest_path.is_symlink() or not manifest_path.is_file():
            raise SigningError(f"{pid}: manifest.json missing or not a regular file")
        try:
            manifest = strict_json_loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError, RegistryError) as exc:
            raise SigningError(f"{pid}: unreadable manifest.json: {exc}") from exc
        if not isinstance(manifest, dict):
            raise SigningError(f"{pid}: manifest.json must be a JSON object")
        if manifest.get("id") != pid:
            raise SigningError(f"{pid}: manifest id {manifest.get('id')!r} does not match catalog id")
        if manifest.get("version") != entry.get("version"):
            raise SigningError(
                f"{pid}: manifest version {manifest.get('version')!r} != catalog version {entry.get('version')!r}"
            )
        # Validate listed files safely via sign_plugin's path checks, then hash
        # manifest.json + sorted files via gen_catalog.payload_sha256.
        sign_plugin.payload_sha256(plugin_dir)
        actual = gen_catalog.payload_sha256(plugin_dir, manifest)
        if actual != entry["sha256"]:
            raise SigningError(
                f"{pid}: payload SHA-256 mismatch (catalog {entry['sha256']}, computed {actual})"
            )
    return len(plugins)


def parse_strict_catalog(catalog_bytes: bytes, expected_repo: str = DEFAULT_REPO) -> dict:
    try:
        decoded = strict_json_loads(catalog_bytes.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError, RegistryError) as exc:
        raise SigningError(f"invalid catalog JSON: {exc}") from exc
    if not isinstance(decoded, dict):
        raise SigningError("catalog must contain a JSON object")
    validate_catalog_data(decoded, expected_repo=expected_repo)
    return decoded


def sign_catalog_file(
    catalog_path: Path,
    signature_path: Path,
    secret_key_path: Path,
    expected_repo: str = DEFAULT_REPO,
) -> dict:
    """Validate catalog.json and create a detached Minisign signature."""
    minisign = shutil.which("minisign")
    if minisign is None:
        raise SigningError("minisign binary is required to sign catalog.json")
    catalog_bytes = read_regular_file(catalog_path, MAX_CATALOG_BYTES)
    catalog = parse_strict_catalog(catalog_bytes, expected_repo=expected_repo)
    if secret_key_path.is_symlink() or not secret_key_path.is_file():
        raise SigningError(f"secret key must be a regular file: {secret_key_path}")
    with tempfile.TemporaryDirectory(prefix="hornero-catalog-sign-") as temp_dir:
        snap = Path(temp_dir)
        catalog_snap = snap / "catalog.json"
        sig_snap = snap / "catalog.json.minisig"
        catalog_snap.write_bytes(catalog_bytes)
        try:
            result = subprocess.run(
                [minisign, "-S", "-s", str(secret_key_path), "-m", str(catalog_snap), "-x", str(sig_snap)],
                capture_output=True,
                text=True,
                check=False,
                timeout=MINISIGN_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            raise SigningError("minisign signing timed out") from exc
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "minisign signing failed"
            raise SigningError(detail)
        sig_bytes = sig_snap.read_bytes()
    signature_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_sig = signature_path.with_name(f".{signature_path.name}.tmp-{os.getpid()}")
    tmp_sig.write_bytes(sig_bytes)
    os.chmod(tmp_sig, 0o644)
    os.replace(tmp_sig, signature_path)
    return catalog


def verify_catalog_signature(
    catalog_path: Path,
    signature_path: Path,
    public_key_path: Path,
    expected_repo: str = DEFAULT_REPO,
) -> dict:
    """Verify a detached Minisign signature over catalog.json before parsing."""
    catalog_bytes = read_regular_file(catalog_path, MAX_CATALOG_BYTES)
    sig_bytes = read_regular_file(signature_path, MAX_SIGNATURE_BYTES)
    pub_bytes = read_regular_file(public_key_path, MAX_PUBLIC_KEY_BYTES)
    minisign = shutil.which("minisign")
    if minisign is None:
        raise SigningError("minisign binary is required to verify the detached catalog signature")
    with tempfile.TemporaryDirectory(prefix="hornero-catalog-verify-") as temp_dir:
        snap = Path(temp_dir)
        catalog_snap = snap / "catalog.json"
        sig_snap = snap / "catalog.json.minisig"
        pub_snap = snap / "catalog.pub"
        catalog_snap.write_bytes(catalog_bytes)
        sig_snap.write_bytes(sig_bytes)
        pub_snap.write_bytes(pub_bytes)
        try:
            result = subprocess.run(
                [minisign, "-V", "-m", str(catalog_snap), "-x", str(sig_snap), "-p", str(pub_snap)],
                capture_output=True,
                text=True,
                check=False,
                timeout=MINISIGN_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            raise SigningError("minisign signature verification timed out") from exc
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "signature verification failed"
            raise SigningError(detail)
    return parse_strict_catalog(catalog_bytes, expected_repo=expected_repo)


def sign_plugin_manifest(
    plugin_dir: Path,
    secret_key_path: Path,
    public_key_path: Path,
    write_manifest: bool = False,
) -> tuple[str, dict[str, str]]:
    """Sign a plugin's files-only payload hash with `minisign -Sl` (legacy Ed)."""
    minisign = shutil.which("minisign")
    if minisign is None:
        raise SigningError("minisign binary is required to sign a plugin payload")
    if secret_key_path.is_symlink() or not secret_key_path.is_file():
        raise SigningError(f"secret key must be a regular file: {secret_key_path}")
    pub_text = read_regular_file(public_key_path, MAX_PUBLIC_KEY_BYTES).decode("utf-8")
    pub_key_b64 = extract_minisign_public_key(pub_text)
    parse_minisign_public_key(pub_key_b64)
    digest = sign_plugin.payload_sha256(plugin_dir)
    with tempfile.TemporaryDirectory(prefix="hornero-plugin-sign-") as temp_dir:
        snap = Path(temp_dir)
        msg_file = snap / "payload.sha256"
        sig_file = snap / "payload.sha256.minisig"
        msg_file.write_bytes(digest.encode("ascii"))
        try:
            result = subprocess.run(
                [minisign, "-Sl", "-s", str(secret_key_path), "-m", str(msg_file), "-x", str(sig_file)],
                capture_output=True,
                text=True,
                check=False,
                timeout=MINISIGN_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired as exc:
            raise SigningError("minisign plugin signing timed out") from exc
        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "minisign plugin signing failed"
            raise SigningError(detail)
        sig_line = extract_minisign_signature_line(sig_file.read_text(encoding="utf-8"))
    if not verify_minisign_legacy_signature(pub_key_b64, sig_line, digest.encode("ascii")):
        raise SigningError("generated plugin signature failed self-verification")
    block = {"publicKey": pub_key_b64, "signature": sig_line}
    if write_manifest:
        manifest_path = plugin_dir / "manifest.json"
        manifest = strict_json_loads(manifest_path.read_text(encoding="utf-8"))
        if not isinstance(manifest, dict):
            raise SigningError("manifest.json must contain a JSON object")
        manifest["signing"] = block
        tmp_manifest = manifest_path.with_name(f".manifest.json.tmp-{os.getpid()}")
        tmp_manifest.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        os.chmod(tmp_manifest, 0o644)
        os.replace(tmp_manifest, manifest_path)
    return digest, block


def verify_plugin_signature(plugin_dir: Path, require_signature: bool = True) -> tuple[str, str]:
    """Verify manifest.json['signing'] against files-only payload_sha256.

    Returns (status, digest) where status is 'signed' or 'unsigned'.
    Raises SigningError on missing (when required), malformed, or bad signature.
    """
    manifest_path = plugin_dir / "manifest.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise SigningError(f"manifest.json missing or not a regular file in {plugin_dir}")
    try:
        manifest = strict_json_loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError, RegistryError) as exc:
        raise SigningError(f"cannot read manifest.json: {exc}") from exc
    if not isinstance(manifest, dict):
        raise SigningError("manifest.json must be a JSON object")
    try:
        digest = sign_plugin.payload_sha256(plugin_dir)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        raise SigningError(f"invalid plugin payload: {exc}") from exc
    if "signing" not in manifest:
        if require_signature:
            raise SigningError(f"{plugin_dir.name}: manifest.json has no signing block")
        return "unsigned", digest
    signing = manifest["signing"]
    if not isinstance(signing, dict) or set(signing) != {"publicKey", "signature"}:
        raise SigningError(f"{plugin_dir.name}: signing must contain exactly publicKey and signature")
    pub_key = signing.get("publicKey")
    sig = signing.get("signature")
    if not isinstance(pub_key, str) or not isinstance(sig, str) or not pub_key or not sig:
        raise SigningError(f"{plugin_dir.name}: signing.publicKey and signing.signature must be non-empty strings")
    if not verify_minisign_legacy_signature(pub_key, sig, digest.encode("ascii")):
        raise SigningError(f"{plugin_dir.name}: bad-signature (author signature verification failed)")
    return "signed", digest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--sign", action="store_true", help="sign catalog.json (or --plugin) with Minisign")
    mode.add_argument("--verify", action="store_true", help="verify Minisign signature and signed payload")
    mode.add_argument("--check", action="store_true", help="check provenance, payload hashes, and optional signature")
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG, help="path to catalog.json")
    parser.add_argument("--signature", type=Path, default=None, help="detached .minisig path (default: <catalog>.minisig)")
    parser.add_argument("--public-key", type=Path, default=None, help="Minisign public key (.pub) path")
    parser.add_argument("--secret-key", type=Path, default=None, help="Minisign secret key (.key) path")
    parser.add_argument("--plugins-root", type=Path, default=None, help="repo root containing plugins/ (default: catalog parent)")
    parser.add_argument("--repo", default=DEFAULT_REPO, help="expected catalogSource.repo URL")
    parser.add_argument("--check-payloads", action="store_true", help="with --verify, also verify every plugin payload hash on disk")
    parser.add_argument("--require-signature", action="store_true", help="with --check, fail if detached/author signature is missing")
    parser.add_argument("--plugin", type=Path, default=None, help="operate on a single plugin directory instead of catalog.json")
    parser.add_argument("--write-manifest", action="store_true", help="with --plugin --sign, write signing block to manifest.json")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.plugin is not None:
            if args.sign:
                if args.secret_key is None or args.public_key is None:
                    raise SigningError("--plugin --sign requires --secret-key and --public-key")
                digest, block = sign_plugin_manifest(
                    args.plugin, args.secret_key, args.public_key, write_manifest=args.write_manifest
                )
                print(f"plugin signed: {args.plugin.name} @ {digest}")
                print(json.dumps({"signing": block}, indent=2))
                return 0
            require_sig = True if args.verify else args.require_signature
            status, digest = verify_plugin_signature(args.plugin, require_signature=require_sig)
            print(f"plugin {status}: {args.plugin.name} @ {digest}")
            return 0

        catalog_path = args.catalog
        sig_path = args.signature or Path(f"{catalog_path}.minisig")
        plugins_root = args.plugins_root or catalog_path.resolve().parent

        if args.sign:
            if args.secret_key is None:
                raise SigningError("--sign requires --secret-key")
            catalog = sign_catalog_file(catalog_path, sig_path, args.secret_key, expected_repo=args.repo)
            print(
                f"catalog signed: {sig_path} ({len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]})"
            )
            return 0

        if args.verify:
            if args.public_key is None:
                raise SigningError("--verify requires --public-key")
            catalog = verify_catalog_signature(
                catalog_path, sig_path, args.public_key, expected_repo=args.repo
            )
            if args.check_payloads:
                count = verify_catalog_payloads(catalog, plugins_root)
                print(
                    f"catalog signature and {count} plugin payloads verified @ {catalog['generatedFrom'][:8]}"
                )
            else:
                print(
                    f"catalog signature and provenance verified: {len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]}"
                )
            return 0

        # --check mode
        sig_requested = args.require_signature or args.public_key is not None or args.signature is not None
        if sig_requested:
            if args.public_key is None:
                raise SigningError("--check with signature verification requires --public-key")
            catalog = verify_catalog_signature(
                catalog_path, sig_path, args.public_key, expected_repo=args.repo
            )
        else:
            catalog_bytes = read_regular_file(catalog_path, MAX_CATALOG_BYTES)
            catalog = parse_strict_catalog(catalog_bytes, expected_repo=args.repo)
        count = verify_catalog_payloads(catalog, plugins_root)
        sig_note = " + signature" if sig_requested else ""
        print(f"catalog check OK{sig_note}: {count} plugins @ {catalog['generatedFrom'][:8]}")
        return 0
    except (SigningError, RegistryError, OSError, ValueError) as exc:
        print(f"sign_catalog: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
