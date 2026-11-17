"""Emoji search logic and data of hornero-emoji (Stowaway, launcher + picker).

EmojiSearch.js is a `.pragma library` module shared by the launcher provider
and the dashboard card; the tests run it under Node against the generated
Unicode 16.0 table and check the table itself (structure, tone variants,
provenance header) without Node. Node is present on GitHub's ubuntu runners;
the Node-backed tests skip with a reason when it is missing.
"""
import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGIN = ROOT / "plugins" / "hornero-emoji"
NODE = shutil.which("node")


def table_lines():
    source = (PLUGIN / "EmojiData.qml").read_text(encoding="utf-8")
    match = re.search(r'property string raw: "(.*)"\n', source)
    assert match, "EmojiData.qml must carry the raw table"
    return json.loads('"' + match.group(1) + '"').split("\n")


def run_js(driver: str):
    src = (PLUGIN / "EmojiSearch.js").read_text(encoding="utf-8").replace(".pragma library", "", 1)
    raw = json.dumps("\n".join(table_lines()))
    proc = subprocess.run([NODE, "-"], input=f"const RAW = {raw};\n{src}\n{driver}", capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


class TableTests(unittest.TestCase):
    def test_table_is_unicode_16_with_attribution(self):
        source = (PLUGIN / "EmojiData.qml").read_text(encoding="utf-8")
        self.assertIn('unicodeVersion: "16.0"', source)
        self.assertIn("Unicode License v3", source)
        self.assertIn("Unicode License v3", (PLUGIN / "README.md").read_text(encoding="utf-8"))

    def test_lines_are_well_formed_and_unique(self):
        lines = table_lines()
        self.assertGreater(len(lines), 1800)
        seen = set()
        tones = 0
        for line in lines:
            parts = line.split("|")
            self.assertEqual(len(parts), 4, line)
            emoji, name, group, variants = parts
            self.assertTrue(emoji and name, line)
            self.assertIn(group, {"smileys", "people", "nature", "food", "travel", "activities", "objects", "symbols", "flags"})
            self.assertNotIn(emoji, seen)
            seen.add(emoji)
            if variants:
                tones += 1
                self.assertEqual(len(variants.split(",")), 5, line)
        self.assertGreater(tones, 250)

    def test_manifest_settings_match_the_logic(self):
        manifest = json.loads((PLUGIN / "manifest.json").read_text())
        options = manifest["capabilities"]["settings"]["skinTone"]["options"]
        js = (PLUGIN / "EmojiSearch.js").read_text()
        for option in options:
            self.assertIn(f'"{option}"', js)
        self.assertEqual(manifest["capabilities"]["networkHosts"], [])
        self.assertEqual(manifest["capabilities"]["processCommands"], ["wl-copy"])


@unittest.skipUnless(NODE, "node is required to execute EmojiSearch.js")
class SearchTests(unittest.TestCase):
    def test_ranking_and_matching(self):
        out = run_js("""
const e = parse(RAW);
const top = q => search(e, q, 6).map(x => x.name);
console.log(JSON.stringify({
  grin: top("grin"),
  exact: top("fire"),
  words: top("heart eyes"),
  group: top("flags").length,
  none: top("zzzzzz"),
  empty: search(e, "", 3).map(x => x.char),
  limit: search(e, "face", 1000).length > 100
}));""")
        self.assertEqual(out["grin"][0], "grinning face")
        self.assertEqual(out["exact"][0], "fire")
        self.assertTrue(any("heart-eyes" in name for name in out["words"]))
        self.assertEqual(out["none"], [])
        self.assertEqual(out["empty"], ["\U0001F600", "\U0001F603", "\U0001F604"])
        self.assertEqual(out["group"], 6)
        self.assertTrue(out["limit"])

    def test_skin_tone_applies_only_where_variants_exist(self):
        out = run_js("""
const e = parse(RAW);
const wave = search(e, "waving hand", 1)[0];
const grin = search(e, "grinning face", 1)[0];
console.log(JSON.stringify({
  def: glyphFor(wave, "default"),
  light: glyphFor(wave, "light"),
  dark: glyphFor(wave, "dark"),
  grin: glyphFor(grin, "dark") === grin.char,
  unknown: glyphFor(wave, "purple") === wave.char
}));""")
        self.assertEqual(out["def"], "\U0001F44B")
        self.assertEqual(out["light"], "\U0001F44B\U0001F3FB")
        self.assertEqual(out["dark"], "\U0001F44B\U0001F3FF")
        self.assertTrue(out["grin"] and out["unknown"])

    def test_rows_copy_the_emoji_and_label_with_the_name(self):
        out = run_js("""
const e = parse(RAW);
console.log(JSON.stringify(rowsFor(e, "fire", "default", 2, true, g => "G:" + g)));""")
        self.assertEqual(out[0]["text"], "\U0001F525")
        self.assertEqual(out[0]["title"], "\U0001F525  fire")
        self.assertEqual(out[0]["subtitle"], "G:travel")


if __name__ == "__main__":
    unittest.main()
