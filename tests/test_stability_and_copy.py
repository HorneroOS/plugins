"""Regression tests for plugin stability (#114) and user-facing copy (#71)."""

import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGINS = ROOT / "plugins"
NODE = shutil.which("node")

TR_CALL_RE = re.compile(r'i18n\.tr\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\)')


def read_plugin(plugin_id: str, filename: str = "Main.qml") -> str:
    return (PLUGINS / plugin_id / filename).read_text(encoding="utf-8")


def tr_strings(plugin_id: str) -> list[str]:
    strings: list[str] = []
    for qml in sorted((PLUGINS / plugin_id).glob("*.qml")):
        strings.extend(TR_CALL_RE.findall(qml.read_text(encoding="utf-8")))
    return strings


class WidgetCopyTests(unittest.TestCase):
    """Ensure widget UI strings do not leak implementation details or raw CLI commands."""

    CLEANED_PLUGINS = (
        "hornero-agenda",
        "hornero-ai-usage",
        "hornero-calendar",
        "hornero-disk-usage",
        "hornero-forge-board",
        "hornero-github-stats",
        "hornero-quick-notes",
        "hornero-studio-audio",
        "hornero-studio-jobs",
        "hornero-weather",
        "hornero-world-clock",
    )

    FORBIDDEN_COPY = (
        "horneroctl",
        "gh auth login",
        "github-cli",
        "calendar events source",
        "events source yet",
        "built-in daylight-saving",
        "built-in rules",
        "single configured location",
        "Drive health is not shown",
        "Saved automatically.",
        "Persistent — saved and restored",
        "shell settings",
    )

    def test_no_leaked_implementation_or_cli_strings_in_ui(self):
        for pid in self.CLEANED_PLUGINS:
            for s in tr_strings(pid):
                low = s.lower()
                for forbidden in self.FORBIDDEN_COPY:
                    self.assertNotIn(
                        forbidden.lower(),
                        low,
                        f"{pid} leaked {forbidden!r} in i18n.tr({s!r})",
                    )

    def test_calendar_numerals_match_native_dashboard_scale(self):
        qml = read_plugin("hornero-calendar")
        self.assertIn("font.pointSize: Theme.font.size.small", qml)
        self.assertIn("font.weight: cell.today ? Font.DemiBold : Font.Normal", qml)

    def test_weather_wind_chip_container_hidden_when_inactive(self):
        qml = read_plugin("hornero-weather")
        self.assertRegex(qml, r"UiStack\s*\{\s*visible:\s*root\.windHigh")


class StabilityGuardTests(unittest.TestCase):
    """Verify defensive null/bounds/exit-code guards across modified plugins."""

    def test_quick_notes_error_chip_uses_error_state_and_safe_save(self):
        qml = read_plugin("hornero-quick-notes")
        self.assertIn('tone: root.saveState === "error" ? "alert" : "neutral"', qml)
        self.assertNotIn('root.saveState === "alert"', qml)
        self.assertIn("if (saveTimer)", qml)
        self.assertIn("noteArea ? noteArea.text", qml)

    def test_world_clock_guards_zone_lookup_and_vertical_bar(self):
        main = read_plugin("hornero-world-clock", "Main.qml")
        bar = read_plugin("hornero-world-clock", "Bar.qml")
        self.assertIn("Object.prototype.hasOwnProperty.call(table, value)", main)
        self.assertIn("zoneOrUtc(modelData)", main)
        self.assertIn("Object.prototype.hasOwnProperty.call(table, value)", bar)
        self.assertIn('root.hostOrientation === "vertical"', bar)

    def test_weather_guards_nullable_facade_fields(self):
        for fname in ("Main.qml", "Bar.qml"):
            qml = read_plugin("hornero-weather", fname)
            self.assertIn("(Weather.lastError || \"\").length", qml, fname)
            self.assertIn("(Weather.description || \"\").length", qml, fname)
        main = read_plugin("hornero-weather", "Main.qml")
        self.assertIn('typeof Weather.forecast.length === "number"', main)
        bar = read_plugin("hornero-weather", "Bar.qml")
        self.assertIn('popover.opened ? "" :', bar)
        self.assertIn('root.hostOrientation !== "vertical"', bar)

    def test_process_exits_and_queue_handlers_guard_state(self):
        for fname in ("Main.qml", "Dashboard.qml"):
            sa = read_plugin("hornero-studio-audio", fname)
            self.assertIn("if (code !== 0)", sa, fname)
            self.assertIn('data.performance_active === "true" || data.performance_active === true', sa, fname)

        sj = read_plugin("hornero-studio-jobs")
        self.assertIn("if (code !== 0)", sj)
        self.assertIn("if (path === undefined || path === null)", sj)

        usage = read_plugin("hornero-ai-usage", "UsageData.qml")
        self.assertIn("if (!parsed || typeof parsed !== \"object\" || parsed.ok === false)", usage)
        self.assertGreaterEqual(usage.count("if (exitCode === 0)"), 2)

        agents = read_plugin("hornero-ai-usage", "Agents.qml")
        self.assertIn("if (index >= 0 && index < windows.length)", agents)

        ai_bar = read_plugin("hornero-ai-usage", "Bar.qml")
        self.assertIn('root.hostOrientation === "vertical"', ai_bar)
        self.assertIn('popover.opened ? "" :', ai_bar)

        gb = read_plugin("hornero-git-board")
        self.assertIn("if (!root.current)", gb)
        self.assertIn("if (!entry)", gb)

        fb = read_plugin("hornero-forge-board")
        self.assertIn("if (pendingStep !== step || !current)", fb)

    @unittest.skipUnless(NODE, "node not available; JS guard check skipped")
    def test_disk_usage_helpers_handle_malformed_entries_without_nan(self):
        src = read_plugin("hornero-disk-usage")
        m = re.search(r"function nameOf\(d\).*?readonly property var mostFull:", src, re.DOTALL)
        self.assertIsNotNone(m)
        js = m.group(0).rsplit("readonly property var mostFull:", 1)[0]
        driver = """
const samples = [null, undefined, "", "/", {mount: "/data", total: "bad", used: "nan", free: null, perc: "oops"}, {mount: "/ok", total: 1000, used: 250}];
const out = samples.map(d => [nameOf(d), totalKiB(d), usedKiB(d), freeKiB(d), fracOf(d)]);
process.stdout.write(JSON.stringify(out));
"""
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "test.js"
            p.write_text(js + "\n" + driver, encoding="utf-8")
            res = subprocess.run([NODE, str(p)], capture_output=True, text=True, check=True)
        rows = json.loads(res.stdout)
        for row in rows:
            for val in row[1:]:
                self.assertIsInstance(val, (int, float))
        self.assertEqual(rows[-1], ["/ok", 1000, 250, 750, 0.25])


if __name__ == "__main__":
    unittest.main()
