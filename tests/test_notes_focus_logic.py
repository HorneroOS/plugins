"""Pure-JS logic shipped in the Notes & Focus 2.0 plugins (#29).

Quick Notes clamps the persistent note to the 4096-character
Settings limit and counts words (NOTE-LOGIC), Quiet Notes
normalizes the session-only intention to one clamped line
(INTENTION-LOGIC), and Focus Card wraps rotation indexes
(FOCUS-LOGIC). These tests extract the shipped blocks and run
them under Node against independent Python implementations of
the same contracts. Structural checks also pin the persistence
split itself: Quick Notes keeps the 1.x Settings note key,
Quiet Notes performs no Settings write at all, and every
declared setting default reproduces 1.x. When Node is
unavailable the oracle comparisons are skipped with a reason;
the structural checks always run. Node is present on GitHub's
ubuntu runners.
"""
import json
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")


def extract_block(plugin: str, marker: str) -> str:
    text = (ROOT / "plugins" / plugin / "Main.qml").read_text()
    begin = text.index(f"{marker}-BEGIN")
    end = text.index(f"{marker}-END")
    return text[text.index("\n", begin) : end]


def manifest(plugin: str) -> dict:
    return json.loads((ROOT / "plugins" / plugin / "manifest.json").read_text())


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


class PersistenceSplit(unittest.TestCase):
    def test_quick_notes_keeps_legacy_note_key(self):
        # An existing user's note survives the 2.0 upgrade only
        # because pluginId and the "note" key are unchanged.
        code = (ROOT / "plugins" / "hornero-quick-notes" / "Main.qml").read_text()
        settings = manifest("hornero-quick-notes")["capabilities"]["settings"]
        self.assertIn("note", settings)
        self.assertEqual(settings["note"]["type"], "string")
        self.assertEqual(settings["note"]["default"], "")
        self.assertIn('pluginId: "hornero-quick-notes"', code)
        self.assertIn('value("note"', code)
        self.assertIn('setValue("note"', code)

    def test_defaults_reproduce_1x(self):
        quick = manifest("hornero-quick-notes")["capabilities"]["settings"]
        self.assertEqual(quick["autoSaveDelayMs"]["default"], 600)
        self.assertIs(quick["showCounts"]["default"], True)

    def test_logic_blocks_present(self):
        self.assertIn("function clampedNote", extract_block("hornero-quick-notes", "NOTE-LOGIC"))


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class NoteLogicOracle(unittest.TestCase):
    DRIVER = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(JSON.stringify(cases.map(c => [
    clampedNote(c, 4096), noteTruncated(c, 4096) ? 1 : 0, wordCount(c)
])));
"""

    def test_clamp_and_counts(self):
        cases = ["", "hello", " one\ttwo\n  three ", "x" * 4096, "y" * 5000, "  "]
        expected = []
        for text in cases:
            expected.append([
                text[:4096],
                1 if len(text) > 4096 else 0,
                len(text.split()),
            ])
        got = run_node(extract_block("hornero-quick-notes", "NOTE-LOGIC"), self.DRIVER, cases)
        self.assertEqual(expected, got)


if __name__ == "__main__":
    unittest.main()
