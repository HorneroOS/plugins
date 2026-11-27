import importlib.util
import json
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "gen_catalog.py"
spec = importlib.util.spec_from_file_location("gen_catalog", SCRIPT)
gen_catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen_catalog)


def catalog(stamp, plugins):
    return json.dumps({"schemaVersion": 1, "generatedFrom": stamp, "plugins": plugins})


class PluginKitLevelTest(unittest.TestCase):
    def test_level_is_recorded_only_above_the_baseline(self):
        built = gen_catalog.build()
        # A level is recorded exactly for the packages that need more than
        # the baseline (hornero-clipboard needs 4); the rest are unchanged.
        by_id = {e["id"]: e for e in built["plugins"]}
        for e in built["plugins"]:
            if "pluginKit" in e:
                self.assertGreater(e["pluginKit"], 3, e["id"])
        self.assertEqual(by_id["hornero-clipboard"]["pluginKit"], 4)
        self.assertNotIn("pluginKit", by_id["hornero-battery"])
        source = SCRIPT.read_text()
        self.assertIn('manifest.get("pluginKit", 3) != 3', source)


class CatalogFreshnessTest(unittest.TestCase):
    def setUp(self):
        self.built = {
            "schemaVersion": 1,
            "generatedFrom": "b" * 40,
            "plugins": [{"id": "hornero-example"}],
        }

    def test_stale_stamp_same_entries_is_current(self):
        # Squash merges rewrite the stamped commit; entries decide.
        self.assertTrue(
            gen_catalog.catalog_is_current(
                catalog("a" * 40, [{"id": "hornero-example"}]), self.built
            )
        )

    def test_changed_entry_is_stale(self):
        self.assertFalse(
            gen_catalog.catalog_is_current(
                catalog("a" * 40, [{"id": "hornero-other"}]), self.built
            )
        )

    def test_short_stamp_is_stale(self):
        self.assertFalse(
            gen_catalog.catalog_is_current(
                catalog("abc", [{"id": "hornero-example"}]), self.built
            )
        )

    def test_invalid_json_is_stale(self):
        self.assertFalse(gen_catalog.catalog_is_current("{nope", self.built))


class StoreFieldsTest(unittest.TestCase):
    """Fields Control Center > Extensions shows before install (gap #4)."""

    @classmethod
    def setUpClass(cls):
        cls.built = gen_catalog.build()
        cls.by_id = {e["id"]: e for e in cls.built["plugins"]}

    def test_every_entry_has_bilingual_permission_lines(self):
        for entry in self.built["plugins"]:
            self.assertIn("permissions", entry, entry["id"])
            for line in entry["permissions"]:
                self.assertIn(line["kind"], {"program", "network", "data", "action", "settings"})
                self.assertTrue(line["en"].strip() and line["es"].strip(), (entry["id"], line))

    def test_each_declared_program_and_host_has_a_curated_reason(self):
        for entry in self.built["plugins"]:
            caps = entry["capabilities"]
            lines = {(l["kind"], l["value"]) for l in entry["permissions"]}
            for cmd in caps.get("processCommands", []):
                self.assertIn(("program", cmd), lines, entry["id"])
            for host in caps.get("networkHosts", []):
                self.assertIn(("network", host), lines, entry["id"])
        forge = {l["value"]: l for l in self.by_id["hornero-forge-board"]["permissions"]}
        self.assertIn("api.github.com", forge)
        self.assertIn("Solo lectura", forge["gh"]["es"])

    def test_missing_reason_fails_generation(self):
        with self.assertRaises(SystemExit) as ctx:
            gen_catalog.permission_lines("hornero-x", {"processCommands": ["curl"]}, {})
        self.assertIn("program:curl", str(ctx.exception))

    def test_reason_for_an_undeclared_use_fails(self):
        notes = {"hornero-x": {"program:curl": {"en": "a", "es": "b"}}}
        with self.assertRaises(SystemExit):
            gen_catalog.permission_lines("hornero-x", {}, notes)

    def test_providers_are_plain_language(self):
        lines = gen_catalog.permission_lines("hornero-x", {"providers": ["system"]}, {})
        self.assertEqual(lines[0]["kind"], "data")
        self.assertIn("CPU", lines[0]["en"])
        self.assertIn("solo lectura", lines[0]["es"])

    def test_marketplace_changelog_reaches_the_catalogue(self):
        agenda = self.by_id["hornero-agenda"]
        self.assertEqual(agenda["marketplace"]["changelog"][0]["version"], agenda["version"])

    def test_screenshots_are_hashed_files_outside_the_payload(self):
        import hashlib
        shot_entries = [e for e in self.built["plugins"] if e.get("screenshots")]
        self.assertGreater(len(shot_entries), 0)
        for entry in shot_entries:
            for shot in entry["screenshots"]:
                self.assertTrue(shot["path"].startswith("docs/screenshots/"))
                data = (gen_catalog.ROOT / shot["path"]).read_bytes()
                self.assertEqual(hashlib.sha256(data).hexdigest(), shot["sha256"])
                self.assertEqual(len(data), shot["bytes"])
                plugin_dir = gen_catalog.ROOT / entry["path"]
                manifest = json.loads((plugin_dir / "manifest.json").read_text(encoding="utf-8"))
                payload = {f"{entry['path']}/{name}" for name in ["manifest.json", *manifest.get("files", [])]}
                self.assertNotIn(shot["path"], payload)
                self.assertFalse(shot["path"].startswith(entry["path"] + "/"))


    def test_catalog_source_is_pinned_and_verifiable(self):
        # Client compatibility contract v1: a consumer can state
        # exactly which upstream revision the entries came from.
        source = self.built.get("catalogSource")
        self.assertIsInstance(source, dict)
        self.assertEqual(source.get("repo"), "https://github.com/HorneroOS/plugins")
        self.assertEqual(source.get("rev"), self.built.get("generatedFrom"))
        self.assertEqual(len(source.get("rev", "")), 40)

    def test_every_official_plugin_has_explicit_category(self):
        plugin_ids = {p.name for p in gen_catalog.PLUGINS.iterdir() if p.is_dir()}
        missing = sorted(plugin_ids - set(gen_catalog.CATEGORIES))
        self.assertEqual(missing, [], f"Missing explicit CATEGORIES entries: {missing}")
        self.assertEqual(self.by_id["hornero-tailscale"]["category"], "system")
        self.assertEqual(self.by_id["hornero-elsewhen"]["category"], "productivity")


if __name__ == "__main__":
    unittest.main()
