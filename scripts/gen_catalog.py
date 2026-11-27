#!/usr/bin/env python3
"""Generate or check catalog.json from plugins/*/manifest.json.

The per-plugin manifest.json stays authoritative (same pattern as
Noctalia's generated catalog). catalog.json is an index for discovery:
identity, placement, capability disclosure, the git revision it was
generated at, and a SHA-256 over the package payload (manifest.json +
every file listed in manifest.files, in sorted order, framed as
name NUL bytes NUL) so installers can verify integrity before the
shell validator even runs.

Store fields for Control Center > Extensions (shown before install,
without running plugin code):
  marketplace  the manifest's marketplace object (changelog,
               compatibility, deprecation, packaged screenshots).
  screenshots  catalogue screenshots kept outside the payload at
               docs/screenshots/<id>.<ext>, each with its SHA-256 so
               horneroctl can verify the bytes before caching them.
  permissions  one plain-language line per declared program, network
               host, shared data domain, broker action and settings
               block, in English and Spanish. Program and network
               reasons come from catalog-permissions.json and are
               required: a declared program without a reason fails.

Usage:
  python3 scripts/gen_catalog.py           # write catalog.json
  python3 scripts/gen_catalog.py --check   # fail if stale or invalid
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGINS = ROOT / "plugins"
CATALOG = ROOT / "catalog.json"
PERMISSIONS = ROOT / "catalog-permissions.json"
SCREENSHOTS = ROOT / "docs" / "screenshots"
SCREENSHOT_EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp")
# Shared data domains (PluginKit Providers) in plain language. These are
# read-only facades the shell already samples; the line says what the
# extension can see, not what it can change.
PROVIDER_TEXT = {
    "system": ("CPU, memory, temperature and disk use", "uso de CPU, memoria, temperatura y disco"),
    "network": ("network throughput and connection state", "tráfico de red y estado de la conexión"),
    "spectrum": ("the audio spectrum of what is playing", "el espectro del audio que se está reproduciendo"),
    "media": ("the track that is playing and its controls", "el tema que se está reproduciendo y sus controles"),
    "audio": ("volume and audio devices", "volumen y dispositivos de audio"),
    "power": ("battery and power profile", "batería y perfil de energía"),
    "weather": ("the weather for your configured location", "el clima de la ubicación que configuraste"),
    "time": ("the clock and calendar", "el reloj y el calendario"),
    "workspaces": ("your workspaces and windows", "tus espacios de trabajo y ventanas"),
}
CATEGORIES = {
    "hornero-agenda": "productivity",
    "hornero-ai-usage": "developer",
    "hornero-audio-deck": "media",
    "hornero-battery": "system",
    "hornero-bitin": "companions",
    "hornero-calendar": "productivity",
    "hornero-capi": "companions",
    "hornero-clipboard": "utilities",
    "hornero-containers": "developer",
    "hornero-countdown": "productivity",
    "hornero-device-battery": "system",
    "hornero-disk-usage": "system",
    "hornero-elsewhen": "productivity",
    "hornero-emoji": "utilities",
    "hornero-equalizer": "media",
    "hornero-forge-board": "developer",
    "hornero-git-board": "developer",
    "hornero-github-stats": "developer",
    "hornero-metronome": "productivity",
    "hornero-microphone": "media",
    "hornero-moon-phase": "utilities",
    "hornero-network-scope": "system",
    "hornero-now-playing": "media",
    "hornero-pomodoro": "productivity",
    "hornero-port-watch": "developer",
    "hornero-quick-notes": "productivity",
    "hornero-studio-audio": "media",
    "hornero-studio-jobs": "developer",
    "hornero-system-insight": "system",
    "hornero-tailscale": "system",
    "hornero-toolbox": "utilities",
    "hornero-uptime": "system",
    "hornero-volume": "media",
    "hornero-weather": "utilities",
    "hornero-world-clock": "productivity",
}


def payload_sha256(plugin_dir: Path, manifest: dict) -> str:
    h = hashlib.sha256()
    names = sorted(set(["manifest.json", *manifest.get("files", [])]))
    for name in names:
        data = (plugin_dir / name).read_bytes()
        h.update(name.encode())
        h.update(b"\0")
        h.update(data)
        h.update(b"\0")
    return h.hexdigest()


def load_permission_notes() -> dict:
    if not PERMISSIONS.exists():
        return {}
    data = json.loads(PERMISSIONS.read_text(encoding="utf-8"))
    if data.get("schemaVersion") != 1 or not isinstance(data.get("plugins"), dict):
        raise SystemExit("catalog-permissions.json: schemaVersion 1 with a plugins object is required")
    return data["plugins"]


def permission_lines(plugin_id: str, capabilities: dict, notes: dict) -> list:
    """Plain-language permission lines, EN and ES, for one entry.

    Program and network reasons are mandatory curated text; the shared
    data, broker action and settings lines are generated because their
    meaning does not depend on the plugin.
    """
    own = notes.get(plugin_id, {})
    lines = []
    for kind, key in (("program", "processCommands"), ("network", "networkHosts")):
        for value in capabilities.get(key, []) or []:
            note = own.get(f"{kind}:{value}")
            if not isinstance(note, dict) or not note.get("en", "").strip() or not note.get("es", "").strip():
                raise SystemExit(
                    f"{plugin_id}: declares {kind} {value!r} but catalog-permissions.json has no "
                    f"English and Spanish reason for \"{kind}:{value}\"")
            lines.append({"kind": kind, "value": value, "en": note["en"], "es": note["es"]})
    for domain in capabilities.get("providers", []) or []:
        en, es = PROVIDER_TEXT.get(domain, (domain, domain))
        lines.append({"kind": "data", "value": domain,
                      "en": f"Reads {en} from the shell's shared data (read-only).",
                      "es": f"Lee {es} de los datos compartidos del shell (solo lectura)."})
    for action in capabilities.get("actions", []) or []:
        name = action if isinstance(action, str) else str(action.get("id", action)) if isinstance(action, dict) else str(action)
        lines.append({"kind": "action", "value": name,
                      "en": f"May ask horneroctl to run the system action {name}; the broker checks every request.",
                      "es": f"Puede pedirle a horneroctl la acción de sistema {name}; el intermediario revisa cada pedido."})
    settings = capabilities.get("settings") or {}
    if settings:
        keys = ", ".join(sorted(settings))
        lines.append({"kind": "settings", "value": keys,
                      "en": f"Stores only its own settings ({keys}).",
                      "es": f"Guarda solo su propia configuración ({keys})."})
    unused = sorted(k for k in own if k.split(":", 1)[1] not in
                    (capabilities.get("processCommands", []) if k.startswith("program:") else
                     capabilities.get("networkHosts", []) if k.startswith("network:") else []))
    if unused:
        raise SystemExit(f"{plugin_id}: catalog-permissions.json has reasons for undeclared uses: {', '.join(unused)}")
    return lines


def catalogue_screenshots(plugin_id: str, name: str) -> list:
    shots = []
    for ext in SCREENSHOT_EXTENSIONS:
        path = SCREENSHOTS / f"{plugin_id}{ext}"
        if path.is_file():
            shots.append({
                "path": path.relative_to(ROOT).as_posix(),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "bytes": path.stat().st_size,
                "alt": f"{name}, rendered by Hornero Shell",
            })
    return shots


def build() -> dict:
    notes = load_permission_notes()
    known = {p.name for p in PLUGINS.iterdir() if p.is_dir()}
    stray = sorted(set(notes) - known)
    if stray:
        raise SystemExit(f"catalog-permissions.json names unknown plugins: {', '.join(stray)}")
    entries = []
    for plugin_dir in sorted(p for p in PLUGINS.iterdir() if p.is_dir()):
        manifest = json.loads((plugin_dir / "manifest.json").read_text())
        entry = (
            {
                "id": manifest["id"],
                "name": manifest["name"],
                "version": manifest["version"],
                "description": manifest["description"],
                "author": manifest["author"],
                "license": manifest["license"],
                "homepage": manifest.get("homepage", ""),
                "placement": manifest.get("placement", "background"),
                "category": CATEGORIES.get(manifest["id"], "utilities"),
                "capabilities": manifest.get("capabilities", {}),
                "trust": "official",
                "path": f"plugins/{plugin_dir.name}",
                "sha256": payload_sha256(plugin_dir, manifest),
            }
        )
        # RFC 0003: record the minimum PluginKit level only when it is
        # above the baseline, so existing entries stay byte-identical and
        # a registry can hide what a given Shell cannot run.
        if manifest.get("pluginKit", 3) != 3:
            entry["pluginKit"] = manifest["pluginKit"]
        if isinstance(manifest.get("marketplace"), dict):
            entry["marketplace"] = manifest["marketplace"]
        shots = catalogue_screenshots(manifest["id"], manifest["name"])
        if shots:
            entry["screenshots"] = shots
        entry["permissions"] = permission_lines(manifest["id"], manifest.get("capabilities", {}), notes)
        entries.append(entry)
    # Revision of the last commit that touched plugins/ at generation
    # time. It is provenance for the snapshot, not freshness: a squash
    # merge rewrites that commit, so --check must not compare it (see
    # catalog_is_current). Generation still stamps the current value.
    rev = subprocess.run(
        ["git", "log", "-1", "--format=%H", "--", "plugins/"],
        cwd=ROOT, capture_output=True, text=True,
    ).stdout.strip()
    return {
        "schemaVersion": 1,
        "generatedFrom": rev,
        # Client compatibility contract v1: where this catalogue comes
        # from. `repo` is the canonical upstream; `rev` is the last
        # commit that touched plugins/ at generation time (same value
        # as generatedFrom). Clients may resolve repo@rev to verify
        # entries against the exact source tree; freshness checks must
        # never compare rev (squash merges rewrite it).
        "catalogSource": {
            "repo": "https://github.com/HorneroOS/plugins",
            "rev": rev,
        },
        "plugins": entries,
    }


def catalog_is_current(existing_text: str, built: dict) -> bool:
    """Freshness compares plugin entries, never the generatedFrom stamp.

    Squash merges rewrite the commit that last touched plugins/, so a
    byte comparison would report a just-merged catalog as stale forever.
    The stamp must still be present and be a full commit id.
    """
    try:
        existing = json.loads(existing_text)
    except json.JSONDecodeError:
        return False
    if not isinstance(existing, dict):
        return False
    stamp = existing.get("generatedFrom")
    if not isinstance(stamp, str) or not re.fullmatch(r"[0-9a-f]{40}([0-9a-f]{24})?", stamp):
        return False
    return (
        existing.get("schemaVersion") == built["schemaVersion"]
        and existing.get("plugins") == built["plugins"]
    )


def main() -> int:
    check = "--check" in sys.argv
    catalog = build()
    text = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    if check:
        if not CATALOG.exists() or not catalog_is_current(CATALOG.read_text(encoding="utf-8"), catalog):
            print("catalog.json is stale; run scripts/gen_catalog.py", file=sys.stderr)
            return 1
        print(f"catalog OK: {len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]}")
        return 0
    CATALOG.write_text(text, encoding="utf-8")
    print(f"wrote catalog.json: {len(catalog['plugins'])} plugins @ {catalog['generatedFrom'][:8]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
