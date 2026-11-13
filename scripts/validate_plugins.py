#!/usr/bin/env python3
"""Validate every plugins/*/ package: contract gate plus quality gate.

Contract gate (errors, unchanged in spirit): manifest parses, required
fields, id pattern, semver, files listed exist and are exactly the
payload (manifest.json + files), README.md and LICENSE present, no
symlinks/executables/binaries, and the entrypoint exists. It also
mirrors the schema in schema/plugin-manifest.schema.json (field
limits, capabilities, settings types) and the shell validator's QML
rules that are decidable here (import allowlist, declared process
commands and network hosts), without third-party deps.

Provenance gate (HorneroOS/plugins#33): inventory.yaml records, for
every researched capability and every first-party reimplementation,
the upstream link, classification, license and license status, and
inspiration notes. A license may be claimed only with
license_status: verified plus recorded license_evidence; anything
not verified from the upstream source must read license: UNVERIFIED
with license_status: unverified, never a silently claimed license.
Verified first-party entries are probed locally (the plugin's own
LICENSE file must exist and its manifest license must match the
inventory); verified upstream entries carry the recorded evidence
URL a maintainer observed (this script performs no network access).

Quality gate (HorneroOS/plugins#21): a maintained per-extension audit
in quality-audit.json classifies every official plugin as
premium-ready, needs-upgrade, consolidated, or
deprecated-with-replacement, and records a status for each premium
dimension (tooltips, accessibility, translation, settings, theme
tokens, orientation, loading/error states, performance, screenshots).
Statically decidable dimensions are probed from the QML/manifest and
the audit must match the probe exactly, so the audit cannot
over-claim and cannot silently go stale. Premium-ready additionally
requires a recorded graphical review. Failing or unverified
dimensions are reported as quality warnings; --strict turns them
into errors.

This is a static gate only. Passing it is NOT graphical acceptance:
no plugin is rendered, screenshotted, or exercised in a shell here.
"""
import json
import math
import re
import stat
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,47}$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$")
REQUIRED = ["schemaVersion", "id", "name", "version", "description", "author", "license", "entrypoint", "files", "capabilities"]
ALLOWED_FIELDS = set(REQUIRED) | {"homepage", "placement", "signing", "surfaces", "translations", "marketplace"}
DASHBOARD_CARD_SIZES = ("compact", "standard", "wide")
ACTION_RE = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
MARKETPLACE_SCREENSHOT_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp")
MARKETPLACE_MAX_SCREENSHOTS = 6
MARKETPLACE_MAX_CHANGELOG = 20
SCHEMA_VERSIONS = (1, 2)
# Manifest v2 surfaces (shell docs/PLUGINS.md): the first four have
# runtime hosts today; launcher/settings are validated declarations
# only. Mirrors the shell validator's SURFACES.
SURFACES = ("background", "bar", "dashboard", "desktop", "launcher", "settings")
LOCALE_TAG_RE = re.compile(r"^[a-z]{2,3}(_[A-Z]{2})?$")
TR_LITERAL_RE = re.compile(r'\btr\(\s*"((?:[^"\\]|\\.)*)"')
QSTR_RE = re.compile(r"\bqsTr(?:Id)?\s*\(")
PLACEHOLDER_RE = re.compile(r"%\d+")
BINARY_SUFFIXES = {".so", ".o", ".a", ".bin", ".exe", ".dll", ".pyc"}
PLACEMENTS = {"background", "bar", "dashboard", "desktop"}
TEXT_LIMITS = {"name": 64, "description": 280, "author": 120, "license": 80}
ALLOWED_IMPORTS = {
    "QtQuick", "QtQuick.Controls", "QtQuick.Layouts", "QtQml",
    "Quickshell", "Quickshell.Io", "Hornero.PluginKit",
}
FORBIDDEN_COMMANDS = {"sh", "bash", "dash", "zsh", "fish", "sudo", "doas", "su"}
COMMAND_RE = re.compile(r"^[A-Za-z0-9_.+-]+$")
HOST_RE = re.compile(r"^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$")
SETTING_KEY_RE = re.compile(r"^[a-z][a-zA-Z0-9]{0,47}$")
SETTING_TYPES = {"boolean", "integer", "number", "string", "enum"}
SETTING_FIELDS = {"type", "default", "description", "minimum", "maximum", "minLength", "maxLength", "options"}
SETTING_CONSTRAINTS = {
    "boolean": frozenset(),
    "integer": frozenset({"minimum", "maximum"}),
    "number": frozenset({"minimum", "maximum"}),
    "string": frozenset({"minLength", "maxLength"}),
    "enum": frozenset({"options"}),
}
SETTING_STRING_MAX = 4096
SETTING_ENUM_MAX_OPTIONS = 32
NETWORK_APIS = ["XMLHttpRequest", "WebSocket", "NetworkRequest", "TcpSocket"]

