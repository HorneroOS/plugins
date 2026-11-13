"""Pure-JS logic shipped in the Battery & Uptime 2.0 plugins (#31).

Each package carries one LOGIC block verbatim in its bar
(Main.qml) and dashboard (Dashboard.qml) entrypoints, because
plugins cannot share code across files. These tests extract the
shipped blocks and run them under Node against independent
Python oracles (the 1.x uptime formatter and /proc/uptime field
rules; the issue #31 visibility matrix and the documented
PluginKit Power stateText vocabulary). The structural checks
(blocks present and identical, surfaces and typed defaults
declared) always run; when Node is unavailable the oracle
comparisons are skipped with a reason. This is stub-level
evidence for the pure logic only: no plugin is rendered and no
live shell, UPower device or /proc read is exercised.
"""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")

PLUGINS = ["hornero-battery", "hornero-uptime"]

# Typed settings and their declared defaults. Battery
# showWhenNoBattery=false is the deliberate issue #31 acceptance
# change; every other default reproduces the 1.x behaviour.
EXPECTED_DEFAULTS = {
    "hornero-battery": {
        "showWhenNoBattery": False,
        "showPercentage": True,
        "showStateText": True,
        "lowBatteryPercent": 20,
    },
    "hornero-uptime": {
        "refreshSeconds": 60,
        "showLabel": True,
        "showWhenUnavailable": True,
    },
}


def extract_block(plugin: str, filename: str) -> str:
    text = (ROOT / "plugins" / plugin / filename).read_text()
    begin = text.index("LOGIC-BEGIN")
    end = text.index("LOGIC-END")
    return text[text.index("\n", begin):end]


def run_node(plugin: str, driver: str, cases) -> list:
    block = extract_block(plugin, "Main.qml")
    with tempfile.TemporaryDirectory() as tmp:
        script = Path(tmp) / "harness.js"
        cases_file = Path(tmp) / "cases.json"
        script.write_text(block + "\n" + driver)
        cases_file.write_text(json.dumps(cases))
        out = subprocess.run(
            [NODE, str(script), str(cases_file)],
            capture_output=True, text=True, check=True,
        )
    return json.loads(out.stdout)


def fmt_1x(total_seconds: int) -> str:
    d = total_seconds // 86400
    h = (total_seconds % 86400) // 3600
    m = (total_seconds % 3600) // 60
    if d > 0:
        return f"{d}d {h}h {m}m"
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m"


class Structure(unittest.TestCase):
    def test_logic_blocks_identical_across_surfaces(self):
        for plugin in PLUGINS:
            self.assertEqual(
                extract_block(plugin, "Main.qml"),
                extract_block(plugin, "Dashboard.qml"),
                plugin,
            )

    def test_manifest_v2_dashboard_surface_and_defaults(self):
        for plugin in PLUGINS:
            manifest = json.loads(
                (ROOT / "plugins" / plugin / "manifest.json").read_text())
            self.assertEqual(manifest["schemaVersion"], 2)
            self.assertEqual(manifest["version"], "2.0.0")
            self.assertEqual(manifest["placement"], "bar")
            dash = manifest["surfaces"]["dashboard"]
            self.assertEqual(dash["entrypoint"], "Dashboard.qml")
            self.assertEqual(dash["category"], "System")
            defaults = {
                key: spec["default"]
                for key, spec in manifest["capabilities"]["settings"].items()
            }
            self.assertEqual(defaults, EXPECTED_DEFAULTS[plugin], plugin)


@unittest.skipUnless(NODE, "node not available for QML logic oracle")
class BatteryLogic(unittest.TestCase):
    DRIVER = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(JSON.stringify(cases.map(c => [
  barShown(c[0], c[1]), isLow(c[0], c[2], c[3], c[4]),
  clampPercent(c[3]), stateKey(c[5])])));
"""

    def test_visibility_low_clamp_and_state(self):
        # [hasBattery, showWhenNoBattery, onBattery, pct, threshold, state]
        cases = [
            [False, False, False, 0, 20, ""],
            [False, True, False, 0, 20, ""],
            [True, False, True, 15, 20, "discharging"],
            [True, False, False, 15, 20, "charging"],
            [True, False, True, 85, 20, "fully-charged"],
            [True, False, True, 140, 20, "pending-charge"],
            [True, False, True, -3, 20, "something-else"],
        ]
        expected = [
            [False, False, 0, ""],
            [True, False, 0, ""],
            [True, True, 15, "discharging"],
            [True, False, 15, "charging"],
            [True, False, 85, "fully-charged"],
            [True, False, 100, "pending-charge"],
            [True, True, 0, "unknown"],
        ]
        self.assertEqual(
            run_node("hornero-battery", self.DRIVER, cases), expected)


@unittest.skipUnless(NODE, "node not available for QML logic oracle")
class UptimeLogic(unittest.TestCase):
    DRIVER = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(JSON.stringify(cases.map(c => [
  fmt(c[0]), parseUptime(c[1]), bootEpochMs(c[2], c[0])])));
"""

    def test_fmt_parse_and_boot_against_1x_oracle(self):
        cases = [
            [0, "", 1_700_000_000_000],
            [59, "59.9 12.0", 1_700_000_000_000],
            [3661, "3661.5 100.25\n", 1_700_000_000_000],
            [90061, "90061 0", 1_700_000_000_000],
            [172800, "garbage", 1_700_000_000_000],
            [3600, "3600", 1_700_000_000_000],
            [3600, "0 5", 1_700_000_000_000],
        ]
        expected = []
        for seconds, text, now_ms in cases:
            fields = text.split()
            def field(i):
                try:
                    return float(fields[i])
                except (IndexError, ValueError):
                    return float("nan")
            up, idle = field(0), field(1)
            expected.append([
                fmt_1x(seconds),
                [int(up) if up > 0 else -1,
                 int(idle) if idle >= 0 else -1],
                now_ms - seconds * 1000,
            ])
        self.assertEqual(
            run_node("hornero-uptime", self.DRIVER, cases), expected)


if __name__ == "__main__":
    unittest.main()
