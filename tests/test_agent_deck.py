"""Agent Deck (hornero-ai-usage 4.0, plugins#22): structural contract."""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / "plugins" / "hornero-ai-usage"
MANIFEST = json.loads((PKG / "manifest.json").read_text())


def read(name: str) -> str:
    return (PKG / name).read_text()


class AgentDeckContractTests(unittest.TestCase):
    def test_agents_page_is_contributed_not_hardcoded(self):
        self.assertEqual(MANIFEST["pluginKit"], 5)
        self.assertEqual(
            MANIFEST["contributes"]["dashboardTabs"],
            [{"id": "agents", "title": "Agents", "glyph": "robot"}],
        )
        self.assertEqual(MANIFEST["surfaces"]["dashboardTab"]["entrypoint"], "Agents.qml")
        self.assertIn("Agents.qml", MANIFEST["files"])

    def test_ui_never_touches_credentials_or_network(self):
        self.assertEqual(MANIFEST["capabilities"]["networkHosts"], [])
        self.assertEqual(sorted(MANIFEST["capabilities"]["processCommands"]), ["horneroctl", "qs"])
        for name in ("Bar.qml", "Main.qml", "Agents.qml", "UsageData.qml"):
            src = read(name)
            for forbidden in ("credentials.json", "accessToken", "state.vscdb", "auth.json", "XMLHttpRequest"):
                self.assertNotIn(forbidden, src, f"{name} must not reference {forbidden}")

    def test_unknown_quota_is_never_rendered_as_zero(self):
        for name in ("Bar.qml", "Main.qml", "Agents.qml"):
            src = read(name)
            self.assertIn("windowsOf", src)
            self.assertIn("Quota: unknown", src)
        data = read("UsageData.qml")
        # Windows come from quotaWindows (v2) with the v1 mirror only
        # when the provider itself reported quota "available".
        self.assertIn("quotaWindows", data)
        self.assertIn('record.quota === "available"', data)

    def test_record_arrays_survive_qml_property_boundaries(self):
        # JSON arrays become QVariantLists across QML properties;
        # Array.isArray on them is False and silently dropped every
        # quota window on the live host (4.0.1). Length checks only.
        for name in ("Bar.qml", "Main.qml", "Agents.qml", "UsageData.qml"):
            src = read(name)
            self.assertNotIn("Array.isArray(record.", src, name)
            self.assertNotIn("Array.isArray(modelData.", src, name)
            self.assertNotIn("Array.isArray(root.current.", src, name)

    def test_no_cross_provider_token_summing_in_bar(self):
        bar = read("Bar.qml")
        self.assertNotIn("totalTokensAll", bar)
        self.assertIn("worstPercent", bar)
        data = read("UsageData.qml")
        # Account-scope records never join the local token total.
        self.assertIn('record.scope !== "account"', data)

    def test_popover_deep_links_to_agents_page(self):
        bar = read("Bar.qml")
        self.assertIn('"drawers", "dashboardTab", "hornero-ai-usage:agents"', bar)


if __name__ == "__main__":
    unittest.main()