AUDIT_FILE = "quality-audit.json"
CLASSIFICATIONS = {"premium-ready", "needs-upgrade", "consolidated", "deprecated-with-replacement"}
DIMENSIONS = [
    "tooltips", "accessibility", "translation", "settings", "themeTokens",
    "orientation", "loadingErrorStates", "performance", "screenshots",
]
# Dimensions this script can decide from the payload alone. The audit
# entry must equal the probe for these; the rest are maintainer
# attestations that require a note (and, for orientation, a recorded
# graphical review before they may claim "pass").
PROBED_DIMENSIONS = ["tooltips", "accessibility", "translation", "settings", "themeTokens", "screenshots"]
DIMENSION_STATUSES = {"pass", "fail", "na", "unverified"}
ISSUE_RE = re.compile(r"^(https://github\.com/HorneroOS/plugins/issues/\d+|HorneroOS/plugins#\d+)$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
INTERACTIVE_RE = re.compile(r"\b(Button|TextField|TextInput|TextArea|Slider|MouseArea|TapHandler|Switch|CheckBox|ComboBox|SpinBox|UiButton|UiToggle|UiSlider)\b")
HARD_COLOR_RE = re.compile(r'color:\s*"(#[0-9A-Fa-f]{3,8}|red|white|black|gray|grey|blue|green|yellow|orange|purple|pink)"')

INVENTORY_FILE = "inventory.yaml"
INVENTORY_SCHEMA_VERSION = 2
INVENTORY_ENTRY_FIELDS = {
    "id", "name", "category", "origin", "classification",
    "license_status", "license_evidence", "inspiration_notes",
    "hornero_equivalent", "status",
}
INVENTORY_REQUIRED_FIELDS = INVENTORY_ENTRY_FIELDS - {"license_evidence"}
# Researched upstream capabilities are inspiration/adapt-idea/
# research-only; first-party reimplementations in plugins/ are
# implemented/hornero-original. Status must agree with that split.
RESEARCHED_CLASSIFICATIONS = {"inspiration", "adapt-idea", "research-only"}
IMPLEMENTED_CLASSIFICATIONS = {"implemented", "hornero-original"}
INVENTORY_CLASSIFICATIONS = RESEARCHED_CLASSIFICATIONS | IMPLEMENTED_CLASSIFICATIONS
LICENSE_STATUSES = {"verified", "unverified"}
UNVERIFIED_LICENSE = "UNVERIFIED"
OFFICIAL_REPO_URL = "https://github.com/HorneroOS/plugins"


def is_safe_relpath(value) -> bool:
    if not isinstance(value, str) or not value or len(value) > 240:
        return False
    if value.startswith("/") or "\\" in value or "//" in value:
        return False
    if any(part in {".", ".."} for part in value.split("/")):
        return False
    return bool(re.fullmatch(r"[A-Za-z0-9._/-]+", value))


def default_matches(declared, value) -> bool:
    if declared == "boolean":
        return isinstance(value, bool)
    if declared == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if declared == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
    if declared == "string":
        return isinstance(value, str)
    if declared == "enum":
        return isinstance(value, str)
    return False


def setting_value_valid(spec: dict, value) -> bool:
    """Whether value satisfies a typed setting declaration (shell #374)."""
    kind = spec.get("type")
    if not default_matches(kind, value):
        return False
    if kind == "string":
        if len(value) > SETTING_STRING_MAX:
            return False
        if "minLength" in spec and len(value) < spec["minLength"]:
            return False
        if "maxLength" in spec and len(value) > spec["maxLength"]:
            return False
    elif kind == "enum":
        return value in spec.get("options", [])
    elif kind in ("integer", "number"):
        if "minimum" in spec and value < spec["minimum"]:
            return False
        if "maximum" in spec and value > spec["maximum"]:
            return False
    return True


def validate_manifest_fields(tag: str, manifest: dict) -> list:
    errors = []
    for field in REQUIRED:
        if field not in manifest:
            errors.append(f"{tag}: missing required field {field}")
    for field in sorted(set(manifest) - ALLOWED_FIELDS):
        errors.append(f"{tag}: unknown top-level field {field} (schema is additionalProperties: false)")
    if type(manifest.get("schemaVersion")) is not int or manifest.get("schemaVersion") not in SCHEMA_VERSIONS:
        errors.append(f"{tag}: schemaVersion must be 1 or 2")
    if not ID_RE.match(str(manifest.get("id", ""))):
        errors.append(f"{tag}: id does not match {ID_RE.pattern}")
    if not SEMVER_RE.match(str(manifest.get("version", ""))):
        errors.append(f"{tag}: version is not semver")
    for field, limit in TEXT_LIMITS.items():
        value = manifest.get(field)
        if field in manifest and (not isinstance(value, str) or not value.strip() or len(value) > limit):
            errors.append(f"{tag}: {field} must be a non-blank string of at most {limit} chars")
    homepage = manifest.get("homepage")
    if homepage is not None and (not isinstance(homepage, str) or not re.match(r"^https://[^\s/]+(/.*)?$", homepage) or len(homepage) > 500):
        errors.append(f"{tag}: homepage must be an https URI of at most 500 chars")
    if manifest.get("placement", "background") not in PLACEMENTS:
        errors.append(f"{tag}: placement must be one of {sorted(PLACEMENTS)}")
    signing = manifest.get("signing")
    if signing is not None:
        if not isinstance(signing, dict) or set(signing) != {"publicKey", "signature"}:
            errors.append(f"{tag}: signing must have exactly publicKey and signature")
        else:
            if not re.fullmatch(r"[A-Za-z0-9+/]{40,80}={0,2}", str(signing["publicKey"])):
                errors.append(f"{tag}: signing.publicKey is malformed")
            if not re.fullmatch(r"[A-Za-z0-9+/]{80,120}={0,2}", str(signing["signature"])):
                errors.append(f"{tag}: signing.signature is malformed")
    entrypoint = manifest.get("entrypoint")
    if entrypoint is not None and (not is_safe_relpath(entrypoint) or not str(entrypoint).endswith(".qml")):
        errors.append(f"{tag}: entrypoint must be a safe relative .qml path")
    files = manifest.get("files")
    if files is not None:
        if not isinstance(files, list) or not all(isinstance(f, str) for f in files):
            errors.append(f"{tag}: files must be an array of strings")
            files = []
        if len(files) < 3:
            errors.append(f"{tag}: files must list at least 3 entries")
        if len(files) != len(set(files)):
            errors.append(f"{tag}: files must be unique")
        if "manifest.json" in files:
            errors.append(f"{tag}: files must not list manifest.json")
        for name in files:
            if not is_safe_relpath(name):
                errors.append(f"{tag}: files entry is not a safe relative path: {name}")
        if entrypoint is not None and entrypoint not in files:
            errors.append(f"{tag}: entrypoint must be listed in files")
    safe_files = {f for f in (files or []) if isinstance(f, str)}
    errors += validate_surfaces(tag, manifest, safe_files)
    errors += validate_translations_declaration(tag, manifest, safe_files)
    errors += validate_marketplace(tag, manifest, safe_files)
    caps = manifest.get("capabilities")
    if caps is not None:
        if not isinstance(caps, dict) or not {"processCommands", "networkHosts", "settings"} <= set(caps) <= {"processCommands", "networkHosts", "settings", "actions"}:
            errors.append(f"{tag}: capabilities must contain processCommands, networkHosts, and settings, plus optional actions")
        else:
            errors += validate_capabilities(tag, caps)
    return errors


def semver_key(version: str):
    core, _, prerelease = str(version).split("+", 1)[0].partition("-")
    numbers = tuple(int(part) for part in core.split("."))
    if not prerelease:
        return (numbers, (1,))
    parts = tuple((0, int(part), "") if part.isdigit() else (1, 0, part) for part in prerelease.split("."))
    return (numbers, (0,) + parts)


def validate_marketplace(tag: str, manifest: dict, safe_files: set) -> list:
    """Marketplace metadata, mirroring the shell validator (#379)."""
    errors = []
    if "marketplace" not in manifest:
        return errors
    mp = manifest["marketplace"]
    if not isinstance(mp, dict):
        return [f"{tag}: marketplace must be an object"]
    extra = set(mp) - {"screenshots", "compatibility", "changelog", "deprecation"}
    if extra:
        errors.append(f"{tag}: marketplace contains unknown fields: {', '.join(sorted(extra))}")
    if not mp:
        errors.append(f"{tag}: marketplace must declare at least one of screenshots, compatibility, changelog or deprecation")
        return errors
    if "screenshots" in mp:
        shots = mp["screenshots"]
        if not isinstance(shots, list) or not shots or len(shots) > MARKETPLACE_MAX_SCREENSHOTS:
            errors.append(f"{tag}: marketplace.screenshots must list 1 to {MARKETPLACE_MAX_SCREENSHOTS} screenshots")
        else:
            seen = set()
            for i, shot in enumerate(shots):
                where = f"{tag}: marketplace.screenshots[{i}]"
                if not isinstance(shot, dict):
                    errors.append(f"{where} must be an object"); continue
                if set(shot) - {"path", "alt"}:
                    errors.append(f"{where} contains unknown fields: {', '.join(sorted(set(shot) - {'path', 'alt'}))}")
                path = shot.get("path")
                if not is_safe_relpath(path):
                    errors.append(f"{where}.path must be a safe relative path")
                elif not str(path).lower().endswith(MARKETPLACE_SCREENSHOT_SUFFIXES):
                    errors.append(f"{where}.path must be a static image ({', '.join(MARKETPLACE_SCREENSHOT_SUFFIXES)})")
                elif path not in safe_files:
                    errors.append(f"{where}.path must be listed in files: {path}")
                elif path in seen:
                    errors.append(f"{tag}: marketplace.screenshots must not repeat a path")
                else:
                    seen.add(path)
                if "alt" in shot and (not isinstance(shot["alt"], str) or not shot["alt"].strip() or len(shot["alt"]) > 160):
                    errors.append(f"{where}.alt must be a non-empty string of at most 160 chars")
    if "compatibility" in mp:
        compat = mp["compatibility"]
        if not isinstance(compat, dict) or not compat or set(compat) - {"minShellVersion", "maxShellVersion"}:
            errors.append(f"{tag}: marketplace.compatibility must declare minShellVersion and/or maxShellVersion only")
        else:
            for bound in ("minShellVersion", "maxShellVersion"):
                if bound in compat and (not isinstance(compat[bound], str) or len(compat[bound]) > 80 or not SEMVER_RE.match(compat[bound])):
                    errors.append(f"{tag}: marketplace.compatibility.{bound} must be semantic versioning")
            if "minShellVersion" in compat and "maxShellVersion" in compat and all(SEMVER_RE.match(str(compat[b])) for b in compat):
                if semver_key(compat["minShellVersion"]) > semver_key(compat["maxShellVersion"]):
                    errors.append(f"{tag}: marketplace.compatibility.minShellVersion must not exceed maxShellVersion")
    if "changelog" in mp:
        log = mp["changelog"]
        if not isinstance(log, list) or not log or len(log) > MARKETPLACE_MAX_CHANGELOG:
            errors.append(f"{tag}: marketplace.changelog must list 1 to {MARKETPLACE_MAX_CHANGELOG} entries")
        else:
            seen = set()
            for i, entry in enumerate(log):
                where = f"{tag}: marketplace.changelog[{i}]"
                if not isinstance(entry, dict) or set(entry) != {"version", "notes"}:
                    errors.append(f"{where} must contain only version and notes"); continue
                if not isinstance(entry["version"], str) or not SEMVER_RE.match(entry["version"]):
                    errors.append(f"{where}.version must be semantic versioning")
                elif entry["version"] in seen:
                    errors.append(f"{tag}: marketplace.changelog must not repeat a version")
                else:
                    seen.add(entry["version"])
                if not isinstance(entry["notes"], str) or not entry["notes"].strip() or len(entry["notes"]) > 1000:
                    errors.append(f"{where}.notes must be a non-empty string of at most 1000 chars")
    if "deprecation" in mp:
        dep = mp["deprecation"]
        if not isinstance(dep, dict) or set(dep) - {"message", "replacedBy"}:
            errors.append(f"{tag}: marketplace.deprecation must contain only optional message and replacedBy")
        else:
            if "message" in dep and (not isinstance(dep["message"], str) or not dep["message"].strip() or len(dep["message"]) > 280):
                errors.append(f"{tag}: marketplace.deprecation.message must be a non-empty string of at most 280 chars")
            if "replacedBy" in dep:
                if not isinstance(dep["replacedBy"], str) or not ID_RE.match(dep["replacedBy"]):
                    errors.append(f"{tag}: marketplace.deprecation.replacedBy must be a plugin id")
                elif dep["replacedBy"] == manifest.get("id"):
                    errors.append(f"{tag}: marketplace.deprecation.replacedBy must not name the plugin itself")
    return errors


def validate_surfaces(tag: str, manifest: dict, safe_files: set) -> list:
    """Manifest v2 surfaces, mirroring the shell validator (#373)."""
    errors = []
    if "surfaces" not in manifest:
        return errors
    if manifest.get("schemaVersion") != 2:
        errors.append(f"{tag}: surfaces requires schemaVersion 2 (schemaVersion 1 supports only the single placement/entrypoint surface)")
        return errors
    surfaces = manifest["surfaces"]
    if not isinstance(surfaces, dict) or not surfaces:
        errors.append(f"{tag}: surfaces must be a non-empty object")
        return errors
    placement = manifest.get("placement", "background")
    entrypoint = manifest.get("entrypoint")
    for name, surface in surfaces.items():
        where = f"{tag}: surfaces.{name}"
        if name not in SURFACES:
            errors.append(f"{where}: unknown surface (known surfaces: {', '.join(SURFACES)})")
            continue
        if not isinstance(surface, dict):
            errors.append(f"{where} must be an object")
            continue
        extra = set(surface) - {"entrypoint", "enabled", "size", "category"}
        if extra:
            errors.append(f"{where} contains unknown fields: {', '.join(sorted(extra))}")
        if ("size" in surface or "category" in surface) and name != "dashboard":
            errors.append(f"{where}.size/category are dashboard card hints and are only allowed on the dashboard surface")
        if "size" in surface and surface["size"] not in DASHBOARD_CARD_SIZES:
            errors.append(f"{where}.size must be one of {', '.join(DASHBOARD_CARD_SIZES)}")
        if "category" in surface:
            category = surface["category"]
            if not isinstance(category, str) or not category.strip() or len(category) > 40 or category.strip().lower() == "pinned":
                errors.append(f"{where}.category must be a non-empty grouping label of at most 40 chars (not the reserved \"Pinned\")")
        if "entrypoint" not in surface:
            errors.append(f"{where}.entrypoint is required")
            continue
        surface_entry = surface["entrypoint"]
        if not is_safe_relpath(surface_entry) or not str(surface_entry).endswith(".qml"):
            errors.append(f"{where}.entrypoint must be a safe relative .qml path")
        elif surface_entry not in safe_files:
            errors.append(f"{where}.entrypoint must be listed in files: {surface_entry}")
        if name == placement and surface_entry != entrypoint:
            errors.append(f"{where}.entrypoint conflicts with the top-level entrypoint for the primary placement {placement!r}")
        if "enabled" in surface and not isinstance(surface["enabled"], bool):
            errors.append(f"{where}.enabled must be a boolean")
    return errors


def translations_declaration(manifest: dict):
    """(directory, locales) for a shape-valid declaration, else None."""
    decl = manifest.get("translations")
    if not isinstance(decl, dict):
        return None
    directory = decl.get("directory", "translations")
    locales = decl.get("locales")
    if not isinstance(directory, str) or not isinstance(locales, list):
        return None
    return directory, locales


def validate_translations_declaration(tag: str, manifest: dict, safe_files: set) -> list:
    """Translations declaration shape, mirroring the shell validator (#375)."""
    errors = []
    if "translations" not in manifest:
        return errors
    decl = manifest["translations"]
    if not isinstance(decl, dict):
        return [f"{tag}: translations must be an object"]
    extra = set(decl) - {"sourceLocale", "locales", "directory"}
    if extra:
        errors.append(f"{tag}: translations contains unknown fields: {', '.join(sorted(extra))}")
    if not {"sourceLocale", "locales"} <= set(decl):
        errors.append(f"{tag}: translations must contain sourceLocale and locales (directory is optional)")
        return errors
    if not isinstance(decl["sourceLocale"], str) or not LOCALE_TAG_RE.match(decl["sourceLocale"]):
        errors.append(f"{tag}: translations.sourceLocale must be a locale tag like \"en\" or \"es_AR\"")
    locales = decl["locales"]
    if (
        not isinstance(locales, list) or not locales
        or any(not isinstance(loc, str) or not LOCALE_TAG_RE.match(loc) for loc in locales)
        or len(locales) != len(set(locales))
    ):
        errors.append(f"{tag}: translations.locales must be a non-empty list of unique locale tags")
        return errors
    directory = decl.get("directory", "translations")
    if not is_safe_relpath(directory) or str(directory).endswith("/"):
        errors.append(f"{tag}: translations.directory must be a safe relative path")
        return errors
    for locale in locales:
        catalog = f"{directory}/{locale}.json"
        if catalog not in safe_files:
            errors.append(f"{tag}: translations declares locale {locale!r} but files does not list {catalog!r}")
    return errors


def unescape_qml_string(raw: str) -> str:
    out, i = [], 0
    escapes = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}
    while i < len(raw):
        if raw[i] == "\\" and i + 1 < len(raw) and raw[i + 1] in escapes:
            out.append(escapes[raw[i + 1]])
            i += 2
        else:
            out.append(raw[i])
            i += 1
    return "".join(out)


