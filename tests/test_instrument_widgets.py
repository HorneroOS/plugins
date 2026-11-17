"""Static contract for the Signal instrument desktop widgets (PluginKit 3).

System Insight, Network Scope and Audio Deck are Rainmeter/Conky-class
desktop widgets over the shared providers. The visual language's real-data
rule is checked statically: they must not own timers, processes, network
access or invented sample data, must declare exactly the provider domains
they read and must render through the kit instruments. No live shell renders
these widgets here.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIDGETS = {
    "hornero-system-insight": {"system"},
    "hornero-network-scope": {"network"},
    "hornero-audio-deck": {"media", "audio", "spectrum"},
}


def load(plugin):
    d = ROOT / "plugins" / plugin
    return json.loads((d / "manifest.json").read_text()), (d / "Main.qml").read_text()


class InstrumentWidgets(unittest.TestCase):
    def test_desktop_v3_with_geometry_hints_and_providers(self):
        for plugin, providers in WIDGETS.items():
            manifest, _ = load(plugin)
            self.assertEqual(manifest["schemaVersion"], 3, plugin)
            self.assertEqual(manifest["placement"], "desktop", plugin)
            surface = manifest["surfaces"]["desktop"]
            for key in ("width", "height", "minWidth", "minHeight", "anchor"):
                self.assertIn(key, surface, f"{plugin}: {key}")
            self.assertEqual(set(manifest["capabilities"]["providers"]), providers, plugin)
            self.assertEqual(manifest["capabilities"]["processCommands"], [], plugin)
            self.assertEqual(manifest["capabilities"]["networkHosts"], [], plugin)

    def test_each_declared_domain_is_leased(self):
        for plugin, providers in WIDGETS.items():
            _, code = load(plugin)
            leased = set(re.findall(r'Subscription \{\s*domain: "([a-z]+)"', code))
            self.assertEqual(leased, providers, plugin)

    def test_no_timers_processes_or_invented_samples(self):
        for plugin in WIDGETS:
            _, code = load(plugin)
            for forbidden in (r"\bTimer\s*\{", r"\bProcess\s*\{", r"XMLHttpRequest", r"Math\.random", r"Quickshell"):
                self.assertIsNone(re.search(forbidden, code), f"{plugin}: {forbidden}")

    def test_instruments_come_from_the_kit(self):
        expected = {
            "hornero-system-insight": ("UiScope", "UiMeterRow", "UiSegmentMeter"),
            "hornero-network-scope": ("UiScope", "UiMeterRow"),
            "hornero-audio-deck": ("UiSegmentMeter", "UiMeterRow"),
        }
        for plugin, components in expected.items():
            _, code = load(plugin)
            for component in components:
                self.assertRegex(code, rf"\b{component}\s*\{{", f"{plugin}: {component}")
            self.assertNotRegex(code, r"\bCanvas\s*\{", plugin)

    def test_unavailable_sources_are_flagged_not_zeroed(self):
        _, insight = load("hornero-system-insight")
        for flag in ("System.gpuAvailable", "System.storageAvailable", "System.cpuTempAvailable", "System.gpuTempAvailable"):
            self.assertIn(flag, insight)
        _, audio = load("hornero-audio-deck")
        self.assertIn("Audio.hasSink", audio)

    def test_audio_spectrum_lease_is_releasable(self):
        manifest, code = load("hornero-audio-deck")
        self.assertIn("showSpectrum", manifest["capabilities"]["settings"])
        self.assertRegex(code, r'domain: "spectrum"\s*\n\s*enabled: root\.showSpectrum')

    def test_wifi_name_is_off_by_default(self):
        manifest, _ = load("hornero-network-scope")
        self.assertIs(manifest["capabilities"]["settings"]["showNetworkName"]["default"], False)


if __name__ == "__main__":
    unittest.main()
