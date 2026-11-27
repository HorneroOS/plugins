"""Regression tests ensuring readable text uses Theme.palette.inkMuted rather than inkFaint.

RFC 0001 §3.1 reserves Theme.palette.inkFaint strictly for disabled controls
and decorative rules/ticks; readable captions, labels, and headers must use
Theme.palette.inkMuted (or ink) to preserve contrast across Signal themes.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGINS_DIR = ROOT / "plugins"

AUDITED_PLUGINS = [
    "hornero-port-watch",
    "hornero-git-board",
    "hornero-containers",
    "hornero-forge-board",
    "hornero-device-battery",
    "hornero-toolbox",
    "hornero-calendar",
]


def _uitext_blocks_matching(src: str, needle: str) -> list[str]:
    return [
        m.group(0)
        for m in re.finditer(r"\bUiText\s*\{[^}]*\}", src, re.DOTALL)
        if needle in m.group(0)
    ]


def test_audited_plugins_avoid_inkfaint_and_use_inkmuted():
    for plugin_id in AUDITED_PLUGINS:
        src = (PLUGINS_DIR / plugin_id / "Main.qml").read_text(encoding="utf-8")
        assert "inkFaint" not in src, f"{plugin_id}/Main.qml still references inkFaint"
        assert "Theme.palette.inkMuted" in src, f"{plugin_id}/Main.qml should use Theme.palette.inkMuted"


def test_audited_readable_text_bindings_use_inkmuted():
    expected_snippets = {
        "hornero-port-watch": [
            ("text: String(s.port)", "s.listening ? Theme.palette.ink : Theme.palette.inkMuted"),
            ('i18n.tr("free")', "s.listening ? Theme.palette.ink : Theme.palette.inkMuted"),
            ('s.proto + (root.showProcess && s.pid > 0 ? " · pid " + s.pid : "")', "color: Theme.palette.inkMuted"),
            ('i18n.tr("%1 more not shown")', "color: Theme.palette.inkMuted"),
        ],
        "hornero-git-board": [
            ('repo.commit + (repo.when.length > 0 ? " · " + repo.when : "")', "color: Theme.palette.inkMuted"),
            ('i18n.tr("Everything is committed and in step. Cosy.")', "color: Theme.palette.inkMuted"),
            ('i18n.tr("%1 more not shown")', "color: Theme.palette.inkMuted"),
        ],
        "hornero-containers": [
            ('c.image + (c.status.length > 0 ? " · " + c.status : "")', "color: Theme.palette.inkMuted"),
            ('i18n.tr("%1 more not shown")', "color: Theme.palette.inkMuted"),
        ],
        "hornero-forge-board": [
            ('(r.run.branch && r.run.branch.length > 0 ? r.run.branch + " · " : "") + r.run.title', "color: Theme.palette.inkMuted"),
        ],
        "hornero-device-battery": [
            ("text: d.model", "color: Theme.palette.inkMuted"),
        ],
        "hornero-toolbox": [
            ('i18n.tr("Not a valid expression yet.")', "color: Theme.palette.inkMuted"),
            ('i18n.tr("Real calendar dates only; the arithmetic uses UTC so daylight saving never shifts a result.")', "color: Theme.palette.inkMuted"),
            ('i18n.tr("%1 characters, %2 words, %3 lines")', "color: Theme.palette.inkMuted"),
        ],
        "hornero-calendar": [
            ('role: "eyebrow"', "color: Theme.palette.inkMuted"),
        ],
    }

    for plugin_id, checks in expected_snippets.items():
        src = (PLUGINS_DIR / plugin_id / "Main.qml").read_text(encoding="utf-8")
        for needle, expected_color in checks:
            blocks = _uitext_blocks_matching(src, needle)
            assert blocks, f"{plugin_id}: missing UiText block for {needle!r}"
            assert any(expected_color in b and "inkFaint" not in b for b in blocks), (
                f"{plugin_id}: UiText for {needle!r} must use {expected_color!r}, not inkFaint"
            )


def test_no_readable_text_uses_inkfaint_across_plugins():
    offenders = []
    for qml_path in sorted(PLUGINS_DIR.glob("*/*.qml")):
        text = qml_path.read_text(encoding="utf-8")
        for match in re.finditer(r"\b(UiText|Text)\s*\{[^}]*\}", text, re.DOTALL):
            block = match.group(0)
            if "inkFaint" in block and "enabled: false" not in block:
                offenders.append(str(qml_path.relative_to(ROOT)))
    assert offenders == [], f"Readable text elements use inkFaint: {offenders}"