def validate_translation_catalogs(tag: str, plugin_dir: Path, manifest: dict, code: str) -> list:
    """Catalog completeness for literal tr() strings (shell #375 rules)."""
    errors = []
    decl = translations_declaration(manifest)
    if decl is None:
        return errors
    directory, locales = decl
    used = {unescape_qml_string(raw) for raw in TR_LITERAL_RE.findall(code)}

    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate key {key!r}")
            result[key] = value
        return result

    for locale in locales:
        relative = f"{directory}/{locale}.json"
        path = plugin_dir / relative
        if not path.is_file():
            continue  # missing catalog already reported as payload/files error
        try:
            catalog = json.loads(path.read_text(), object_pairs_hook=unique_object)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{tag}: {relative} is not readable JSON: {exc}")
            continue
        if not isinstance(catalog, dict):
            errors.append(f"{tag}: {relative} must be a JSON object mapping source strings to translations")
            continue
        for source_text, translated in catalog.items():
            if not source_text.strip() or len(source_text) > 4000:
                errors.append(f"{tag}: {relative} contains an empty or overlong source string key")
            if not isinstance(translated, str) or not translated.strip() or len(translated) > 4000:
                errors.append(f"{tag}: {relative} entry for {source_text!r} must be a non-empty translated string")
            elif set(PLACEHOLDER_RE.findall(source_text)) != set(PLACEHOLDER_RE.findall(translated)):
                errors.append(f"{tag}: {relative} entry for {source_text!r} must keep the same %1/%2 placeholders as the source string")
        missing = sorted(used - set(catalog))
        if missing:
            errors.append(f"{tag}: {relative} is missing translations for strings passed to Translations.tr(): " + ", ".join(repr(t) for t in missing))
    return errors


