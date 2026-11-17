"""Popover footer actions use the native full-width UiActionRow
(shell PluginKit 1.2.79), not small ghost/tonal buttons."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Plugins whose popover/dashboard surface has footer actions. Agenda,
# Calendar and Moon Phase became actionless Signal desktop widgets in
# their 3.x rewrites, so they no longer belong here.
MIGRATED = {
    "hornero-ai-usage": "Main.qml",
    "hornero-studio-audio": "Main.qml",
    "hornero-uptime": "Main.qml",
}


def test_popover_actions_are_full_width_rows():
    for pid, fname in MIGRATED.items():
        src = (ROOT / "plugins" / pid / fname).read_text(encoding="utf-8")
        assert "UiActionRow {" in src, pid
        assert "width: parent.width" in src, pid
        manifest = json.loads((ROOT / "plugins" / pid / "manifest.json").read_text())
        compat = manifest["marketplace"]["compatibility"]
        assert compat["minShellVersion"] == "1.2.79", pid


def test_ai_usage_bar_popover_action_is_a_row():
    src = (ROOT / "plugins/hornero-ai-usage/Bar.qml").read_text(encoding="utf-8")
    assert "UiActionRow {" in src
