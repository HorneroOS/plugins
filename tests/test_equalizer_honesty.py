"""hornero-equalizer draws only real PipeWire spectrum data.

The extension is an analyser over `Audio.spectrum`; these structural tests
pin the honesty contract (no simulated levels, no idle animation, the
analyser lease only while there is something to analyse) and that every
setting the manifest declares is read with the declared bounds. The QML is
not executed here; graphical and CPU evidence is recorded in the PR.
"""
import json
import re
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent / "plugins" / "hornero-equalizer"
QML = (PLUGIN / "Main.qml").read_text(encoding="utf-8")
MANIFEST = json.loads((PLUGIN / "manifest.json").read_text())


class HonestyTests(unittest.TestCase):
    def test_levels_come_only_from_the_audio_spectrum(self):
        self.assertIn("Audio.spectrum", QML)
        for needle in ("Math.random", "SequentialAnimation", "NumberAnimation", "Behavior on", "interval:", "Timer"):
            self.assertNotIn(needle, QML, f"{needle} would draw a level that is not a real sample")

    def test_spectrum_lease_is_gated_on_sound_being_possible(self):
        self.assertRegex(QML, r'domain: "spectrum"\s+enabled: root\.analysing')
        self.assertIn('(Media.hasPlayer && Media.isPlaying)', QML)
        self.assertEqual(MANIFEST["capabilities"]["providers"], ["audio", "media", "spectrum"])
        self.assertEqual(MANIFEST["capabilities"]["processCommands"], [])
        self.assertEqual(MANIFEST["capabilities"]["networkHosts"], [])

    def test_it_never_claims_to_change_sound(self):
        self.assertNotIn("setVolume", QML)
        self.assertNotIn("UiSlider", QML)
        self.assertIn("analyser", QML)
        self.assertIn("no equalizer sliders", QML)

    def test_declared_settings_are_read_with_their_bounds(self):
        settings = MANIFEST["capabilities"]["settings"]
        for key in settings:
            self.assertIn(f'"{key}"', QML)
        for key in ("barBands", "popoverBands"):
            spec = settings[key]
            self.assertRegex(QML, rf"Math\.max\({spec['minimum']}, Math\.min\({spec['maximum']},")
            self.assertGreaterEqual(spec["default"], spec["minimum"])
            self.assertLessEqual(spec["default"], spec["maximum"])
        self.assertEqual(settings["analyseWhen"]["default"], "playing")

    def test_unavailable_states_are_rendered_not_hidden(self):
        self.assertIn('kind: "empty"', QML)
        self.assertIn("No output device", QML)

    def test_peak_ticks_are_derived_with_a_fixed_decay(self):
        match = re.search(r"readonly property real peakDecay: ([0-9.]+)", QML)
        self.assertIsNotNone(match)
        self.assertIn("Ticks are the peak of recent samples", QML)


if __name__ == "__main__":
    unittest.main()