def validate_capabilities(tag: str, caps: dict) -> list:
    errors = []
    if "actions" in caps:
        actions = caps["actions"]
        if not isinstance(actions, list) or len(actions) > 32 or any(not isinstance(a, str) or not ACTION_RE.match(a) for a in actions) or (all(isinstance(a, str) for a in actions) and len(actions) != len(set(actions))):
            errors.append(f"{tag}: capabilities.actions must declare at most 32 unique snake_case action names")
    commands = caps["processCommands"]
    if not isinstance(commands, list) or not all(isinstance(c, str) for c in commands):
        errors.append(f"{tag}: capabilities.processCommands must be an array of strings")
    else:
        if len(commands) != len(set(commands)):
            errors.append(f"{tag}: capabilities.processCommands must be unique")
        for cmd in commands:
            if not COMMAND_RE.match(cmd) or cmd.lower() in FORBIDDEN_COMMANDS:
                errors.append(f"{tag}: forbidden or malformed processCommands entry: {cmd}")
    hosts = caps["networkHosts"]
    if not isinstance(hosts, list) or not all(isinstance(h, str) for h in hosts):
        errors.append(f"{tag}: capabilities.networkHosts must be an array of strings")
    else:
        if len(hosts) != len(set(hosts)):
            errors.append(f"{tag}: capabilities.networkHosts must be unique")
        for host in hosts:
            if not HOST_RE.match(host):
                errors.append(f"{tag}: malformed networkHosts entry: {host}")
    settings = caps["settings"]
    if not isinstance(settings, dict):
        errors.append(f"{tag}: capabilities.settings must be an object")
    else:
        for key, spec in settings.items():
            if not SETTING_KEY_RE.match(key):
                errors.append(f"{tag}: settings key does not match {SETTING_KEY_RE.pattern}: {key}")
            if not isinstance(spec, dict) or not set(spec) <= SETTING_FIELDS or not {"type", "default"} <= set(spec):
                errors.append(f"{tag}: settings.{key} must have type and default (description and type constraints optional)")
                continue
            if spec["type"] not in SETTING_TYPES:
                errors.append(f"{tag}: settings.{key}.type must be one of {sorted(SETTING_TYPES)}")
                continue
            kind = spec["type"]
            misplaced = (set(spec) - {"type", "default", "description"}) - SETTING_CONSTRAINTS[kind]
            if misplaced:
                errors.append(f"{tag}: settings.{key} of type {kind} cannot declare {', '.join(sorted(misplaced))}")
                continue
            if kind == "integer":
                bad = [b for b in ("minimum", "maximum") if b in spec and not (isinstance(spec[b], int) and not isinstance(spec[b], bool))]
                if bad:
                    errors.append(f"{tag}: settings.{key} {'/'.join(bad)} must be an integer")
                    continue
            if kind == "number":
                bad = [b for b in ("minimum", "maximum") if b in spec and not default_matches("number", spec[b])]
                if bad:
                    errors.append(f"{tag}: settings.{key} {'/'.join(bad)} must be a finite number")
                    continue
            if kind in ("integer", "number") and "minimum" in spec and "maximum" in spec and spec["minimum"] > spec["maximum"]:
                errors.append(f"{tag}: settings.{key} minimum must not exceed maximum")
                continue
            if kind == "string":
                bad = [b for b in ("minLength", "maxLength") if b in spec and not (isinstance(spec[b], int) and not isinstance(spec[b], bool) and 0 <= spec[b] <= SETTING_STRING_MAX)]
                if bad:
                    errors.append(f"{tag}: settings.{key} {'/'.join(bad)} must be an integer between 0 and {SETTING_STRING_MAX}")
                    continue
                if "minLength" in spec and "maxLength" in spec and spec["minLength"] > spec["maxLength"]:
                    errors.append(f"{tag}: settings.{key} minLength must not exceed maxLength")
                    continue
            if kind == "enum":
                options = spec.get("options")
                if (
                    not isinstance(options, list) or not options or len(options) > SETTING_ENUM_MAX_OPTIONS
                    or any(not isinstance(o, str) or not o or len(o) > 64 for o in options)
                    or len(options) != len(set(options))
                ):
                    errors.append(f"{tag}: settings.{key} of type enum must declare options: 1 to {SETTING_ENUM_MAX_OPTIONS} unique non-empty strings of at most 64 chars")
                    continue
            if not setting_value_valid(spec, spec["default"]):
                errors.append(f"{tag}: settings.{key}.default does not match declared type {spec['type']} or its constraints")
            desc = spec.get("description")
            if desc is not None and (not isinstance(desc, str) or not desc.strip() or len(desc) > 160):
                errors.append(f"{tag}: settings.{key}.description must be non-blank, at most 160 chars")
    return errors


