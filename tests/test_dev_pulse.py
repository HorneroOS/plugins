"""Dev Pulse (hornero-github-stats 1.0): structural contract."""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PKG = ROOT / "plugins" / "hornero-github-stats"
MANIFEST = json.loads((PKG / "manifest.json").read_text())


def read(name: str) -> str:
    return (PKG / name).read_text()


class DevPulseContractTests(unittest.TestCase):
    def test_dev_pulse_page_is_contributed_not_hardcoded(self):
        self.assertEqual(MANIFEST["pluginKit"], 5)
        self.assertEqual(
            MANIFEST["contributes"]["dashboardTabs"],
            [{"id": "devpulse", "title": "Dev Pulse", "glyph": "activity"}],
        )
        self.assertEqual(MANIFEST["surfaces"]["dashboardTab"]["entrypoint"], "DevPulse.qml")
        self.assertEqual(MANIFEST["surfaces"]["bar"]["entrypoint"], "Bar.qml")
        for name in ("Main.qml", "Bar.qml", "DevPulse.qml", "GithubData.qml"):
            self.assertIn(name, MANIFEST["files"])

    def test_ui_never_runs_gh_or_touches_tokens_or_network(self):
        self.assertEqual(MANIFEST["capabilities"]["networkHosts"], [])
        self.assertEqual(sorted(MANIFEST["capabilities"]["processCommands"]), ["horneroctl", "qs", "xdg-open"])
        for name in ("Bar.qml", "Main.qml", "DevPulse.qml", "GithubData.qml"):
            src = read(name)
            for forbidden in ("auth token", "accessToken", "credentials.json", "auth.json",
                              "XMLHttpRequest", '"gh"', "'gh'", "api.github.com"):
                self.assertNotIn(forbidden, src, f"{name} must not reference {forbidden}")

    def test_data_layer_consumes_only_horneroctl(self):
        data = read("GithubData.qml")
        self.assertIn('"horneroctl", "github", "stats"', data)
        self.assertIn('"horneroctl", "github", "inbox"', data)
        self.assertIn('"horneroctl", "agent", "usage"', data)
        self.assertIn("stats-calendar", data)
        self.assertIn("stats-totals", data)

    def test_unknown_metrics_are_not_zero_filled(self):
        page = read("DevPulse.qml")
        # Windowed totals render only when the backend reported them.
        self.assertIn("prsCreated !== undefined", page)
        self.assertIn("available:", page)

    def test_ai_comparison_is_temporal_only(self):
        data = read("GithubData.qml")
        page = read("DevPulse.qml")
        self.assertIn("scope === \"account\"", data)
        self.assertIn("NOT ATTRIBUTION", page)
        self.assertIn("No pull request is attributed to an agent from timing alone.", page)

    def test_reactions_use_existing_governed_kinds_only(self):
        data = read("GithubData.qml")
        self.assertIn('Companion.react("hornero-github-stats", "build.failed"', data)
        self.assertIn('Companion.react("hornero-github-stats", "attention"', data)
        self.assertNotIn("github.pr", data)
        self.assertNotIn("github.check", data)
        # First sight is a baseline, never a replay of history.
        self.assertIn("_prevFailing !== null", data)

    def test_popover_and_inbox_open_real_urls(self):
        for name in ("Bar.qml", "DevPulse.qml"):
            src = read(name)
            self.assertIn("xdg-open", src)
            self.assertIn("modelData.url", src)

    def test_data_layer_id_never_shadows_item_data(self):
        # `data` is Item's default children property: an id named
        # `data` is shadowed inside Repeater delegates, which broke
        # the activity-window selector (setStatsWindow resolved to
        # UiTooltip objects and no window ever read as selected).
        for name in ("Bar.qml", "Main.qml", "DevPulse.qml", "GithubData.qml"):
            self.assertNotIn("id: data", read(name), name)
        for name in ("Bar.qml", "Main.qml", "DevPulse.qml"):
            self.assertNotIn(" data.", read(name), name)
        page = read("DevPulse.qml")
        self.assertIn("pulse.setStatsWindow(modelData)", page)
        self.assertIn('property string statsWindow: "30"', read("GithubData.qml"))

    def test_translations_cover_ui_strings(self):
        es = json.loads((PKG / "translations/es.json").read_text())
        self.assertEqual(MANIFEST["translations"]["locales"], ["es"])
        for needle in ("Dev Pulse", "Refresh", "DEVELOPMENT INBOX"):
            self.assertTrue(any(needle in k or needle in v for k, v in es.items()))


if __name__ == "__main__":
    unittest.main()
