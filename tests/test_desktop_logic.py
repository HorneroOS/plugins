"""PluginKit 3 desktop-widget contract for the first-party desktop packages.

hornero-agenda, hornero-calendar and hornero-moon-phase are the first-party
`placement: "desktop"` packages. Under PluginKit 3 (Hornero Signal) the shell
host owns the module frame, position, size, persistence and edit mode; an
extension only lays out its content in the host's content box. These checks
are static: they assert the packages carry geometry hints on the desktop
surface, no longer manage placement themselves (no Desktop.position, size
class or hide/show state) and read the host content box. No live shell
renders these widgets here.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLUGINS = ("hornero-agenda", "hornero-calendar", "hornero-moon-phase")
RETIRED_SETTINGS = ("sizeClass", "showOnDesktop")


def manifest(plugin: str) -> dict:
    return json.loads((ROOT / "plugins" / plugin / "manifest.json").read_text())


def main_qml(plugin: str) -> str:
    return (ROOT / "plugins" / plugin / "Main.qml").read_text()


class DesktopWidgetContract(unittest.TestCase):
    def test_manifests_are_v3_desktop_with_geometry_hints(self):
        for plugin in PLUGINS:
            m = manifest(plugin)
            self.assertEqual(m["schemaVersion"], 3, plugin)
            self.assertEqual(m["placement"], "desktop", plugin)
            surface = m["surfaces"]["desktop"]
            self.assertEqual(surface["entrypoint"], "Main.qml", plugin)
            for key in ("width", "height", "minWidth", "minHeight", "anchor"):
                self.assertIn(key, surface, f"{plugin}: desktop surface needs {key}")
            self.assertLessEqual(surface["minWidth"], surface["width"], plugin)
            self.assertLessEqual(surface["minHeight"], surface["height"], plugin)

    def test_retired_placement_settings_are_gone(self):
        for plugin in PLUGINS:
            settings = manifest(plugin)["capabilities"]["settings"]
            for key in RETIRED_SETTINGS:
                self.assertNotIn(key, settings, f"{plugin} still declares {key}")

    def test_widgets_do_not_manage_placement_themselves(self):
        for plugin in PLUGINS:
            code = main_qml(plugin)
            for forbidden in ("Desktop.position", "sizeClass", "showOnDesktop", "DESKTOP-LOGIC", "desktopPopover"):
                self.assertNotIn(forbidden, code, f"{plugin}: {forbidden}")

    def test_widgets_use_the_host_content_box_and_header_hooks(self):
        for plugin in PLUGINS:
            code = main_qml(plugin)
            self.assertIn("hostAvailableWidth", code, plugin)
            self.assertRegex(code, r"readonly property string widgetTitle", plugin)
            self.assertRegex(code, r"readonly property string widgetContext", plugin)

    def test_no_hand_drawn_card_frames_inside_the_host_module(self):
        for plugin in PLUGINS:
            self.assertNotRegex(main_qml(plugin), re.compile(r"\bUiCard\s*\{"), plugin)


if __name__ == "__main__":
    unittest.main()