def strip_line_comments(code: str) -> str:
    # Rough textual aid (same caveat as the shell validator's source
    # checks): drop // comments not preceded by ':' so https:// in a
    # string literal survives. Dynamic code can evade textual checks.
    return re.sub(r"(?<!:)//.*", "", code)


def validate_qml_contract(tag: str, manifest: dict, code: str) -> list:
    errors = []
    caps = manifest.get("capabilities") or {}
    declared_commands = caps.get("processCommands") or []
    declared_hosts = caps.get("networkHosts") or []
    declared_settings = caps.get("settings") or {}
    for module in sorted(set(re.findall(r"(?m)^import\s+([A-Za-z][A-Za-z0-9_.]*)", code))):
        if module not in ALLOWED_IMPORTS:
            errors.append(f"{tag}: disallowed QML import: {module}")
    if re.search(r"\bProcess\s*\{", code):
        literals = re.findall(r'command:\s*\[\s*"([^"]+)"', code)
        if not literals:
            errors.append(f"{tag}: Process usage must use a literal command array")
        for cmd in literals:
            base = cmd.rsplit("/", 1)[-1]
            if base.lower() in FORBIDDEN_COMMANDS:
                errors.append(f"{tag}: Process uses forbidden executable: {cmd}")
            elif base not in declared_commands:
                errors.append(f"{tag}: Process executable not declared in processCommands: {cmd}")
    for host in sorted(set(re.findall(r"https?://([A-Za-z0-9.-]+)", code))):
        if host not in declared_hosts:
            errors.append(f"{tag}: URL host not declared in networkHosts: {host}")
    for api in NETWORK_APIS:
        if api in code and not declared_hosts:
            errors.append(f"{tag}: network API {api} used with no declared networkHosts")
    for key in sorted(set(re.findall(r'(?:value|setValue)\(\s*"([A-Za-z0-9]+)"', code))):
        if key not in declared_settings:
            errors.append(f"{tag}: Settings key used but not declared in manifest: {key}")
    for key in declared_settings:
        if f'"{key}"' not in code:
            errors.append(f"{tag}: declared settings key never used in QML: {key}")
    for plugin_id in sorted(set(re.findall(r'pluginId:\s*"([^"]+)"', code))):
        if plugin_id != manifest.get("id"):
            errors.append(f"{tag}: Settings pluginId {plugin_id} does not equal manifest id")
    if QSTR_RE.search(code):
        errors.append(f"{tag}: qsTr()/qsTrId() is never translated for plugins (the shell installs no QTranslator for extension catalogs); use PluginKit Translations and tr() instead")
    return errors


def validate_plugin_dir(plugin_dir: Path):
    """Return (errors, manifest_or_none, qml_code)."""
    tag = plugin_dir.name
    try:
        manifest = json.loads((plugin_dir / "manifest.json").read_text())
    except Exception as exc:  # noqa: BLE001
        return [f"{tag}: manifest.json unreadable: {exc}"], None, ""
    if not isinstance(manifest, dict):
        return [f"{tag}: manifest.json must be a JSON object"], None, ""
    errors = validate_manifest_fields(tag, manifest)
    if manifest.get("id") != plugin_dir.name:
        errors.append(f"{tag}: directory name must equal manifest id")
    files = manifest.get("files", []) if isinstance(manifest.get("files", []), list) else []
    if "README.md" not in files or "LICENSE" not in files:
        errors.append(f"{tag}: files must include README.md and LICENSE")
    for name in files:
        if isinstance(name, str) and is_safe_relpath(name) and not (plugin_dir / name).is_file():
            errors.append(f"{tag}: listed file missing: {name}")
    on_disk = {
        str(p.relative_to(plugin_dir))
        for p in plugin_dir.rglob("*")
        if p.is_file() and not p.is_symlink()
    }
    if on_disk != set(files) | {"manifest.json"}:
        errors.append(f"{tag}: payload drift, on disk {sorted(on_disk)} vs manifest {sorted(set(files) | {'manifest.json'})}")
    for path in plugin_dir.rglob("*"):
        if path.is_symlink():
            errors.append(f"{tag}: symlink not allowed: {path.relative_to(plugin_dir)}")
        elif path.is_file():
            mode = path.stat().st_mode
            if mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH):
                errors.append(f"{tag}: executable file not allowed: {path.relative_to(plugin_dir)}")
            if path.suffix in BINARY_SUFFIXES:
                errors.append(f"{tag}: binary file not allowed: {path.relative_to(plugin_dir)}")
    entry = plugin_dir / str(manifest.get("entrypoint", ""))
    if not entry.is_file():
        errors.append(f"{tag}: entrypoint missing: {manifest.get('entrypoint')}")
    code = ""
    for name in files:
        if isinstance(name, str) and name.endswith(".qml") and (plugin_dir / name).is_file():
            code += (plugin_dir / name).read_text(errors="replace") + "\n"
    if code:
        errors += validate_qml_contract(tag, manifest, code)
        errors += validate_translation_catalogs(tag, plugin_dir, manifest, code)
    return errors, manifest, code


