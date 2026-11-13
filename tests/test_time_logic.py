"""Pure-JS time logic shipped in the Time & Agenda 2.0 plugins (#28).

PluginKit Time exposes only the local system clock, so world-clock
and dual-clock compute other zones from UTC with a rule table (the
TZ-LOGIC block, verbatim in both packages because plugins cannot
share code) and calendar/agenda compute date facts with UTC day
math (DATE-LOGIC blocks). These tests extract the shipped blocks
and run them under Node against independent oracles: Python
zoneinfo (the system IANA database) for offsets around every DST
transition, and Python calendar/datetime for the date math. When
Node is unavailable the oracle comparisons are skipped with a
reason; the structural checks (blocks present, copies identical)
always run. Node is present on GitHub's ubuntu runners.
"""
import calendar as calendar_module
import json
import shutil
import subprocess
import tempfile
import unittest
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")

ZONES = {
    "utc": "UTC",
    "buenos-aires": "America/Argentina/Buenos_Aires",
    "new-york": "America/New_York",
    "chicago": "America/Chicago",
    "los-angeles": "America/Los_Angeles",
    "london": "Europe/London",
    "madrid": "Europe/Madrid",
    "berlin": "Europe/Berlin",
    "new-delhi": "Asia/Kolkata",
    "tokyo": "Asia/Tokyo",
    "sydney": "Australia/Sydney",
    "auckland": "Pacific/Auckland",
}


def extract_block(plugin: str, marker: str) -> str:
    text = (ROOT / "plugins" / plugin / "Main.qml").read_text()
    begin = text.index(f"{marker}-BEGIN")
    end = text.index(f"{marker}-END")
    return text[text.index("\n", begin) : end]


def run_node(block: str, driver: str, cases) -> list:
    with tempfile.TemporaryDirectory() as tmp:
        script = Path(tmp) / "harness.js"
        cases_file = Path(tmp) / "cases.json"
        script.write_text(block + "\n" + driver)
        cases_file.write_text(json.dumps(cases))
        out = subprocess.run(
            [NODE, str(script), str(cases_file)],
            capture_output=True, text=True, check=True,
        )
    return json.loads(out.stdout)


class TzBlockStructure(unittest.TestCase):
    def test_tz_blocks_present_and_identical(self):
        world = extract_block("hornero-world-clock", "TZ-LOGIC")
        dual = extract_block("hornero-dual-clock", "TZ-LOGIC")
        self.assertIn("function effectiveOffsetMin", world)
        self.assertEqual(world, dual, "TZ-LOGIC copies must stay verbatim")

    def test_zone_options_match_table_and_oracle(self):
        # Every enum option offered in a manifest must be a zone the
        # rule table (and hence this oracle map) actually knows.
        block = extract_block("hornero-world-clock", "TZ-LOGIC")
        for plugin, keys in (
            ("hornero-world-clock", ("city1", "city2", "city3")),
            ("hornero-dual-clock", ("secondZone",)),
        ):
            manifest = json.loads((ROOT / "plugins" / plugin / "manifest.json").read_text())
            settings = manifest["capabilities"]["settings"]
            for key in keys:
                for option in settings[key]["options"]:
                    self.assertIn(option, ZONES, f"{plugin}:{key} offers unknown zone {option}")
                    self.assertIn(f'"{option}"', block)


def transitions(zi: ZoneInfo, year: int):
    found = []
    t = datetime(year, 1, 1, tzinfo=timezone.utc)
    prev = t.astimezone(zi).utcoffset()
    while t.year == year:
        t += timedelta(hours=1)
        cur = t.astimezone(zi).utcoffset()
        if cur != prev:
            lo = t - timedelta(hours=1)
            for m in range(1, 61):
                cand = lo + timedelta(minutes=m)
                if cand.astimezone(zi).utcoffset() == cur:
                    found.append(cand)
                    break
            prev = cur
    return found


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class TzOracle(unittest.TestCase):
    DRIVER = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const zones = zoneTable();
