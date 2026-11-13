import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "validate_plugins.py"
spec = importlib.util.spec_from_file_location("validate_plugins", SCRIPT)
validate_plugins = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validate_plugins)
vp = validate_plugins

GOOD_QML = """import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

Item {
    Translations { id: i18n; pluginId: "hornero-example" }
    Text { color: Theme.onSurface; text: i18n.tr("Example") }
    Button {
        text: i18n.tr("Go")
        Accessible.name: i18n.tr("Go")
        ToolTip.text: i18n.tr("Go")
        ToolTip.visible: hovered
    }
}
"""

GOOD_ES = {"Example": "Ejemplo", "Go": "Ir"}


def make_plugin(root: Path, pid="hornero-example", qml=GOOD_QML, **overrides) -> Path:
    plugin_dir = root / "plugins" / pid
    plugin_dir.mkdir(parents=True)
    manifest = {
        "schemaVersion": 1,
        "id": pid,
        "name": "Hornero Example",
        "version": "1.0.0",
        "description": "An example plugin used by the validator tests.",
        "author": "HorneroOS contributors",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "files": ["Main.qml", "README.md", "LICENSE", "translations/es.json"],
        "translations": {"sourceLocale": "en", "locales": ["es"]},
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        "placement": "dashboard",
    }
    manifest.update(overrides)
    (plugin_dir / "manifest.json").write_text(json.dumps(manifest))
    (plugin_dir / "Main.qml").write_text(qml)
    (plugin_dir / "README.md").write_text("# Hornero Example\n")
    (plugin_dir / "LICENSE").write_text("MIT\n")
    (plugin_dir / "translations").mkdir()
    (plugin_dir / "translations" / "es.json").write_text(json.dumps(GOOD_ES))
    return plugin_dir


def audit_entry(pid, probe, **overrides):
    dims = {d: {"status": probe[d], "note": "probe"} for d in vp.PROBED_DIMENSIONS}
    for dim in ("orientation", "loadingErrorStates", "performance"):
        dims[dim] = {"status": "unverified", "note": "not yet reviewed"}
    entry = {
        "id": pid,
        "classification": "needs-upgrade",
        "valueProposition": "Shows an example value to the user.",
        "nativeOverlap": "No native equivalent identified yet.",
        "dimensions": dims,
        "issue": "HorneroOS/plugins#21",
    }
    entry.update(overrides)
    return entry


def write_audit(root: Path, entries, disclaimer="Static audit; this is not graphical acceptance."):
    (root / vp.AUDIT_FILE).write_text(json.dumps(
        {"schemaVersion": 1, "disclaimer": disclaimer, "entries": entries}))


def inventory_yaml(entries, schema_version=2):
    lines = [f"schemaVersion: {schema_version}", "capabilities:"]
    for entry in entries:
        first = True
        for key, value in entry.items():
            prefix = "  - " if first else "    "
            first = False
            if key == "origin":
                value = "{project: %s, url: \"%s\", license: %s}" % (
                    value["project"], value["url"], value["license"])
            elif isinstance(value, str) and (":" in value or value.startswith("https://")):
                value = json.dumps(value)
            lines.append(f"{prefix}{key}: {value}")
    return "\n".join(lines) + "\n"


def implemented_entry(pid="hornero-example", **overrides):
    entry = {
        "id": pid,
        "name": "Hornero Example",
        "category": "dashboard",
        "origin": {"project": "HorneroOS/plugins", "url": "https://github.com/HorneroOS/plugins", "license": "MIT"},
        "classification": "hornero-original",
        "license_status": "verified",
        "license_evidence": f"plugins/{pid}/LICENSE",
        "inspiration_notes": "First-party HorneroOS plugin; no upstream code is copied.",
        "hornero_equivalent": f"plugins/{pid}",
        "status": "implemented",
    }
    entry.update(overrides)
    return entry