def translatable_literals(code: str) -> list:
    """Alphabetic string literals outside comments, imports, Process
    command arrays, and date/time format calls. Conservative: it may
    count a non-visible literal, never the reverse for visible text
    written as a plain literal."""
    text = strip_line_comments(code)
    text = re.sub(r"(?m)^import\s+.*$", "", text)
    text = re.sub(r"command:\s*\[[^\]]*\]", "command: []", text)
    text = re.sub(r"(?:formatDateTime|format)\((?:[^()\"]|\"[^\"]*\")*\)", "format()", text)
    return [s for s in re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', text) if re.search(r"[A-Za-z]{2,}", s)]


def quality_probe(plugin_dir: Path, manifest: dict, code: str, root: Path) -> dict:
    """Statically decidable premium dimensions for one plugin."""
    caps = manifest.get("capabilities") or {}
    declared_settings = caps.get("settings") or {}
    interactive = bool(INTERACTIVE_RE.search(code))
    probe = {}
    # PluginKit controls expose tooltips/accessible names through the
    # kit properties (tooltipText/accessibleName, backed by UiTooltip
    # and Accessible.* inside the kit); plain Qt controls use the
    # attached ToolTip.text/Accessible.name properties. Both are real.
    has_tooltip = "ToolTip.text" in code or "tooltipText" in code or "UiTooltip" in code
    has_a11y_name = "Accessible.name" in code or "accessibleName" in code
    probe["tooltips"] = "na" if not interactive else ("pass" if has_tooltip else "fail")
    probe["accessibility"] = "na" if not interactive else ("pass" if has_a11y_name else "fail")
    if not translatable_literals(code):
        probe["translation"] = "na"
    else:
        # The shell rejects qsTr() in plugins (no QTranslator is
        # installed for them); PluginKit Translations + tr() is the
        # only mechanism that actually translates.
        has_translations = (
            "Translations" in code
            and bool(TR_LITERAL_RE.search(code))
            and translations_declaration(manifest) is not None
        )
        probe["translation"] = "pass" if has_translations else "fail"
    if not declared_settings:
        probe["settings"] = "na"
    else:
        used = all(f'"{key}"' in code for key in declared_settings)
        probe["settings"] = "pass" if (used and re.search(r"\bSettings\s*\{", code)) else "fail"
    if manifest.get("placement", "background") == "background":
        probe["themeTokens"] = "na"
    else:
        probe["themeTokens"] = "pass" if ("Theme." in code and not HARD_COLOR_RE.search(code)) else "fail"
    shots = [root / "docs" / "screenshots" / f"{plugin_dir.name}{ext}" for ext in (".png", ".jpg", ".jpeg", ".webp")]
    probe["screenshots"] = "pass" if any(p.is_file() for p in shots) else "fail"
    return probe


def parse_inventory_scalar(raw: str):
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2:
        return raw[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    if raw.startswith("{") or raw.startswith("[") or raw.startswith('"'):
        raise ValueError(f"unsupported scalar {raw!r}")
    return raw


def parse_inventory_flow_map(raw: str) -> dict:
    raw = raw.strip()
    if not (raw.startswith("{") and raw.endswith("}")):
        raise ValueError("origin must be a flow mapping {project: ..., url: ..., license: ...}")
    parts, current, in_quote = [], [], False
    for char in raw[1:-1]:
        if char == '"':
            in_quote = not in_quote
        if char == "," and not in_quote:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
    if in_quote:
        raise ValueError("unterminated quote in flow mapping")
    if current:
        parts.append("".join(current))
    result = {}
    for part in parts:
        if not part.strip():
            continue
        key, sep, value = part.partition(":")
        if not sep or not key.strip():
            raise ValueError(f"malformed flow mapping entry {part!r}")
        if key.strip() in result:
            raise ValueError(f"duplicate flow mapping key {key.strip()!r}")
        result[key.strip()] = parse_inventory_scalar(value)
    return result


def parse_inventory(text: str):
    """Parse the restricted YAML subset inventory.yaml is written in.

    Deliberately narrow (no third-party YAML dependency): top-level
    schemaVersion/capabilities, one list of flat mappings, origin as
    a flow mapping, plain or double-quoted scalars. Anything outside
    the subset is an error, so new entries cannot smuggle shapes the
    provenance gate does not check.
    """
    errors = []
    data = {"schemaVersion": None, "capabilities": []}
    current = None
    in_capabilities = False
    for lineno, line in enumerate(text.splitlines(), 1):
        where = f"inventory: line {lineno}"
        if not line.strip() or line.strip().startswith("#"):
            continue
        if line != line.rstrip():
            errors.append(f"{where}: trailing whitespace is not allowed")
            continue
        if not in_capabilities:
            if line.startswith("schemaVersion:"):
                try:
                    data["schemaVersion"] = int(line.partition(":")[2].strip())
                except ValueError:
                    errors.append(f"{where}: schemaVersion must be an integer")
            elif line == "capabilities:":
                in_capabilities = True
            else:
                errors.append(f"{where}: unsupported top-level content {line.strip()!r} (only schemaVersion and capabilities are allowed)")
            continue
        if line.startswith("  - "):
            current = {}
            data["capabilities"].append(current)
            rest = line[4:]
        elif line.startswith("    ") and current is not None:
            rest = line[4:]
        else:
            errors.append(f"{where}: unsupported indentation or content {line.strip()!r}")
            continue
        key, sep, value = rest.partition(":")
        if not sep or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key.strip()):
            errors.append(f"{where}: malformed mapping entry {rest.strip()!r}")
            continue
        key = key.strip()
        if key in current:
            errors.append(f"{where}: duplicate field {key}")
            continue
        try:
            current[key] = parse_inventory_flow_map(value) if key == "origin" else parse_inventory_scalar(value)
        except ValueError as exc:
            errors.append(f"{where}: {exc}")
    if not in_capabilities:
        errors.append("inventory: capabilities list is missing")
    return data, errors


def validate_inventory(root: Path, official_ids: set, manifests: dict):
    """Provenance gate (#33). Return (errors, entries)."""
    errors = []
    path = root / INVENTORY_FILE
    if not path.is_file():
        return [f"inventory: {INVENTORY_FILE} missing (every capability and first-party plugin needs a provenance entry)"], []
    data, parse_errors = parse_inventory(path.read_text())
    errors += parse_errors
    if data["schemaVersion"] != INVENTORY_SCHEMA_VERSION:
        errors.append(f"inventory: schemaVersion must be {INVENTORY_SCHEMA_VERSION} (schema 1 entries carried no license status or inspiration notes)")
    entries = data["capabilities"]
    seen = {}
    implemented_ids = set()
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
            errors.append("inventory: every entry needs a string id")
            continue
        if entry["id"] in seen:
            errors.append(f"inventory: duplicate entry for {entry['id']}")
        seen[entry["id"]] = entry
    for pid, entry in sorted(seen.items()):
        errors += validate_inventory_entry(root, pid, entry, official_ids, manifests)
        if entry.get("status") == "implemented":
            implemented_ids.add(pid)
    for missing in sorted(set(official_ids) - implemented_ids):
        errors.append(f"inventory: missing implemented provenance entry for official plugin {missing}")
    for extra in sorted(implemented_ids - set(official_ids)):
        errors.append(f"inventory: implemented entry {extra} does not name an official plugin in plugins/")
    return errors, entries


def validate_inventory_entry(root: Path, pid: str, entry: dict, official_ids: set, manifests: dict) -> list:
    errors = []
    tag = f"inventory: {pid}"
    for field in sorted(set(entry) - INVENTORY_ENTRY_FIELDS):
        errors.append(f"{tag}: unknown field {field}")
    for field in sorted(INVENTORY_REQUIRED_FIELDS - set(entry)):
        errors.append(f"{tag}: missing provenance field {field}")
    if not ID_RE.match(pid):
        errors.append(f"{tag}: id does not match {ID_RE.pattern}")
    for field in ("name", "category", "hornero_equivalent"):
        value = entry.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{tag}: {field} must be a non-blank string")
    notes = entry.get("inspiration_notes")
    if not isinstance(notes, str) or len(notes.strip()) < 10:
        errors.append(f"{tag}: inspiration_notes must be a non-blank string of at least 10 chars")
    classification = entry.get("classification")
    if classification not in INVENTORY_CLASSIFICATIONS:
        errors.append(f"{tag}: classification must be one of {sorted(INVENTORY_CLASSIFICATIONS)}")
    status = entry.get("status")
    if status not in ("researched", "implemented"):
        errors.append(f"{tag}: status must be researched or implemented")
    elif classification in RESEARCHED_CLASSIFICATIONS and status != "researched":
        errors.append(f"{tag}: classification {classification} requires status researched")
    elif classification in IMPLEMENTED_CLASSIFICATIONS and status != "implemented":
        errors.append(f"{tag}: classification {classification} requires status implemented")
    origin = entry.get("origin")
    if not isinstance(origin, dict) or set(origin) != {"project", "url", "license"}:
        errors.append(f"{tag}: origin must have exactly project, url and license")
        origin = origin if isinstance(origin, dict) else {}
    if not isinstance(origin.get("project"), str) or not str(origin.get("project", "")).strip():
        errors.append(f"{tag}: origin.project must be a non-blank string")
    url = origin.get("url")
    if not isinstance(url, str) or not re.match(r"^https://[^\s/]+(/.*)?$", url) or len(url) > 500:
        errors.append(f"{tag}: origin.url must be an https URI of at most 500 chars (the verified upstream link)")
    license_value = origin.get("license")
    if not isinstance(license_value, str) or not license_value.strip():
        errors.append(f"{tag}: origin.license must be a non-blank string")
    license_status = entry.get("license_status")
    if license_status not in LICENSE_STATUSES:
        errors.append(f"{tag}: license_status must be one of {sorted(LICENSE_STATUSES)}")
    evidence = entry.get("license_evidence")
    if license_status == "verified":
        if license_value == UNVERIFIED_LICENSE:
            errors.append(f"{tag}: license_status verified cannot claim license UNVERIFIED")
        if status == "implemented":
            # Probed locally below, not merely attested.
            if evidence != f"plugins/{pid}/LICENSE":
                errors.append(f"{tag}: implemented entries must record license_evidence plugins/{pid}/LICENSE (probed from this repository)")
        elif not isinstance(evidence, str) or not re.match(r"^https://[^\s/]+(/.*)?$", evidence) or len(evidence) > 500:
            errors.append(f"{tag}: license_status verified requires license_evidence: the https URL of the upstream license a maintainer observed")
    elif license_status == "unverified":
        if license_value != UNVERIFIED_LICENSE:
            errors.append(f"{tag}: unverified licenses must be marked license: UNVERIFIED, never silently claimed (found {license_value!r})")
        if evidence is not None:
            errors.append(f"{tag}: license_evidence is only allowed with license_status verified")
    if status == "implemented":
        if pid not in official_ids:
            return errors  # coverage error is reported by the caller
        if entry.get("hornero_equivalent") != f"plugins/{pid}":
            errors.append(f"{tag}: implemented entries must set hornero_equivalent to plugins/{pid}")
        if url != OFFICIAL_REPO_URL:
            errors.append(f"{tag}: implemented entries are first-party; origin.url must be {OFFICIAL_REPO_URL} (credit upstream inspiration in a separate researched entry)")
        manifest = manifests.get(pid) or {}
        if license_value != manifest.get("license"):
            errors.append(f"{tag}: origin.license {license_value!r} does not match the plugin manifest license {manifest.get('license')!r}")
        if not (root / "plugins" / pid / "LICENSE").is_file():
            errors.append(f"{tag}: license probe failed: plugins/{pid}/LICENSE is missing")
        if license_status != "verified":
            errors.append(f"{tag}: implemented first-party entries must be license_status verified (their LICENSE ships in this repository)")
    elif status == "researched" and pid in official_ids:
        errors.append(f"{tag}: researched entry id must not reuse an official plugin id")
    return errors


def validate_audit(root: Path, official: dict):
    """official: {id: probe}. Return (errors, warnings, entries)."""
    errors, warnings = [], []
    path = root / AUDIT_FILE
    if not path.is_file():
        return [f"quality-audit: {AUDIT_FILE} missing (every official plugin needs an audit entry)"], warnings, []
    try:
        audit = json.loads(path.read_text())
    except Exception as exc:  # noqa: BLE001
        return [f"quality-audit: {AUDIT_FILE} unreadable: {exc}"], warnings, []
    if not isinstance(audit, dict) or set(audit) != {"schemaVersion", "disclaimer", "entries"}:
        return ["quality-audit: top level must be exactly schemaVersion, disclaimer, entries"], warnings, []
    if audit.get("schemaVersion") != 1:
        errors.append("quality-audit: schemaVersion must be 1")
    if "not graphical acceptance" not in str(audit.get("disclaimer", "")).lower():
        errors.append("quality-audit: disclaimer must state this is not graphical acceptance")
    entries = audit.get("entries")
    if not isinstance(entries, list):
        return errors + ["quality-audit: entries must be an array"], warnings, []
    seen = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str):
            errors.append("quality-audit: every entry needs a string id")
            continue
        if entry["id"] in seen:
            errors.append(f"quality-audit: duplicate entry for {entry['id']}")
        seen[entry["id"]] = entry
    for missing in sorted(set(official) - set(seen)):
        errors.append(f"quality-audit: missing entry for {missing}")
    for extra in sorted(set(seen) - set(official)):
        errors.append(f"quality-audit: entry for unknown plugin {extra}")
    for pid, entry in sorted(seen.items()):
        if pid not in official:
            continue
        errors += validate_audit_entry(pid, entry, official)
        dims = entry.get("dimensions") or {}
        weak = [f"{d}={dims.get(d, {}).get('status')}" for d in DIMENSIONS if dims.get(d, {}).get("status") in {"fail", "unverified"}]
        if weak:
            warnings.append(f"quality: {pid} [{entry.get('classification')}]: " + ", ".join(weak))
    return errors, warnings, entries


