import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "validate_plugins.py"
spec = importlib.util.spec_from_file_location("validate_plugins", SCRIPT)
vp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vp)

V3_QML = """import QtQuick
import Hornero.PluginKit

Item {
    Translations { id: i18n; pluginId: "hornero-example" }
    Subscription { domain: "system" }
    UiText { color: Theme.palette.ink; text: i18n.tr("Load") + " " + System.cpuPerc }
    UiButton { glyph: "player-play"; text: i18n.tr("Go"); tooltipText: i18n.tr("Go"); accessibleName: i18n.tr("Go") }
}
"""


def make_v3(root: Path, qml=V3_QML, providers=("system",), surfaces=None, **overrides) -> Path:
    plugin_dir = root / "plugins" / "hornero-example"
    plugin_dir.mkdir(parents=True)
    caps = {"processCommands": [], "networkHosts": [], "settings": {}}
    if providers is not None:
        caps["providers"] = list(providers)
    manifest = {
        "schemaVersion": 3,
        "id": "hornero-example",
        "name": "Hornero Example",
        "version": "1.0.0",
        "description": "An example plugin used by the PluginKit 3 validator tests.",
        "author": "HorneroOS contributors",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "files": ["Main.qml", "README.md", "LICENSE", "translations/es.json"],
        "translations": {"sourceLocale": "en", "locales": ["es"]},
        "capabilities": caps,
        "placement": "dashboard",
    }
    if surfaces is not None:
        manifest["surfaces"] = surfaces
    manifest.update(overrides)
    (plugin_dir / "manifest.json").write_text(json.dumps(manifest))
    (plugin_dir / "Main.qml").write_text(qml)
    (plugin_dir / "README.md").write_text("# Hornero Example\n")
    (plugin_dir / "LICENSE").write_text("MIT\n")
    (plugin_dir / "translations").mkdir()
    (plugin_dir / "translations" / "es.json").write_text(json.dumps({"Load": "Carga", "Go": "Ir"}))
    return plugin_dir


class PluginKit3ContractTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def errors_for(self, **kwargs):
        errors, _, _ = vp.validate_plugin_dir(make_v3(self.root, **kwargs))
        return errors

    def test_good_v3_plugin_is_clean(self):
        self.assertEqual(self.errors_for(), [])

    def test_material_theme_token_is_rejected_with_replacement(self):
        errors = self.errors_for(qml=V3_QML.replace("Theme.palette.ink", "Theme.onSurface"))
        self.assertTrue(any("Theme.onSurface" in e and "Theme.palette.ink" in e for e in errors))

    def test_flat_group_token_is_rejected(self):
        errors = self.errors_for(qml=V3_QML + "\nItem { width: Theme.spacingSmall; height: Theme.spacing }\n")
        self.assertTrue(any("Theme.spacingSmall" in e for e in errors))
        self.assertTrue(any("tokens are groups" in e for e in errors))

    def test_icon_properties_and_fill_axis_are_rejected(self):
        errors = self.errors_for(qml=V3_QML + '\nUiButton { iconName: "play_arrow"; iconFill: 1 }\n')
        self.assertTrue(any("iconName" in e for e in errors))
        self.assertTrue(any("iconFill" in e for e in errors))

    def test_material_glyph_literal_and_unknown_glyph_are_rejected(self):
        errors = self.errors_for(qml=V3_QML + '\nUiIcon { name: "graphic_eq" }\nUiButton { glyph: "not-a-real-glyph" }\n')
        self.assertTrue(any("graphic_eq" in e and "Material" in e for e in errors))
        self.assertTrue(any("not-a-real-glyph" in e for e in errors))

    def test_undeclared_provider_is_rejected(self):
        errors = self.errors_for(providers=[])
        self.assertTrue(any("subscribes to provider 'system'" in e for e in errors))
        self.assertTrue(any("reads the System facade" in e for e in errors))

    def test_spectrum_needs_its_own_declaration(self):
        errors = self.errors_for(qml=V3_QML + "\nItem { property var s: Audio.spectrum }\n", providers=["system", "audio"])
        self.assertTrue(any('"spectrum"' in e for e in errors))

    def test_providers_require_v3_and_known_domains(self):
        errors = self.errors_for(providers=["system", "bogus"])
        self.assertTrue(any("capabilities.providers must list unique provider domains" in e for e in errors))

    def test_desktop_hints(self):
        good = {"desktop": {"entrypoint": "Main.qml", "width": 320, "height": 200, "minWidth": 240, "anchor": "top-left", "resizable": False}}
        self.assertEqual(self.errors_for(surfaces=good, placement="desktop"), [])

    def test_desktop_hints_are_validated(self):
        bad = {"desktop": {"entrypoint": "Main.qml", "width": 20, "minHeight": 400, "height": 200, "anchor": "nowhere"}}
        errors = self.errors_for(surfaces=bad, placement="desktop")
        self.assertTrue(any("surfaces.desktop.width must be an integer between 80 and 1600" in e for e in errors))
        self.assertTrue(any("minHeight must not exceed" in e for e in errors))
        self.assertTrue(any("anchor must be one of" in e for e in errors))

    def test_desktop_hint_off_desktop_surface(self):
        errors = self.errors_for(surfaces={"bar": {"entrypoint": "Main.qml", "width": 200}})
        self.assertTrue(any("only allowed on the desktop surface" in e for e in errors))

    def test_starter_template_is_valid_v3(self):
        template = Path(__file__).resolve().parent.parent / "templates" / "starter-plugin"
        manifest = json.loads((template / "manifest.json").read_text())
        self.assertEqual(manifest["schemaVersion"], 3)
        self.assertEqual(vp.validate_signal_contract("starter", manifest, template), [])


if __name__ == "__main__":
    unittest.main()
