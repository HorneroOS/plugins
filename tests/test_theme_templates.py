import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_validate_plugins import GOOD_QML, make_plugin, vp  # noqa: E402

GOOD_TMPL = '{"id": "{{ id }}", "signal": "{{ signal.hex }}", "ink": "{{ ink.rgba 0.5 }}"}\n{{#dark}}{{ glow.bare }}{{/dark}}\n'


class ThemeTemplatesTest(unittest.TestCase):
    def build(self, templates, text=GOOD_TMPL, files=("palette.json.tmpl",)):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        d = make_plugin(Path(tmp.name), files=["Main.qml", "README.md", "LICENSE", "translations/es.json", *files], theme={"templates": templates})
        for name in files:
            (d / name).write_text(text)
        return d

    def errors(self, d):
        return vp.validate_plugin_dir(d)[0]

    def entry(self, template="palette.json.tmpl", output="palette.json"):
        return {"template": template, "output": output}

    def test_valid_declaration(self):
        self.assertEqual(self.errors(self.build([self.entry()])), [])

    def test_outputs_must_be_plain_file_names(self):
        for output in ("/etc/x", "../x", "sub/x", ".hidden", "a..b", "x y", "", "a" * 65, "~/x"):
            with self.subTest(output=output):
                errs = self.errors(self.build([self.entry(output=output)]))
                self.assertTrue(any("output" in e for e in errs), errs)

    def test_template_path_and_listing(self):
        for template in ("/abs.tmpl", "../up.tmpl", "palette.json"):
            with self.subTest(template=template):
                self.assertTrue(self.errors(self.build([self.entry(template=template)])))
        errs = self.errors(self.build([self.entry(template="missing.tmpl")]))
        self.assertTrue(any("listed in files" in e for e in errs), errs)

    def test_duplicates_and_shape(self):
        errs = self.errors(self.build([self.entry(), self.entry(output="b.json")]))
        self.assertTrue(any("declared twice" in e for e in errs), errs)
        for bad in ([], [{"template": "palette.json.tmpl"}]):
            self.assertTrue(self.errors(self.build(bad)))

    def test_grammar_is_strict_and_names_the_line(self):
        for text, needle in (
            ("{{ nosuchrole }}", "unknown palette role"),
            ("{{ signal.upper }}", "unsupported filter"),
            ("{{ signal.rgba 2 }}", "rgba"),
            ("{{ mode.hex }}", "no filter"),
            ("{{#dark}} open", "never closed"),
            ("{{/light}}", "unbalanced"),
            ("{{ $(rm -rf /) }}", "unsupported template expression"),
            ("}} stray", "stray"),
        ):
            with self.subTest(text=text):
                errs = self.errors(self.build([self.entry()], text="one\n" + text + "\n"))
                self.assertTrue(any(needle in e and "palette.json.tmpl" in e for e in errs), errs)

    def test_oversized_template(self):
        errs = self.errors(self.build([self.entry()], text="x" * (64 * 1024 + 1)))
        self.assertTrue(any("exceeds" in e for e in errs), errs)

if __name__ == "__main__":
    unittest.main()