def validate_audit_entry(pid: str, entry: dict, official: dict) -> list:
    errors = []
    allowed = {"id", "classification", "valueProposition", "nativeOverlap", "dimensions", "issue", "replacement", "graphicalReview"}
    for field in sorted(set(entry) - allowed):
        errors.append(f"quality-audit: {pid}: unknown field {field}")
    classification = entry.get("classification")
    if classification not in CLASSIFICATIONS:
        errors.append(f"quality-audit: {pid}: classification must be one of {sorted(CLASSIFICATIONS)}")
    for field in ("valueProposition", "nativeOverlap"):
        value = entry.get(field)
        if not isinstance(value, str) or len(value.strip()) < 10:
            errors.append(f"quality-audit: {pid}: {field} must be a non-blank string of at least 10 chars")
    if classification == "needs-upgrade" and not ISSUE_RE.match(str(entry.get("issue", ""))):
        errors.append(f"quality-audit: {pid}: needs-upgrade requires a linked issue (HorneroOS/plugins#N or its URL)")
    if classification in {"consolidated", "deprecated-with-replacement"}:
        replacement = entry.get("replacement")
        if replacement not in official or replacement == pid:
            errors.append(f"quality-audit: {pid}: {classification} requires replacement to be another official plugin id")
    dims = entry.get("dimensions")
    if not isinstance(dims, dict) or set(dims) != set(DIMENSIONS):
        errors.append(f"quality-audit: {pid}: dimensions must be exactly {DIMENSIONS}")
        dims = dims if isinstance(dims, dict) else {}
    probe = official[pid]
    for dim in DIMENSIONS:
        spec = dims.get(dim)
        if not isinstance(spec, dict) or set(spec) != {"status", "note"}:
            errors.append(f"quality-audit: {pid}: dimensions.{dim} must have exactly status and note")
            continue
        if spec["status"] not in DIMENSION_STATUSES:
            errors.append(f"quality-audit: {pid}: dimensions.{dim}.status must be one of {sorted(DIMENSION_STATUSES)}")
        if not isinstance(spec["note"], str) or not spec["note"].strip():
            errors.append(f"quality-audit: {pid}: dimensions.{dim}.note must be non-blank")
        if dim in PROBED_DIMENSIONS and spec["status"] != probe[dim]:
            errors.append(
                f"quality-audit: {pid}: dimensions.{dim} is {spec['status']} but static probe finds {probe[dim]}; "
                "fix the plugin or correct the audit, do not let them disagree"
            )
    review = entry.get("graphicalReview")
    if dims.get("orientation", {}).get("status") == "pass" and not review:
        errors.append(f"quality-audit: {pid}: orientation pass requires a recorded graphicalReview")
    if review is not None:
        if not isinstance(review, dict) or set(review) != {"reviewer", "date"} or not str(review.get("reviewer", "")).strip() or not DATE_RE.match(str(review.get("date", ""))):
            errors.append(f"quality-audit: {pid}: graphicalReview must be {{reviewer, date: YYYY-MM-DD}}")
    if classification == "premium-ready":
        for dim in DIMENSIONS:
            if dims.get(dim, {}).get("status") not in {"pass", "na"}:
                errors.append(f"quality-audit: {pid}: premium-ready requires {dim} pass/na, found {dims.get(dim, {}).get('status')}")
        if not review:
            errors.append(f"quality-audit: {pid}: premium-ready requires a recorded graphicalReview (static checks are not graphical acceptance)")
    return errors


