"""Privacy and logic contract of hornero-clipboard (Stowaway, launcher + commands).

History.js is the single in-memory store shared by the launcher recorder, the
card and the command handler. The tests execute it under Node (skipped with a
reason when Node is missing; it is present on GitHub's ubuntu runners) and
check the structural privacy promises without Node: no disk or network API,
the manifest's disclosure, the PluginKit 4 commands and the Settings contract.
"""
import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGIN = ROOT / "plugins" / "hornero-clipboard"
NODE = shutil.which("node")


def run_js(driver: str):
    src = (PLUGIN / "History.js").read_text(encoding="utf-8").replace(".pragma library", "", 1)
    proc = subprocess.run([NODE, "-"], input=f"{src}\n{driver}", capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


class PrivacyStructureTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((PLUGIN / "manifest.json").read_text())
        self.sources = {p.name: p.read_text(encoding="utf-8") for p in PLUGIN.iterdir() if p.suffix in (".qml", ".js")}

    def test_nothing_is_persisted_or_sent(self):
        everything = "\n".join(self.sources.values())
        for needle in ("FileView", "writeFile", "XMLHttpRequest", "WebSocket", "localStorage", "Qt.labs.settings", "cliphist", "tee", "console.log"):
            self.assertNotIn(needle, everything, needle)
        # The only place clipboard text may enter Settings is nowhere: the
        # recording flag is the only value this extension writes.
        writes = re.findall(r'setValue\("([A-Za-z]+)"', everything)
        self.assertEqual(sorted(set(writes)), ["recording"])
        self.assertEqual(self.manifest["capabilities"]["networkHosts"], [])
        self.assertEqual(self.manifest["capabilities"]["processCommands"], ["wl-paste", "echo"])

    def test_defaults_are_private(self):
        settings = self.manifest["capabilities"]["settings"]
        self.assertTrue(settings["skipSensitive"]["default"])
        self.assertLessEqual(settings["retentionMinutes"]["default"], 120)
        self.assertGreater(settings["retentionMinutes"]["default"], 0)
        self.assertLessEqual(settings["maxChars"]["default"], 5000)

    def test_pluginkit4_commands_match_the_handler(self):
        self.assertEqual(self.manifest["pluginKit"], 4)
        ids = [c["id"] for c in self.manifest["contributes"]["commands"]]
        self.assertEqual(ids, ["pause", "resume", "clear"])
        handler = self.sources["Commands.qml"]
        for command in ids:
            self.assertIn(f'"{command}"', handler)
        self.assertIn("function run(commandId: string, args: string): string", handler)

    def test_watcher_is_gated_on_the_recording_setting_and_skips_the_first_event(self):
        launcher = self.sources["Launcher.qml"]
        self.assertIn("running: root.recording", launcher)
        self.assertIn("Date.now() - root.startedAt < 500", launcher)
        self.assertIn('"--list-types"', launcher)
        self.assertIn("skipSensitive", launcher)


@unittest.skipUnless(NODE, "node is required to execute History.js")
class HistoryLogicTests(unittest.TestCase):
    def test_add_dedupes_trims_and_orders_newest_first(self):
        out = run_js("""
add("a", 1000, 3); add("b", 2000, 3); add("a", 3000, 3); add("c", 4000, 3); add("d", 5000, 3);
console.log(JSON.stringify({order: search("", 10).map(i => i.text), count: count()}));""")
        self.assertEqual(out["order"], ["d", "c", "a"])
        self.assertEqual(out["count"], 3)

    def test_search_requires_every_word_case_insensitively(self):
        out = run_js("""
add("Hello World", 1, 10); add("hello there", 2, 10); add("other", 3, 10);
console.log(JSON.stringify({both: search("WORLD hello", 5).map(i => i.text), one: search("hello", 5).map(i => i.text), none: search("zzz", 5), limit: search("", 2).length}));""")
        self.assertEqual(out["both"], ["Hello World"])
        self.assertEqual(out["one"], ["hello there", "Hello World"])
        self.assertEqual(out["none"], [])
        self.assertEqual(out["limit"], 2)

    def test_retention_purge_and_clear(self):
        out = run_js("""
add("old", 0, 10); add("new", 10 * 60000, 10);
purge(11 * 60000, 5);
const after = search("", 10).map(i => i.text);
purge(100 * 60000, 0);
const keep = count();
clear();
console.log(JSON.stringify({after, keep, cleared: count()}));""")
        self.assertEqual(out["after"], ["new"])
        self.assertEqual(out["keep"], 1)  # 0 minutes keeps everything
        self.assertEqual(out["cleared"], 0)

    def test_acceptable_blocks_blank_long_and_excluded(self):
        out = run_js("""
console.log(JSON.stringify([
  acceptable("fine text", 100, ""),
  acceptable("   ", 100, ""),
  acceptable("x".repeat(101), 100, ""),
  acceptable("my Password is x", 100, "password, token"),
  acceptable("a token here", 100, " , token ,"),
  acceptable(5, 100, ""),
  acceptable("ok", 100, ",,")
]));""")
        self.assertEqual(out, [True, False, False, False, False, False, True])

    def test_offer_decision_skips_secrets_and_non_text(self):
        out = run_js("""
const text = "text/plain;charset=utf-8\\nUTF8_STRING\\nTEXT";
console.log(JSON.stringify([
  offerDecision(text, true),
  offerDecision(text + "\\nx-kde-passwordManagerHint", true),
  offerDecision(text + "\\nx-kde-passwordManagerHint", false),
  offerDecision("image/png\\n", true),
  offerDecision("", true),
  offerDecision(null, true)
]));""")
        self.assertEqual(out, ["ok", "sensitive", "ok", "no-text", "no-text", "no-text"])

    def test_age_label_parts(self):
        out = run_js("""
console.log(JSON.stringify([ageLabelParts(5000, 1000), ageLabelParts(125000, 0), ageLabelParts(7300000, 0)]));""")
        self.assertEqual(out[0]["unit"], "now")
        self.assertEqual(out[1], {"unit": "min", "n": 2})
        self.assertEqual(out[2], {"unit": "hour", "n": 2})


if __name__ == "__main__":
    unittest.main()
