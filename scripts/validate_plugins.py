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
import re
import stat
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,47}$")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$")
REQUIRED = ["schemaVersion", "id", "name", "version", "description", "author", "license", "entrypoint", "files", "capabilities"]
ALLOWED_FIELDS = set(REQUIRED) | {"homepage", "placement", "signing"}
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
SETTING_TYPES = {"boolean", "integer", "number", "string"}
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
INTERACTIVE_RE = re.compile(r"\b(Button|TextField|TextInput|TextArea|Slider|MouseArea|TapHandler|Switch|CheckBox|ComboBox|SpinBox)\b")
HARD_COLOR_RE = re.compile(r'color:\s*"(#[0-9A-Fa-f]{3,8}|red|white|black|gray|grey|blue|green|yellow|orange|purple|pink)"')


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
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if declared == "string":
        return isinstance(value, str)
    return False


def validate_manifest_fields(tag: str, manifest: dict) -> list:
    errors = []
    for field in REQUIRED:
        if field not in manifest:
            errors.append(f"{tag}: missing required field {field}")
    for field in sorted(set(manifest) - ALLOWED_FIELDS):
        errors.append(f"{tag}: unknown top-level field {field} (schema is additionalProperties: false)")
    if manifest.get("schemaVersion") != 1:
        errors.append(f"{tag}: schemaVersion must be 1")
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
    caps = manifest.get("capabilities")
    if caps is not None:
        if not isinstance(caps, dict) or set(caps) != {"processCommands", "networkHosts", "settings"}:
            errors.append(f"{tag}: capabilities must have exactly processCommands, networkHosts, settings")
        else:
            errors += validate_capabilities(tag, caps)
    return errors


def validate_capabilities(tag: str, caps: dict) -> list:
    errors = []
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
            if not isinstance(spec, dict) or not set(spec) <= {"type", "default", "description"} or not {"type", "default"} <= set(spec):
                errors.append(f"{tag}: settings.{key} must have type and default (description optional)")
                continue
            if spec["type"] not in SETTING_TYPES:
                errors.append(f"{tag}: settings.{key}.type must be one of {sorted(SETTING_TYPES)}")
            elif not default_matches(spec["type"], spec["default"]):
                errors.append(f"{tag}: settings.{key}.default does not match declared type {spec['type']}")
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
    probe["tooltips"] = "na" if not interactive else ("pass" if "ToolTip.text" in code else "fail")
    probe["accessibility"] = "na" if not interactive else ("pass" if "Accessible.name" in code else "fail")
    if not translatable_literals(code):
        probe["translation"] = "na"
    else:
        probe["translation"] = "pass" if ("qsTr(" in code or "qsTrId(" in code) else "fail"
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
    for plugin_dir in official_dirs + community_dirs:
        found, manifest, code = validate_plugin_dir(plugin_dir)
        errors += found
        if manifest is not None and plugin_dir in official_dirs:
            probes[plugin_dir.name] = quality_probe(plugin_dir, manifest, code, root)
    warnings, entries = [], []
    if official_dirs:
        audit_errors, warnings, entries = validate_audit(root, probes)
        errors += audit_errors
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
    for warning in warnings:
        print(warning)
    print("static quality gate only: NOT graphical acceptance (no plugin was rendered or run in a shell)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
