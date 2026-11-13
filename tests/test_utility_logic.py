"""Pure-JS utility logic shipped in the Utility Tools 2.0 plugins (#30).

Each of the seven packages carries one LOGIC block verbatim in its
bar (Main.qml), dashboard (Dashboard.qml) and declaration-only
launcher (Launcher.qml) entrypoints, because plugins cannot share
code across files. These tests extract the shipped blocks and run
them under Node against independent Python oracles (arithmetic via
Python operators on hand-picked cases, colorsys for HSL, json for
JSON round-trips, datetime for date math, Python int formatting for
bases) plus the 1.x documented formulas. The structural checks
(blocks present, copies identical, launcher/dashboard surfaces and
typed defaults declared) always run; when Node is unavailable the
oracle comparisons are skipped with a reason. This is stub-level
evidence for the pure logic only: no plugin is rendered and the
launcher surface has no host yet (HorneroOS/shell#250).
"""
import colorsys
import json
import shutil
import subprocess
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")

PLUGINS = [
    "hornero-calculator",
    "hornero-unit-converter",
    "hornero-text-tools",
    "hornero-color-converter",
    "hornero-json-tools",
    "hornero-base-converter",
    "hornero-date-calculator",
]

# Typed settings whose defaults must reproduce the 1.x behaviour.
EXPECTED_DEFAULTS = {
    "hornero-calculator": {"showKeypad": True, "liveResult": False},
    "hornero-unit-converter": {"defaultCategory": "length", "precision": 6},
    "hornero-text-tools": {"defaultMode": "uppercase", "showCounts": True},
    "hornero-color-converter": {"defaultHex": "#336699", "showPreview": True},
    "hornero-json-tools": {"indentSpaces": 2, "defaultAction": "format"},
    "hornero-base-converter": {"uppercaseHex": True},
    "hornero-date-calculator": {"showUtcNote": True},
}


def extract_block(plugin: str, filename: str) -> str:
    text = (ROOT / "plugins" / plugin / filename).read_text()
    begin = text.index("LOGIC-BEGIN")
    end = text.index("LOGIC-END")
    return text[text.index("\n", begin) : end]


def run_node(plugin: str, driver: str, cases) -> list:
    block = extract_block(plugin, "Launcher.qml")
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