def researched_entry(pid="upstream-widgets", **overrides):
    entry = {
        "id": pid,
        "name": "Upstream widget system",
        "category": "widgets",
        "origin": {"project": "Upstream", "url": "https://example.invalid/upstream", "license": "MIT"},
        "classification": "inspiration",
        "license_status": "verified",
        "license_evidence": "https://example.invalid/upstream/LICENSE",
        "inspiration_notes": "Studied as a capability reference; reimplemented independently, no code copied.",
        "hornero_equivalent": "hornero-example plugin",
        "status": "researched",
    }
    entry.update(overrides)
    return entry


def write_inventory(root: Path, entries, schema_version=2):
    (root / vp.INVENTORY_FILE).write_text(inventory_yaml(entries, schema_version))


class ContractTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def errors_for(self, **kwargs):
        plugin_dir = make_plugin(self.root, **kwargs)
        errors, _, _ = vp.validate_plugin_dir(plugin_dir)
        return errors

    def test_good_plugin_has_no_errors(self):
        self.assertEqual(self.errors_for(), [])

    def test_missing_and_unknown_fields(self):
        plugin_dir = make_plugin(self.root)
        manifest = json.loads((plugin_dir / "manifest.json").read_text())
        del manifest["author"]
        manifest["surprise"] = True
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest))
        errors, _, _ = vp.validate_plugin_dir(plugin_dir)
        self.assertTrue(any("missing required field author" in e for e in errors))
        self.assertTrue(any("unknown top-level field surprise" in e for e in errors))

    def test_settings_default_must_match_type(self):
        errors = self.errors_for(capabilities={
            "processCommands": [], "networkHosts": [],
            "settings": {"count": {"type": "integer", "default": "three"}},
        })
        self.assertTrue(any("does not match declared type" in e for e in errors))

    def test_forbidden_process_command(self):
        errors = self.errors_for(capabilities={
            "processCommands": ["bash"], "networkHosts": [], "settings": {}})
        self.assertTrue(any("forbidden or malformed processCommands" in e for e in errors))

    def test_entrypoint_must_be_listed_in_files(self):
        errors = self.errors_for(files=["README.md", "LICENSE", "Other.qml"])
        self.assertTrue(any("entrypoint must be listed in files" in e for e in errors))

    def test_payload_drift(self):
        plugin_dir = make_plugin(self.root)
        (plugin_dir / "extra.txt").write_text("surprise")
        errors, _, _ = vp.validate_plugin_dir(plugin_dir)
        self.assertTrue(any("payload drift" in e for e in errors))

    def test_disallowed_import_and_undeclared_process(self):
        qml = GOOD_QML.replace("import QtQuick", "import QtQuick\nimport Quickshell.Io\nimport Evil.Module")
        qml += '\nProcess { command: ["curl", "https://example.invalid"] }\n'
        errors = self.errors_for(qml=qml)
        self.assertTrue(any("disallowed QML import: Evil.Module" in e for e in errors))
        self.assertTrue(any("not declared in processCommands: curl" in e for e in errors))
        self.assertTrue(any("URL host not declared" in e for e in errors))

    def test_qstr_is_rejected_as_never_translated(self):
        errors = self.errors_for(qml=GOOD_QML.replace('i18n.tr("Example")', 'qsTr("Example")'))
        self.assertTrue(any("never translated for plugins" in e for e in errors))

    def test_surfaces_require_schema_version_2(self):
        errors = self.errors_for(surfaces={"bar": {"entrypoint": "Main.qml"}})
        self.assertTrue(any("surfaces requires schemaVersion 2" in e for e in errors))

    def test_v2_surface_entrypoint_must_be_listed(self):
        errors = self.errors_for(schemaVersion=2, surfaces={"bar": {"entrypoint": "Bar.qml"}})
        self.assertTrue(any("surfaces.bar.entrypoint must be listed in files" in e for e in errors))

    def test_v2_primary_surface_conflict_is_rejected(self):
        plugin_dir = make_plugin(self.root, schemaVersion=2)
        manifest = json.loads((plugin_dir / "manifest.json").read_text())
        manifest["files"].append("Other.qml")
        manifest["surfaces"] = {"dashboard": {"entrypoint": "Other.qml"}}
        (plugin_dir / "manifest.json").write_text(json.dumps(manifest))
        (plugin_dir / "Other.qml").write_text(GOOD_QML)
        errors, _, _ = vp.validate_plugin_dir(plugin_dir)
        self.assertTrue(any("conflicts with the top-level entrypoint" in e for e in errors))

    def test_dashboard_hints_only_on_dashboard_surface(self):
        errors = self.errors_for(schemaVersion=2, surfaces={"bar": {"entrypoint": "Main.qml", "size": "wide"}})
        self.assertTrue(any("only allowed on the dashboard surface" in e for e in errors))
        errors = self.errors_for(pid="hornero-example2", schemaVersion=2, surfaces={"dashboard": {"entrypoint": "Main.qml", "size": "huge"}})
        self.assertTrue(any("size must be one of" in e for e in errors))
        errors = self.errors_for(pid="hornero-example3", schemaVersion=2, surfaces={"dashboard": {"entrypoint": "Main.qml", "category": "Pinned"}})
        self.assertTrue(any("category must be" in e for e in errors))

    def test_marketplace_rules(self):
        errors = self.errors_for(marketplace={})
        self.assertTrue(any("marketplace must declare at least one" in e for e in errors))
        errors = self.errors_for(pid="hornero-example2", marketplace={"compatibility": {"minShellVersion": "2.0.0", "maxShellVersion": "1.0.0"}})
        self.assertTrue(any("minShellVersion must not exceed" in e for e in errors))
        errors = self.errors_for(pid="hornero-example3", marketplace={"changelog": [{"version": "1.0.0", "notes": "a"}, {"version": "1.0.0", "notes": "b"}]})
        self.assertTrue(any("must not repeat a version" in e for e in errors))
        errors = self.errors_for(pid="hornero-example4", marketplace={"screenshots": [{"path": "previews/x.svg"}]})
        self.assertTrue(any("must be a static image" in e for e in errors))
        errors = self.errors_for(pid="hornero-example5", marketplace={"deprecation": {"replacedBy": "hornero-example5"}})
        self.assertTrue(any("must not name the plugin itself" in e for e in errors))

    def test_capabilities_actions_must_be_snake_case(self):
        errors = self.errors_for(capabilities={
            "processCommands": [], "networkHosts": [], "settings": {}, "actions": ["BadAction"]})
        self.assertTrue(any("capabilities.actions" in e for e in errors))
        errors = self.errors_for(pid="hornero-example2", capabilities={
            "processCommands": [], "networkHosts": [], "settings": {}, "actions": ["system_info"]})
        self.assertFalse(any("capabilities.actions" in e for e in errors))

    def test_incomplete_translation_catalog_is_rejected(self):
        plugin_dir = make_plugin(self.root)
        (plugin_dir / "translations" / "es.json").write_text(json.dumps({"Example": "Ejemplo"}))
        errors, _, _ = vp.validate_plugin_dir(plugin_dir)
        self.assertTrue(any("missing translations for strings passed to Translations.tr()" in e for e in errors))

    def test_typed_setting_constraints(self):
        errors = self.errors_for(capabilities={
            "processCommands": [], "networkHosts": [],
            "settings": {"refresh": {"type": "integer", "default": 5, "minimum": 15, "maximum": 60}},
        })
        self.assertTrue(any("does not match declared type" in e for e in errors))
        errors = self.errors_for(pid="hornero-example2", capabilities={
            "processCommands": [], "networkHosts": [],
            "settings": {"mode": {"type": "enum", "default": "x", "options": ["a", "b"]}},
        })
        self.assertTrue(any("does not match declared type" in e for e in errors))
        errors = self.errors_for(pid="hornero-example3", capabilities={
            "processCommands": [], "networkHosts": [],
            "settings": {"label": {"type": "string", "default": "ok", "minimum": 1}},
        })
        self.assertTrue(any("cannot declare minimum" in e for e in errors))

    def test_undeclared_and_unused_settings_keys(self):
        qml = GOOD_QML + '\nSettings { pluginId: "hornero-example" }\nText { text: String(pluginSettings.value("ghost", 1)) }\n'
        errors = self.errors_for(qml=qml, capabilities={
            "processCommands": [], "networkHosts": [],
            "settings": {"unused": {"type": "string", "default": ""}},
        })
        self.assertTrue(any("used but not declared" in e for e in errors))
        self.assertTrue(any("never used in QML: unused" in e for e in errors))


class QualityProbeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def probe_for(self, qml=GOOD_QML, **overrides):
        plugin_dir = make_plugin(self.root, qml=qml, **overrides)
        _, manifest, code = vp.validate_plugin_dir(plugin_dir)
        return vp.quality_probe(plugin_dir, manifest, code, self.root)

    def test_good_plugin_probes_pass_except_screenshots(self):
        probe = self.probe_for()
        self.assertEqual(probe["tooltips"], "pass")
        self.assertEqual(probe["accessibility"], "pass")
        self.assertEqual(probe["translation"], "pass")
        self.assertEqual(probe["themeTokens"], "pass")
        self.assertEqual(probe["settings"], "na")
        self.assertEqual(probe["screenshots"], "fail")

    def test_screenshot_file_flips_probe(self):
        shots = self.root / "docs" / "screenshots"
        shots.mkdir(parents=True)
        (shots / "hornero-example.png").write_bytes(b"png")
        self.assertEqual(self.probe_for()["screenshots"], "pass")

    def test_interactive_without_tooltip_or_accessible_name_fails(self):
        probe = self.probe_for(qml="import QtQuick\nimport QtQuick.Controls\nItem { Button { text: 'x' } }\n")
        self.assertEqual(probe["tooltips"], "fail")
        self.assertEqual(probe["accessibility"], "fail")

    def test_non_interactive_is_na_and_untranslated_text_fails(self):
        probe = self.probe_for(qml='import QtQuick\nItem { Text { text: "Hello world" } }\n')
        self.assertEqual(probe["tooltips"], "na")
        self.assertEqual(probe["accessibility"], "na")
        self.assertEqual(probe["translation"], "fail")
        self.assertEqual(probe["themeTokens"], "fail")

    def test_format_only_strings_need_no_translation(self):
        qml = 'import QtQuick\nimport Hornero.PluginKit\nItem { Text { color: Theme.onSurface; text: Time.format("HH:mm") } }\n'
        self.assertEqual(self.probe_for(qml=qml)["translation"], "na")

    def test_hard_coded_chrome_colour_fails_theme_tokens(self):
        qml = GOOD_QML.replace('color: Theme.onSurface', 'color: "#112233"')
        self.assertEqual(self.probe_for(qml=qml)["themeTokens"], "fail")

    def test_pluginkit_controls_probe_pass_with_kit_properties(self):
        qml = """import QtQuick
import Hornero.PluginKit

Item {
    Translations { id: i18n; pluginId: "hornero-example" }
    UiButton {
        text: i18n.tr("Go")
        tooltipText: i18n.tr("Go")
        accessibleName: i18n.tr("Go")
    }
    Text { color: Theme.onSurface; text: i18n.tr("Example") }
}
"""
        probe = self.probe_for(qml=qml)
        self.assertEqual(probe["tooltips"], "pass")
        self.assertEqual(probe["accessibility"], "pass")
        self.assertEqual(probe["translation"], "pass")

    def test_declared_and_used_settings_pass(self):
        qml = GOOD_QML + '\nSettings { id: s; pluginId: "hornero-example" }\nText { text: String(s.value("bpm", 96)) }\n'
        probe = self.probe_for(qml=qml, capabilities={
            "processCommands": [], "networkHosts": [],
            "settings": {"bpm": {"type": "integer", "default": 96}},
        })
        self.assertEqual(probe["settings"], "pass")


class QualityAuditTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        plugin_dir = make_plugin(self.root)
        _, manifest, code = vp.validate_plugin_dir(plugin_dir)
        self.probe = vp.quality_probe(plugin_dir, manifest, code, self.root)
        self.official = {"hornero-example": self.probe}

    def tearDown(self):
        self.tmp.cleanup()

    def test_missing_audit_file_is_an_error(self):
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("missing" in e for e in errors))

    def test_honest_needs_upgrade_entry_warns_but_passes(self):
        write_audit(self.root, [audit_entry("hornero-example", self.probe)])
        errors, warnings, _ = vp.validate_audit(self.root, self.official)
        self.assertEqual(errors, [])
        # screenshots=fail plus three unverified dimensions are reported.
        self.assertEqual(len(warnings), 1)
        self.assertIn("screenshots=fail", warnings[0])

    def test_needs_upgrade_requires_linked_issue(self):
        entry = audit_entry("hornero-example", self.probe)
        del entry["issue"]
        write_audit(self.root, [entry])
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("requires a linked issue" in e for e in errors))

    def test_audit_must_not_overclaim_probe(self):
        entry = audit_entry("hornero-example", self.probe)
        entry["dimensions"]["screenshots"] = {"status": "pass", "note": "trust me"}
        write_audit(self.root, [entry])
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("static probe finds fail" in e for e in errors))

    def test_audit_must_not_go_stale(self):
        entry = audit_entry("hornero-example", self.probe)
        entry["dimensions"]["tooltips"] = {"status": "fail", "note": "was missing once"}
        write_audit(self.root, [entry])
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("static probe finds pass" in e for e in errors))

    def test_premium_ready_rejected_without_graphical_review(self):
        entry = audit_entry("hornero-example", self.probe, classification="premium-ready")
        del entry["issue"]
        write_audit(self.root, [entry])
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("premium-ready requires" in e for e in errors))

    def test_premium_ready_accepted_when_everything_passes(self):
        shots = self.root / "docs" / "screenshots"
        shots.mkdir(parents=True)
        (shots / "hornero-example.png").write_bytes(b"png")
        plugin_dir = self.root / "plugins" / "hornero-example"
        _, manifest, code = vp.validate_plugin_dir(plugin_dir)
        probe = vp.quality_probe(plugin_dir, manifest, code, self.root)
        entry = audit_entry("hornero-example", probe, classification="premium-ready",
                            graphicalReview={"reviewer": "Test Reviewer", "date": "2026-11-13"})
        del entry["issue"]
        for dim in ("orientation", "loadingErrorStates", "performance"):
            entry["dimensions"][dim] = {"status": "pass", "note": "reviewed"}
        write_audit(self.root, [entry])
        errors, warnings, _ = vp.validate_audit(self.root, {"hornero-example": probe})
        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])

    def test_deprecated_requires_real_replacement(self):
        entry = audit_entry("hornero-example", self.probe,
                            classification="deprecated-with-replacement", replacement="hornero-example")
        del entry["issue"]
        write_audit(self.root, [entry])
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("requires replacement" in e for e in errors))

    def test_orientation_pass_requires_graphical_review(self):
        entry = audit_entry("hornero-example", self.probe)
        entry["dimensions"]["orientation"] = {"status": "pass", "note": "looks fine"}
        write_audit(self.root, [entry])
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("orientation pass requires" in e for e in errors))

    def test_disclaimer_must_deny_graphical_acceptance(self):
        write_audit(self.root, [audit_entry("hornero-example", self.probe)], disclaimer="All good.")
        errors, _, _ = vp.validate_audit(self.root, self.official)
        self.assertTrue(any("not graphical acceptance" in e for e in errors))

    def test_main_strict_turns_warnings_into_errors(self):
        write_audit(self.root, [audit_entry("hornero-example", self.probe)])
        write_inventory(self.root, [implemented_entry()])
        self.assertEqual(vp.main([], root=self.root), 0)
        self.assertEqual(vp.main(["--strict"], root=self.root), 1)


class InventoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        make_plugin(self.root)
        self.official = {"hornero-example"}
        self.manifests = {"hornero-example": {"license": "MIT"}}

    def tearDown(self):
        self.tmp.cleanup()

    def errors_for(self, entries, schema_version=2):
        write_inventory(self.root, entries, schema_version)
        errors, _ = vp.validate_inventory(self.root, self.official, self.manifests)
        return errors

    def test_missing_inventory_file_is_an_error(self):
        errors, _ = vp.validate_inventory(self.root, self.official, self.manifests)
        self.assertTrue(any("missing" in e for e in errors))

    def test_verified_implemented_and_researched_entries_pass(self):
        self.assertEqual(self.errors_for([implemented_entry(), researched_entry()]), [])

    def test_honest_unverified_entry_passes(self):
        entry = researched_entry(license_status="unverified",
                                 origin={"project": "Upstream", "url": "https://example.invalid/upstream", "license": "UNVERIFIED"})
        del entry["license_evidence"]
        self.assertEqual(self.errors_for([implemented_entry(), entry]), [])

    def test_unverified_license_must_never_be_silently_claimed(self):
        errors = self.errors_for([implemented_entry(), researched_entry(license_status="unverified")])
        self.assertTrue(any("never silently claimed" in e for e in errors))
        self.assertTrue(any("license_evidence is only allowed" in e for e in errors))

    def test_verified_requires_recorded_evidence(self):
        entry = researched_entry()
        del entry["license_evidence"]
        errors = self.errors_for([implemented_entry(), entry])
        self.assertTrue(any("verified requires license_evidence" in e for e in errors))

    def test_schema_1_is_rejected(self):
        errors = self.errors_for([implemented_entry()], schema_version=1)
        self.assertTrue(any("schemaVersion must be 2" in e for e in errors))

    def test_missing_provenance_fields_are_rejected(self):
        entry = researched_entry()
        del entry["inspiration_notes"], entry["license_status"], entry["classification"]
        errors = self.errors_for([implemented_entry(), entry])
        self.assertTrue(any("missing provenance field inspiration_notes" in e for e in errors))
        self.assertTrue(any("missing provenance field license_status" in e for e in errors))
        self.assertTrue(any("missing provenance field classification" in e for e in errors))

    def test_unknown_classification_and_field_are_rejected(self):
        entry = researched_entry(classification="copied", surprise="yes")
        errors = self.errors_for([implemented_entry(), entry])
        self.assertTrue(any("classification must be one of" in e for e in errors))
        self.assertTrue(any("unknown field surprise" in e for e in errors))

    def test_status_must_agree_with_classification(self):
        errors = self.errors_for([implemented_entry(), researched_entry(classification="implemented")])
        self.assertTrue(any("requires status implemented" in e for e in errors))

    def test_every_official_plugin_needs_an_implemented_entry(self):
        errors = self.errors_for([researched_entry()])
        self.assertTrue(any("missing implemented provenance entry for official plugin hornero-example" in e for e in errors))

    def test_implemented_license_must_match_manifest_and_license_file(self):
        entry = implemented_entry(origin={"project": "HorneroOS/plugins", "url": "https://github.com/HorneroOS/plugins", "license": "Apache-2.0"})
        errors = self.errors_for([entry])
        self.assertTrue(any("does not match the plugin manifest license" in e for e in errors))
        entry = implemented_entry(license_evidence="https://example.invalid/LICENSE")
        errors = self.errors_for([entry])
        self.assertTrue(any("must record license_evidence plugins/hornero-example/LICENSE" in e for e in errors))

    def test_upstream_link_must_be_https(self):
        entry = researched_entry(origin={"project": "Upstream", "url": "http://example.invalid/upstream", "license": "MIT"})
        errors = self.errors_for([implemented_entry(), entry])
        self.assertTrue(any("origin.url must be an https URI" in e for e in errors))

    def test_duplicate_ids_are_rejected(self):
        errors = self.errors_for([implemented_entry(), researched_entry(), researched_entry()])
        self.assertTrue(any("duplicate entry for upstream-widgets" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
