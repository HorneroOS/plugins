"""Desktop Widgets 2.0 pure-JS logic shipped in the desktop plugins (#32).

hornero-agenda, hornero-calendar and hornero-moon-phase are the
first-party `placement: "desktop"` packages. Each carries the same
DESKTOP-LOGIC block verbatim (plugins cannot share code): the nine
shell slot names, malformed-slot fallback to ``bottom-right`` (the
shell's documented fallback for new/unrecognized displays and
malformed saved state), and persisted size-class
(compact/standard/wide) normalization and widths inside the host
cap. These tests extract the shipped blocks and run them under Node
against oracles computed independently in Python; the structural
checks (blocks identical, settings declared with pre-#32 defaults,
read-only Desktop facade use, restore affordance) always run. This
is stub/static evidence only: no live shell renders these widgets
here, and slot persistence/monitor migration are shell-owned
behaviour (Config.plugins slots per display), not plugin claims.
"""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")
PLUGINS = ("hornero-agenda", "hornero-calendar", "hornero-moon-phase")
SLOTS = [
    f"{v}-{h}"
    for v in ("top", "middle", "bottom")
    for h in ("left", "center", "right")
]
SIZE_CLASSES = ("compact", "standard", "wide")


def extract_block(plugin: str) -> str:
    text = (ROOT / "plugins" / plugin / "Main.qml").read_text()
    begin = text.index("DESKTOP-LOGIC-BEGIN")
    end = text.index("DESKTOP-LOGIC-END")
    return text[text.index("\n", begin) : end]


def run_node(block: str, driver: str, cases) -> list:
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


def manifest(plugin: str) -> dict:
    return json.loads((ROOT / "plugins" / plugin / "manifest.json").read_text())


class DesktopBlockStructure(unittest.TestCase):
    def test_blocks_present_and_identical(self):
        blocks = [extract_block(p) for p in PLUGINS]
        for block in blocks:
            self.assertIn("function normalizeSlot", block)
            self.assertIn("function sizeClassWidth", block)
        self.assertEqual(blocks[0], blocks[1], "DESKTOP-LOGIC copies must stay verbatim")
        self.assertEqual(blocks[0], blocks[2], "DESKTOP-LOGIC copies must stay verbatim")

    def test_manifests_declare_desktop_settings_with_legacy_defaults(self):
        for plugin in PLUGINS:
            m = manifest(plugin)
            self.assertEqual(m["placement"], "desktop", plugin)
            self.assertEqual(m["schemaVersion"], 2, plugin)
            self.assertEqual(
                m["surfaces"]["desktop"]["entrypoint"], m["entrypoint"], plugin
            )
            settings = m["capabilities"]["settings"]
            self.assertEqual(settings["sizeClass"]["default"], "standard", plugin)
            self.assertEqual(settings["sizeClass"]["options"], list(SIZE_CLASSES), plugin)
            self.assertIs(settings["showOnDesktop"]["default"], True, plugin)

    def test_only_read_only_desktop_facade_and_recovery_affordance(self):
        for plugin in PLUGINS:
            code = (ROOT / "plugins" / plugin / "Main.qml").read_text()
            # Desktop.position(pluginId, screenName) is the only
            # PluginKit Desktop member; there is no slot setter.
            self.assertIn(f'Desktop.position("{plugin}"', code)
            self.assertNotIn("setDesktopWidgetSlot", code)
            self.assertNotIn("Desktop.set", code)
            # Hidden content always leaves a visible restore path.
            self.assertIn("visible: !root.desktopVisible", code)
            self.assertIn('i18n.tr("Show widget")', code)
            # Size/visibility persist through typed Settings and reset.
            self.assertIn('setValue("sizeClass"', code)
            self.assertIn('setValue("showOnDesktop"', code)
            self.assertIn('resetValue("sizeClass")', code)
            self.assertIn('resetValue("showOnDesktop")', code)


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class DesktopLogicOracle(unittest.TestCase):
    DRIVER = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(JSON.stringify(cases.map(c => [
    normalizeSlot(c[0]), normalizeSizeClass(c[1]), nextSizeClass(c[1]),
    sizeClassWidth(c[1], c[2], c[3]), sizeClassCompact(c[1]) ? 1 : 0,
    desktopSlots().join(","),
])));
"""

    def test_slot_and_size_normalization(self):
        slot_inputs = SLOTS + ["", "nowhere", "TOP-LEFT", "bottom_right", None]
        size_inputs = ["compact", "standard", "wide", "", "huge", None]
        cases, expected = [], []
        widths = {
            "compact": lambda cap, std: min(220, cap if cap > 0 else 300),
            "wide": lambda cap, std: cap if cap > 0 else 300,
            "standard": lambda cap, std: min(std, cap if cap > 0 else 300),
        }
        cycle = {"compact": "standard", "standard": "wide", "wide": "compact"}
        for slot in slot_inputs:
            for size in size_inputs:
                for cap, std in ((0, 260), (300, 260), (180, 260), (300, 400)):
                    cases.append([slot, size, cap, std])
                    norm_size = size if size in SIZE_CLASSES else "standard"
                    expected.append([
                        slot if slot in SLOTS else "bottom-right",
                        norm_size,
                        cycle[norm_size],
                        widths[norm_size](cap, std),
                        1 if norm_size == "compact" else 0,
                        ",".join(SLOTS),
                    ])
        got = run_node(extract_block(PLUGINS[0]), self.DRIVER, cases)
        self.assertEqual(expected, got)


if __name__ == "__main__":
    unittest.main()