process.stdout.write(JSON.stringify(cases.map(c => {
    const p = zonedParts(new Date(c[0]), zones[c[1]]);
    return [p.offsetMin, p.dst ? 1 : 0, p.year, p.month + 1, p.day, p.hours, p.minutes, p.seconds];
})));
"""

    def test_offsets_match_zoneinfo_around_transitions(self):
        cases, expected = [], []
        for key, iana in ZONES.items():
            zi = ZoneInfo(iana)
            instants = []
            for year in (2024, 2025, 2026, 2027):
                instants += [
                    datetime(year, 1, 15, 12, tzinfo=timezone.utc),
                    datetime(year, 7, 15, 12, tzinfo=timezone.utc),
                    datetime(year, 12, 31, 23, 59, 59, tzinfo=timezone.utc),
                ]
            for year in (2025, 2026):
                for tr in transitions(zi, year):
                    instants += [
                        tr - timedelta(seconds=1), tr, tr + timedelta(seconds=1),
                        tr - timedelta(hours=2), tr + timedelta(hours=2),
                    ]
            for t in instants:
                local = t.astimezone(zi)
                dst = local.dst()
                cases.append([int(t.timestamp() * 1000), key])
                expected.append([
                    int(local.utcoffset().total_seconds() // 60),
                    1 if dst and dst.total_seconds() else 0,
                    local.year, local.month, local.day,
                    local.hour, local.minute, local.second,
                ])
        got = run_node(extract_block("hornero-world-clock", "TZ-LOGIC"), self.DRIVER, cases)
        for (ms, key), exp, act in zip(cases, expected, got):
            self.assertEqual(
                exp, act,
                f"{key} at {datetime.fromtimestamp(ms / 1000, timezone.utc)}",
            )


@unittest.skipUnless(NODE, "node not available; JS oracle comparison skipped")
class DateLogicOracle(unittest.TestCase):
    def test_calendar_month_cells(self):
        driver = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(JSON.stringify(cases.map(c => monthCells(c[0], c[1], c[2]))));
"""
        cases, expected = [], []
        for year in (2023, 2024, 2025, 2026):
            for month in range(12):
                for start in (0, 1):
                    cases.append([year, month, start])
                    first_weekday, ndays = calendar_module.monthrange(year, month + 1)
                    # Python: Monday=0..Sunday=6; JS: Sunday=0..Saturday=6.
                    js_first = (first_weekday + 1) % 7
                    blanks = (js_first - start + 7) % 7
                    cells = [0] * blanks + list(range(1, ndays + 1))
                    while len(cells) % 7:
                        cells.append(0)
                    expected.append(cells)
        got = run_node(extract_block("hornero-calendar", "DATE-LOGIC"), driver, cases)
        self.assertEqual(expected, got)

    def test_agenda_date_facts(self):
        driver = """
const fs = require("fs");
const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
process.stdout.write(JSON.stringify(cases.map(c => {
    const iso = isoWeekFields(c[0], c[1], c[2]);
    return [dayOfYearFields(c[0], c[1], c[2]), daysInYearFields(c[0]),
            iso.week, iso.weekYear, daysInMonth(c[0], c[1]), quarterOf(c[1])];
})));
"""
        days = []
        for year in (2023, 2024, 2025, 2026):
            days += [date(year, 1, 1), date(year, 1, 4), date(year, 2, 28),
                     date(year, 3, 1), date(year, 6, 15), date(year, 12, 28),
                     date(year, 12, 31)]
        days += [date(2020, 12, 31), date(2021, 1, 1), date(2024, 2, 29)]
        cases = [[d.year, d.month - 1, d.day] for d in days]
        expected = []
        for d in days:
            iso = d.isocalendar()
            expected.append([
                d.timetuple().tm_yday,
                366 if calendar_module.isleap(d.year) else 365,
                iso.week, iso.year,
                calendar_module.monthrange(d.year, d.month)[1],
                (d.month - 1) // 3 + 1,
            ])
        got = run_node(extract_block("hornero-agenda", "DATE-LOGIC"), driver, cases)
        self.assertEqual(expected, got)


if __name__ == "__main__":
    unittest.main()