DRIVER = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(JSON.stringify(cases.map(c => quickResult(...c))));
"""


class Structure(unittest.TestCase):
    def test_logic_blocks_identical_across_surfaces(self):
        for plugin in PLUGINS:
            blocks = [extract_block(plugin, f) for f in ("Main.qml", "Dashboard.qml", "Launcher.qml")]
            self.assertIn("function quickResult", blocks[0], plugin)
            self.assertEqual(blocks[0], blocks[1], f"{plugin}: Main/Dashboard LOGIC drift")
            self.assertEqual(blocks[0], blocks[2], f"{plugin}: Main/Launcher LOGIC drift")

    def test_manifests_declare_quick_surfaces_and_defaults(self):
        for plugin in PLUGINS:
            m = json.loads((ROOT / "plugins" / plugin / "manifest.json").read_text())
            self.assertEqual(m["schemaVersion"], 2, plugin)
            self.assertEqual(m["version"], "2.0.0", plugin)
            self.assertEqual(m["placement"], "bar", plugin)
            self.assertEqual(m["surfaces"]["launcher"]["entrypoint"], "Launcher.qml", plugin)
            dash = m["surfaces"]["dashboard"]
            self.assertEqual((dash["size"], dash["category"]), ("compact", "Utilities"), plugin)
            settings = m["capabilities"]["settings"]
            self.assertEqual(set(settings), set(EXPECTED_DEFAULTS[plugin]), plugin)
            for key, default in EXPECTED_DEFAULTS[plugin].items():
                self.assertEqual(settings[key]["default"], default, f"{plugin}:{key}")

    def test_launcher_gap_is_documented_not_faked(self):
        for plugin in PLUGINS:
            readme = (ROOT / "plugins" / plugin / "README.md").read_text()
            self.assertIn("shell#250", readme, plugin)
            self.assertIn("not loaded", readme, plugin)
            launcher = (ROOT / "plugins" / plugin / "Launcher.qml").read_text()
            self.assertIn("VALIDATED DECLARATION ONLY", launcher, plugin)


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class CalculatorOracle(unittest.TestCase):
    def test_expressions(self):
        cases = [["2+3"], ["(2 + 3) * 4"], ["10 / 4"], ["-3 + 1"], ["7 % 3"],
                 ["2 * -3"], ["1.5 * 2"], ["1/0"], ["2+"], [""], ["2..3"], ["(1+2"]]
        expected = ["5", "20", "2.5", "-2", "1", "-6", "3"] + ["Error"] * 5
        got = run_node("hornero-calculator", DRIVER, cases)
        self.assertEqual([g["text"] for g in got], expected)


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class UnitOracle(unittest.TestCase):
    def test_quick_conversions_against_documented_formulas(self):
        def expected(v, f, t):
            base = {"km": v * 1000, "mi": v * 1000 / 0.621371, "ft": v * 0.3048,
                    "lb": v / 2.20462, "F": (v - 32) * 5 / 9, "K": v - 273.15}.get(f, v)
            out = {"km": base / 1000, "mi": base / 1000 * 0.621371, "ft": base / 0.3048,
                   "lb": base * 2.20462, "F": base * 9 / 5 + 32, "K": base + 273.15}.get(t, base)
            return round(out, 6)

        good = [(10, "km", "mi"), (1, "m", "ft"), (70, "kg", "lb"), (100, "C", "F"),
                (32, "F", "C"), (0, "C", "K"), (5, "mi", "km")]
        cases = [[f"{v} {f} to {t}", 6] for v, f, t in good]
        cases += [["10 km kg", 6], ["ten km mi", 6], ["", 6], ["10 xx yy", 6]]
        got = run_node("hornero-unit-converter", DRIVER, cases)
        for (v, f, t), g in zip(good, got):
            self.assertTrue(g["ok"], (v, f, t))
            shown = float(g["text"].split(" = ")[1].rsplit(" ", 1)[0])
            self.assertAlmostEqual(shown, expected(v, f, t), places=6)
        self.assertEqual([g["ok"] for g in got[len(good):]], [False] * 4)


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class TextOracle(unittest.TestCase):
    def test_transforms_and_counts(self):
        cases = [["hola mundo", "uppercase"], ["HOLA", "lowercase"],
                 ["hola   mundo\nnueva linea", "title-case"], ["abc", "reverse"]]
        got = run_node("hornero-text-tools", DRIVER, cases)
        self.assertEqual([g["text"] for g in got],
                         ["HOLA MUNDO", "hola", "Hola   Mundo\nNueva Linea", "cba"])
        self.assertEqual([(g["characters"], g["words"], g["lines"]) for g in got],
                         [(10, 2, 1), (4, 1, 1), (24, 4, 2), (3, 1, 1)])


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class ColorOracle(unittest.TestCase):
    def test_hex_rgb_hsl_against_colorsys(self):
        cases = [["#336699"], ["#369"], ["#FF0000"], ["#00FF80"], ["336699"], ["#12"], ["#GGGGGG"]]
        got = run_node("hornero-color-converter", DRIVER, cases)
        for g, hexv in zip(got[:4], cases[:4]):
            self.assertTrue(g["ok"], hexv)
            h, li, s = colorsys.rgb_to_hls(g["r"] / 255, g["g"] / 255, g["b"] / 255)  # colorsys order is H,L,S
            self.assertIn(f"HSL: {round(h * 360)}, {round(s * 100)}%, {round(li * 100)}%", g["text"])
        self.assertEqual((got[0]["r"], got[0]["g"], got[0]["b"]), (51, 102, 153))
        self.assertEqual((got[1]["r"], got[1]["g"], got[1]["b"]), (51, 102, 153))
        self.assertEqual([g["ok"] for g in got[4:]], [False] * 3)


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class JsonOracle(unittest.TestCase):
    def test_format_minify_and_errors(self):
        payload = {"b": [1, 2.5, None, True], "a": {"x": "y"}}
        raw = json.dumps(payload)
        cases = [[raw, 2, "format"], [raw, 2, "minify"], ["{bad", 2, "format"], ["", 2, "minify"]]
        got = run_node("hornero-json-tools", DRIVER, cases)
        self.assertEqual(json.loads(got[0]["text"]), payload)
        self.assertIn("\n  ", got[0]["text"])  # 2-space indentation, the 1.x default
        self.assertEqual(got[1]["text"], json.dumps(payload, separators=(",", ":")))
        self.assertEqual([(g["ok"], g["text"] == "") for g in got[2:]], [(False, True)] * 2)
        self.assertTrue(all(g["error"] for g in got[2:]))


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class BaseOracle(unittest.TestCase):
    def test_bases_against_python_int(self):
        numbers = [0, 1, 255, -42, 9007199254740991]
        cases = [[str(n), True] for n in numbers] + [["0xFF"], ["-0x2A"], ["12.5"], ["FF"]]
        got = run_node("hornero-base-converter", DRIVER, cases)
        for n, g in zip(numbers, got):
            self.assertTrue(g["ok"], n)
            self.assertEqual(
                g["text"],
                f"Binary: {n:b}\nOctal: {n:o}\nHex: {n:X}".replace("-", "-", 1)
                if n >= 0 else f"Binary: -{abs(n):b}\nOctal: -{abs(n):o}\nHex: -{abs(n):X}",
            )
        self.assertEqual(got[5]["text"], "Decimal: 255")
        self.assertEqual(got[6]["text"], "Decimal: -42")
        # Bare "FF" is not guessed as hex on the quick path; 12.5 is not an integer.
        self.assertEqual([g["ok"] for g in got[7:]], [False, False])


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class DateOracle(unittest.TestCase):
    def test_dates_against_datetime(self):
        pairs = [(date(2026, 1, 1), date(2026, 2, 1)), (date(2024, 2, 28), date(2024, 3, 1)),
                 (date(2026, 3, 1), date(2026, 1, 1))]
        adds = [(date(2026, 1, 31), 1), (date(2024, 2, 28), 1), (date(2026, 1, 1), -1)]
        cases = [[f"{a} {b}"] for a, b in pairs] + [[f"{a} {n:+d}"] for a, n in adds]
        cases += [["2026-02-30 2026-03-01"], ["2026-01-01 1.5"], ["2026-01-01"]]
        got = run_node("hornero-date-calculator", DRIVER, cases)
        expected = [f"Days between: {(b - a).days}" for a, b in pairs]
        expected += [f"Resulting date: {a + timedelta(days=n)}" for a, n in adds]
        self.assertEqual([g["text"] for g in got[:6]], expected)
        self.assertEqual([g["ok"] for g in got[6:]], [False] * 3)


if __name__ == "__main__":
    unittest.main()
