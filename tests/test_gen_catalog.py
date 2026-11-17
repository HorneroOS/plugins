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
        # No official package requires level 4 yet: entries are unchanged.
        self.assertTrue(all("pluginKit" not in e for e in built["plugins"]))
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


if __name__ == "__main__":
    unittest.main()
