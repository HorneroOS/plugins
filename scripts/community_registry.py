"""Strict community registry source and index validation helpers."""

from __future__ import annotations

import base64
import hashlib
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import urlsplit


SOURCE_PATH = Path("community/registry-sources.json")
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{0,47}$")
OBJECT_ID_PATTERN = re.compile(r"^(?:[a-f0-9]{40}|[a-f0-9]{64})$")
SHA256_PATTERN = re.compile(r"^[a-f0-9]{64}$")
FINGERPRINT_PATTERN = re.compile(r"^sha256:[a-f0-9]{64}$")
PUBLIC_KEY_PATTERN = re.compile(r"^RW[A-Za-z0-9+/]{54}$")
ALLOWED_HOSTS = {"github.com", "codeberg.org", "gitlab.com"}


class RegistryError(ValueError):
    """The registry input does not meet its strict schema or trust rules."""


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise RegistryError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def strict_json_loads(text: str) -> object:
    return json.loads(text, object_pairs_hook=_unique_object)


def _read_json(path: Path) -> dict:
    try:
        value = strict_json_loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RegistryError(f"cannot read valid JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RegistryError(f"{path} must contain a JSON object")
    return value


def _repository(value: object, where: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 500:
        raise RegistryError(f"{where} must be a non-empty HTTPS repository URL")
    try:
        parsed = urlsplit(value)
        port = parsed.port
    except ValueError as exc:
        raise RegistryError(f"{where} must be a valid HTTPS repository URL") from exc
    if (
        parsed.scheme != "https"
        or parsed.hostname not in ALLOWED_HOSTS
        or parsed.netloc != parsed.hostname
        or parsed.username is not None
        or parsed.password is not None
        or port is not None
        or parsed.query
        or parsed.fragment
    ):
        raise RegistryError(f"{where} must use HTTPS on github.com, codeberg.org, or gitlab.com")
    segments = parsed.path.strip("/").split("/")
    if len(segments) < 2 or any(not re.fullmatch(r"[A-Za-z0-9_.-]+", part) or part in {".", ".."} for part in segments):
        raise RegistryError(f"{where} must identify a repository path")
    if segments[-1].endswith(".git"):
        segments[-1] = segments[-1][:-4]
    if not segments[-1] or value != f"https://{parsed.netloc}/{'/'.join(parsed.path.strip('/').split('/'))}":
        raise RegistryError(f"{where} must be a canonical HTTPS repository URL without a trailing slash")
    return value.removesuffix(".git")


def _public_key_fingerprint(value: object, where: str) -> str:
    if not isinstance(value, str) or not PUBLIC_KEY_PATTERN.fullmatch(value):
        raise RegistryError(f"{where} must be a canonical minisign public key")
    try:
        raw = base64.b64decode(value, validate=True)
    except ValueError as exc:
        raise RegistryError(f"{where} must be valid base64") from exc
    if len(raw) != 42 or raw[:2] != b"Ed" or base64.b64encode(raw).decode("ascii") != value:
        raise RegistryError(f"{where} must encode a 42-byte minisign public key")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _source_entry(raw: object, index: int) -> dict:
    where = f"plugins[{index}]"
    if not isinstance(raw, dict):
        raise RegistryError(f"{where} must be an object")
    required = {"id", "repository", "revision", "sha256", "authorPublicKey"}
    if set(raw) != required:
        raise RegistryError(f"{where} must contain exactly {', '.join(sorted(required))}")
    plugin_id = raw["id"]
    if not isinstance(plugin_id, str) or not ID_PATTERN.fullmatch(plugin_id):
        raise RegistryError(f"{where}.id must be a lowercase plugin id")
    repository = _repository(raw["repository"], f"{where}.repository")
    revision = raw["revision"]
    if not isinstance(revision, str) or not OBJECT_ID_PATTERN.fullmatch(revision):
        raise RegistryError(f"{where}.revision must be a full lowercase 40- or 64-character commit id")
    payload_hash = raw["sha256"]
    if not isinstance(payload_hash, str) or not SHA256_PATTERN.fullmatch(payload_hash):
        raise RegistryError(f"{where}.sha256 must be a lowercase SHA-256 hex digest")
    fingerprint = _public_key_fingerprint(raw["authorPublicKey"], f"{where}.authorPublicKey")
    return {
        "id": plugin_id,
        "repository": repository,
        "revision": revision,
        "sha256": payload_hash,
        "authorKeyFingerprint": fingerprint,
    }


def load_sources(path: Path) -> tuple[int, list[dict]]:
    source = _read_json(path)
    if set(source) != {"schemaVersion", "indexVersion", "plugins"}:
        raise RegistryError("registry sources must contain exactly schemaVersion, indexVersion, and plugins")
    if type(source["schemaVersion"]) is not int or source["schemaVersion"] != 1:
        raise RegistryError("registry source schemaVersion must be 1")
    version = source["indexVersion"]
    if type(version) is not int or version < 1:
        raise RegistryError("indexVersion must be a positive integer")
    if not isinstance(source["plugins"], list):
        raise RegistryError("plugins must be an array")
    entries = [_source_entry(entry, index) for index, entry in enumerate(source["plugins"])]
    ids = [entry["id"] for entry in entries]
    if len(ids) != len(set(ids)):
        raise RegistryError("plugin ids must be unique")
    return version, sorted(entries, key=lambda entry: entry["id"])


def source_revision(root: Path, source_path: Path = SOURCE_PATH) -> str:
    result = subprocess.run(
        ["git", "log", "-1", "--format=%H", "--", source_path.as_posix()],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    revision = result.stdout.strip()
    if result.returncode != 0 or not OBJECT_ID_PATTERN.fullmatch(revision):
        detail = result.stderr.strip() or "no committed registry source revision found"
        raise RegistryError(f"cannot resolve registry source revision: {detail}")
    committed = subprocess.run(
        ["git", "show", f"{revision}:{source_path.as_posix()}"],
        cwd=root,
        capture_output=True,
        check=False,
    )
    try:
        working_copy = (root / source_path).read_bytes()
    except OSError as exc:
        raise RegistryError(f"cannot read registry source {source_path}: {exc}") from exc
    if committed.returncode != 0 or committed.stdout != working_copy:
        raise RegistryError(
            f"{source_path} differs from its committed revision; commit source changes before generating"
        )
    return revision


def build_index(root: Path, source_path: Path = SOURCE_PATH) -> dict:
    version, entries = load_sources(root / source_path)
    return {
        "schemaVersion": 1,
        "indexVersion": version,
        "generatedFrom": source_revision(root, source_path),
        "plugins": entries,
    }


def validate_index(index: dict) -> None:
    if set(index) != {"schemaVersion", "indexVersion", "generatedFrom", "plugins"}:
        raise RegistryError("index must contain exactly schemaVersion, indexVersion, generatedFrom, and plugins")
    if type(index["schemaVersion"]) is not int or index["schemaVersion"] != 1:
        raise RegistryError("index schemaVersion is unsupported")
    if type(index["indexVersion"]) is not int or index["indexVersion"] < 1:
        raise RegistryError("indexVersion must be a positive integer")
    if not isinstance(index["generatedFrom"], str) or not OBJECT_ID_PATTERN.fullmatch(index["generatedFrom"]):
        raise RegistryError("generatedFrom must be a full lowercase commit id")
    if not isinstance(index["plugins"], list):
        raise RegistryError("plugins must be an array")
    required = {"id", "repository", "revision", "sha256", "authorKeyFingerprint"}
    ids = []
    for number, entry in enumerate(index["plugins"]):
        where = f"plugins[{number}]"
        if not isinstance(entry, dict) or set(entry) != required:
            raise RegistryError(f"{where} has an unsupported shape")
        if not isinstance(entry["id"], str) or not ID_PATTERN.fullmatch(entry["id"]):
            raise RegistryError(f"{where}.id is invalid")
        ids.append(entry["id"])
        _repository(entry["repository"], f"{where}.repository")
        if not isinstance(entry["revision"], str) or not OBJECT_ID_PATTERN.fullmatch(entry["revision"]):
            raise RegistryError(f"{where}.revision must be a full commit id")
        if not isinstance(entry["sha256"], str) or not SHA256_PATTERN.fullmatch(entry["sha256"]):
            raise RegistryError(f"{where}.sha256 must be a SHA-256 hex digest")
        if not isinstance(entry["authorKeyFingerprint"], str) or not FINGERPRINT_PATTERN.fullmatch(entry["authorKeyFingerprint"]):
            raise RegistryError(f"{where}.authorKeyFingerprint is invalid")
    if len(ids) != len(set(ids)):
        raise RegistryError("plugin ids must be unique")


def json_text(value: dict) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"
