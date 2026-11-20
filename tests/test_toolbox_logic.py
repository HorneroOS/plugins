"""Oracle tests for the absorbed utility logic in hornero-toolbox.

Replaces test_utility_logic.py, whose subjects (the seven single-purpose
utility extensions) were retired into hornero-toolbox and then physically
removed from the catalogue (owner decision, 2026-11-20).
"""
import json, shutil, subprocess, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")


def toolbox_block() -> str:
    text = (ROOT / "plugins" / "hornero-toolbox" / "Main.qml").read_text()
    begin = text.index("TOOLBOX-LOGIC-BEGIN")
    end = text.index("TOOLBOX-LOGIC-END")
    return text[text.index("\n", begin):end]


def run_node(exprs):
    driver = (
        "const cases = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));\n"
        "process.stdout.write(JSON.stringify(cases.map(c => eval(c))));\n"
    )
    with tempfile.TemporaryDirectory() as tmp:
        script = Path(tmp) / "harness.js"
        cases_file = Path(tmp) / "cases.json"
        script.write_text(toolbox_block() + "\n" + driver)
        cases_file.write_text(json.dumps(exprs))
        out = subprocess.run([NODE, str(script), str(cases_file)], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


class Structure(unittest.TestCase):
    def test_manifest(self):
        m = json.loads((ROOT / "plugins" / "hornero-toolbox" / "manifest.json").read_text())
        self.assertEqual(m["schemaVersion"], 3)

    def test_logic_block_present(self):
        block = toolbox_block()
        for fn in ("calcText", "convertUnit", "convertDecText", "convertHexText",
                   "parseHex", "daysBetweenText", "formatJsonText", "transformText"):
            self.assertIn(f"function {fn}", block)


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class ToolboxOracle(unittest.TestCase):
    def test_calculator(self):
        exprs = [f"calcText({json.dumps(e)})" for e in
                 ["2+3", "(2 + 3) * 4", "10 / 4", "-3 + 1", "7 % 3", "2 * -3", "1.5 * 2"]]
        got = run_node(exprs)
        self.assertEqual([g["text"] for g in got], ["5", "20", "2.5", "-2", "1", "-6", "3"])
        bad = run_node([f"calcText({json.dumps(e)})" for e in ["1/0", "2+", "", "2..3", "(1+2"]])
        self.assertTrue(all(not g["ok"] for g in bad))

    def test_units(self):
        got = run_node([
            'convertUnit(1,"length","km","mi")',
            'convertUnit(100,"temperature","C","F")',
            'convertUnit(1,"mass","kg","lb")',
        ])
        self.assertAlmostEqual(got[0], 0.621371, places=5)
        self.assertEqual(got[1], 212)
        self.assertAlmostEqual(got[2], 2.20462, places=4)

    def test_bases_and_color(self):
        got = run_node(['convertDecText("255", true)', 'convertHexText("FF")',
                        'parseHex("#336699")', 'toHex(51,102,153)'])
        self.assertEqual(got[0]["hex"], "FF")
        self.assertEqual(got[1]["dec"], "255")
        self.assertEqual(got[2], {"r": 51, "g": 102, "b": 153})
        self.assertEqual(got[3], "#336699")

    def test_dates_json_text(self):
        got = run_node([
            'daysBetweenText("2026-01-01","2026-01-31")',
            'addDaysText("2026-01-31","1")',
            'formatJsonText("{\\"a\\":1}", 2)',
            'minifyJsonText("{ \\"a\\": 1 }")',
            'transformText("hola mundo","uppercase")',
            'countWordsText("uno dos  tres")',
        ])
        self.assertEqual(got[0]["days"], 30)
        self.assertEqual(got[1]["text"], "2026-02-01")
        self.assertIn('"a": 1', got[2]["text"])
        self.assertEqual(got[3]["text"], '{"a":1}')
        self.assertEqual(got[4], "HOLA MUNDO")
        self.assertEqual(got[5], 3)


if __name__ == "__main__":
    unittest.main()