def main(argv=None, root: Path = ROOT) -> int:
    argv = sys.argv[1:] if argv is None else argv
    strict = "--strict" in argv
    errors = []
    # Official plugins (plugins/) feed catalog.json. Community
    # submissions (community/) pass the exact same contract gate but
    # are never catalogued, endorsed, or distributed as official, and
    # are not part of the official quality audit.
    official_dirs = sorted(p for p in (root / "plugins").iterdir() if p.is_dir()) if (root / "plugins").is_dir() else []
    community_root = root / "community"
    community_dirs = sorted(p for p in community_root.iterdir() if p.is_dir()) if community_root.is_dir() else []
    probes = {}
    manifests = {}
    for plugin_dir in official_dirs + community_dirs:
        found, manifest, code = validate_plugin_dir(plugin_dir)
        errors += found
        if manifest is not None and plugin_dir in official_dirs:
            probes[plugin_dir.name] = quality_probe(plugin_dir, manifest, code, root)
            manifests[plugin_dir.name] = manifest
    warnings, entries, inventory_entries = [], [], []
    if official_dirs:
        audit_errors, warnings, entries = validate_audit(root, probes)
        errors += audit_errors
        inventory_errors, inventory_entries = validate_inventory(root, set(probes), manifests)
        errors += inventory_errors
    if strict and warnings:
        errors += [f"strict: {w}" for w in warnings]
        warnings = []
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("plugins valid:", ", ".join(p.name for p in official_dirs))
    if community_root.is_dir():
        print("community valid (unreviewed, not catalogued):", ", ".join(p.name for p in community_dirs) or "none")
    counts = {}
    for entry in entries:
        counts[entry.get("classification")] = counts.get(entry.get("classification"), 0) + 1
    print("quality audit:", f"{len(entries)} official plugins classified:", ", ".join(f"{k}={counts[k]}" for k in sorted(counts)))
    license_counts = {}
    for entry in inventory_entries:
        license_counts[entry.get("license_status")] = license_counts.get(entry.get("license_status"), 0) + 1
    print("provenance inventory:", f"{len(inventory_entries)} entries:", ", ".join(f"license-{k}={license_counts[k]}" for k in sorted(license_counts, key=str)))
    for warning in warnings:
        print(warning)
    print("static quality gate only: NOT graphical acceptance (no plugin was rendered or run in a shell)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
