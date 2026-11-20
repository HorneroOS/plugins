"""Bar popovers of the official plugins follow the native popout pattern:
subtitle header, caption state line, UiDetailRow label/value rows."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
POPOVERS = ["hornero-studio-audio", "hornero-pomodoro"]


def test_popovers_use_native_pattern():
    for pid in POPOVERS:
        src = (ROOT / "plugins" / pid / "Main.qml").read_text(encoding="utf-8")
        popover = src.split("UiPopover {")[1]
        assert 'role: "subtitle"' in popover, pid
        assert "UiDetailRow {" in popover, pid
        assert 'role: "title"' not in popover, pid
        assert "UiMetric {" not in popover, pid
        assert "UiChip {" not in popover, pid
        manifest = json.loads((ROOT / "plugins" / pid / "manifest.json").read_text())
        # studio-audio moved to 1.2.79 for the UiActionRow footer.
        expected = "1.2.79" if pid == "hornero-studio-audio" else "1.2.74"
        assert manifest["marketplace"]["compatibility"]["minShellVersion"] == expected, pid
