"""Pure-JS logic of the dev/gaming extensions added by the catalogue audit.

Git Board, Port Watch, Containers, Device Battery and Pomodoro 4 each carry a
marked LOGIC block in Main.qml. These tests extract the block and run it under
Node (via stdin, no temp files) against hand-written fixtures of the real tool
output formats (`git status --porcelain=v2 --branch`, `ss -H -tulnp`,
`podman ps --format json`, `docker ps --format '{{json .}}'`, `upower -d`).
Structural checks always run; the Node cases are skipped without Node.
"""
import json
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODE = shutil.which("node")


def block(plugin: str, marker: str) -> str:
    text = (ROOT / "plugins" / plugin / "Main.qml").read_text()
    begin = text.index(f"{marker}-BEGIN")
    end = text.index(f"{marker}-END")
    return text[text.index("\n", begin) : end]


def js(plugin: str, marker: str, expr: str):
    src = block(plugin, marker) + f"\nprocess.stdout.write(JSON.stringify({expr}));\n"
    out = subprocess.run([NODE, "-"], input=src, capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


class Structure(unittest.TestCase):
    def test_blocks_present(self):
        for plugin, marker in [
            ("hornero-git-board", "GIT-LOGIC"),
            ("hornero-port-watch", "PORTS-LOGIC"),
            ("hornero-containers", "CONTAINERS-LOGIC"),
            ("hornero-device-battery", "DEVICES-LOGIC"),
            ("hornero-pomodoro", "POMODORO-LOGIC"),
        ]:
            self.assertIn("function", block(plugin, marker), plugin)

    def test_read_only_process_commands(self):
        expected = {
            "hornero-git-board": ["git"],
            "hornero-port-watch": ["ss"],
            "hornero-containers": ["podman", "docker"],
            "hornero-device-battery": ["upower"],
        }
        for plugin, cmds in expected.items():
            m = json.loads((ROOT / "plugins" / plugin / "manifest.json").read_text())
            self.assertEqual(m["capabilities"]["processCommands"], cmds)
            self.assertEqual(m["capabilities"]["networkHosts"], [])
            code = (ROOT / "plugins" / plugin / "Main.qml").read_text()
            for verb in ['"push"', '"pull"', '"fetch"', '"rm"', '"stop"', '"kill"', '"start"', '"commit"']:
                self.assertNotIn(verb, code, f"{plugin} must stay read-only")

    def test_git_never_runs_repo_hooks(self):
        code = (ROOT / "plugins" / "hornero-git-board" / "Main.qml").read_text()
        self.assertEqual(code.count('"git", "-c", "core.fsmonitor=false", "--no-optional-locks"'), 2)


@unittest.skipUnless(NODE, "node not available")
class GitBoard(unittest.TestCase):
    P, M = "hornero-git-board", "GIT-LOGIC"

    def test_status_counts(self):
        text = "\n".join([
            "# branch.oid abc",
            "# branch.head feat/x",
            "# branch.upstream origin/feat/x",
            "# branch.ab +2 -1",
            "1 .M N... 100644 100644 100644 a b src/a.qml",
            "1 M. N... 100644 100644 100644 a b src/b.qml",
            "2 R. N... 100644 100644 100644 a b R100 new\told",
            "u UU N... 1 1 1 1 a b c d f.txt",
            "? notes.txt",
            "? more.txt",
        ])
        r = js(self.P, self.M, f"parseStatus({json.dumps(text)})")
        self.assertEqual((r["branch"], r["upstream"], r["ahead"], r["behind"]), ("feat/x", "origin/x".replace("x", "feat/x"), 2, 1))
        self.assertEqual((r["staged"], r["modified"], r["untracked"], r["conflicted"]), (2, 1, 2, 1))

    def test_no_upstream_and_detached(self):
        r = js(self.P, self.M, 'parseStatus("# branch.head (detached)\\n")')
        self.assertEqual((r["branch"], r["upstream"], r["hasAb"]), ("(detached)", "", False))

    def test_split_repos_rejects_unsafe(self):
        text = "/home/u/a;relative/path;/home/u/../etc;/home/u/a/;/home/u/b\n/home/u/c;;"
        r = js(self.P, self.M, f"splitRepos({json.dumps(text)}, 8)")
        self.assertEqual(r, ["/home/u/a", "/home/u/b", "/home/u/c"])
        self.assertEqual(js(self.P, self.M, f"splitRepos({json.dumps(text)}, 2)"), ["/home/u/a", "/home/u/b"])

    def test_attention_sort(self):
        rows = [
            {"path": "/b", "staged": 0, "modified": 0, "untracked": 0, "conflicted": 0, "ahead": 0, "behind": 0},
            {"path": "/a", "staged": 0, "modified": 1, "untracked": 0, "conflicted": 0, "ahead": 0, "behind": 0},
            {"path": "/c", "error": True},
            {"path": "/d", "staged": 0, "modified": 0, "untracked": 0, "conflicted": 2, "ahead": 0, "behind": 0},
        ]
        r = js(self.P, self.M, f"sortRows({json.dumps(rows)}, 'attention').map(x => x.path)")
        self.assertEqual(r, ["/c", "/d", "/a", "/b"])
        r = js(self.P, self.M, f"sortRows({json.dumps(rows)}, 'path').map(x => x.path)")
        self.assertEqual(r, ["/a", "/b", "/c", "/d"])


@unittest.skipUnless(NODE, "node not available")
class PortWatch(unittest.TestCase):
    P, M = "hornero-port-watch", "PORTS-LOGIC"
    SS = "\n".join([
        "tcp LISTEN 0 4096 127.0.0.1:631 0.0.0.0:*",
        "tcp LISTEN 0 511 *:3000 *:* users:((\"node\",pid=4242,fd=19))",
        "tcp LISTEN 0 511 [::]:3000 [::]:* users:((\"node\",pid=4242,fd=20))",
        "tcp LISTEN 0 4096 [::1]:6379 [::]:* users:((\"redis-server\",pid=1022,fd=6))",
        "udp UNCONN 0 0 127.0.0.53%lo:53 0.0.0.0:*",
        "tcp ESTAB 0 0 10.0.0.2:44444 1.2.3.4:443",
        "tcp LISTEN 0 4096 192.168.1.20:8384 0.0.0.0:*",
        "garbage",
    ])

    def sockets(self):
        return js(self.P, self.M, f"parseSockets({json.dumps(self.SS)})")

    def test_merge_and_reach(self):
        by = {(s["proto"], s["port"]): s for s in self.sockets()}
        self.assertEqual(len(by), 5)
        self.assertEqual(by[("tcp", 3000)]["reach"], 2)
        self.assertEqual(by[("tcp", 3000)]["process"], "node")
        self.assertEqual(by[("tcp", 631)]["reach"], 0)
        self.assertEqual(by[("tcp", 6379)]["reach"], 0)
        self.assertEqual(by[("udp", 53)]["reach"], 0)
        self.assertEqual(by[("tcp", 8384)]["reach"], 1)
        self.assertEqual(by[("tcp", 631)]["process"], "")

    def test_watch_and_filters(self):
        socks = json.dumps(self.sockets())
        r = js(self.P, self.M, f"compose({socks}, parseWatch('5173, 3000 99999 abc 5173'), 'tcp', 'all', 20).map(x => [x.port, x.listening])")
        self.assertEqual(r[:2], [[3000, True], [5173, False]])
        r = js(self.P, self.M, f"compose({socks}, [], 'tcp', 'exposed', 20).map(x => x.port)")
        self.assertEqual(r, [3000])
        r = js(self.P, self.M, f"compose({socks}, [], 'both', 'local', 20).map(x => x.port)")
        self.assertEqual(r, [53, 631, 6379])
        r = js(self.P, self.M, f"compose({socks}, [], 'both', 'all', 2).length")
        self.assertEqual(r, 2)


@unittest.skipUnless(NODE, "node not available")
class Containers(unittest.TestCase):
    P, M = "hornero-containers", "CONTAINERS-LOGIC"

    def test_podman_array_and_docker_lines(self):
        podman = json.dumps([
            {"Names": ["tea-db"], "Image": "postgres:16", "State": "running", "Status": "Up 3 hours",
             "Ports": [{"host_port": 5432, "container_port": 5432, "protocol": "tcp"}]},
            {"Names": ["old"], "Image": "redis", "State": "exited", "Status": "Exited (0)", "Ports": None},
        ])
        r = js(self.P, self.M, f"parseList({json.dumps(podman)}, 'podman')")
        self.assertEqual(r[0]["ports"], "5432→5432")
        self.assertEqual(r[1]["ports"], "")
        docker = "\n".join(json.dumps(o) for o in [
            {"Names": "web", "Image": "nginx", "State": "running", "Status": "Up 1 minute", "Ports": "0.0.0.0:8080->80/tcp"},
            {"Names": "/db", "Image": "pg", "State": "Paused", "Status": "Up (Paused)", "Ports": ""},
        ])
        r = js(self.P, self.M, f"parseList({json.dumps(docker)}, 'docker')")
        self.assertEqual([c["name"] for c in r], ["web", "db"])
        self.assertEqual(r[1]["state"], "paused")
        self.assertEqual(js(self.P, self.M, "parseList('', 'docker')"), [])

    def test_arrange_orders_running_first_and_hides_stopped(self):
        rows = [{"name": "b", "state": "exited"}, {"name": "z", "state": "running"}, {"name": "a", "state": "running"}, {"name": "p", "state": "paused"}]
        r = js(self.P, self.M, f"arrange({json.dumps(rows)}, true, 10).map(x => x.name)")
        self.assertEqual(r, ["a", "z", "p", "b"])
        r = js(self.P, self.M, f"arrange({json.dumps(rows)}, false, 10).map(x => x.name)")
        self.assertEqual(r, ["a", "z", "p"])


@unittest.skipUnless(NODE, "node not available")
class DeviceBattery(unittest.TestCase):
    P, M = "hornero-device-battery", "DEVICES-LOGIC"
    UPOWER = """Device: /org/freedesktop/UPower/devices/line_power_AC
  power supply:         yes
  line-power
    online:               yes

Device: /org/freedesktop/UPower/devices/gaming_input_pad
  model:                DualSense
  power supply:         no
  gaming-input
    present:             yes
    state:               discharging
    percentage:          18%

Device: /org/freedesktop/UPower/devices/headset_x
  model:                Arctis
  power supply:         no
  headset
    present:             yes
    state:               unknown

Device: /org/freedesktop/UPower/devices/battery_BAT0
  power supply:         yes
  battery
    present:             yes
    state:               discharging
    percentage:          78%

Daemon:
  daemon-version:  1.90
  on-battery: yes
"""

    def test_parse_pick_arrange(self):
        up = json.dumps(self.UPOWER)
        parsed = js(self.P, self.M, f"parseDevices({up})")
        self.assertEqual(len(parsed), 4)
        pad = [d for d in parsed if d["type"] == "gaming-input"][0]
        self.assertEqual((pad["percent"], pad["state"], pad["model"]), (18, "discharging", "DualSense"))
        headset = [d for d in parsed if d["type"] == "headset"][0]
        self.assertEqual(headset["percent"], -1)
        picked = js(self.P, self.M, f"pick(parseDevices({up}), false).map(d => d.type)")
        self.assertEqual(picked, ["gaming-input", "headset"])
        picked = js(self.P, self.M, f"pick(parseDevices({up}), true).map(d => d.type)")
        self.assertEqual(picked, ["gaming-input", "headset", "battery"])
        order = js(self.P, self.M, f"arrange(pick(parseDevices({up}), true), 'lowest').map(d => d.type)")
        self.assertEqual(order, ["gaming-input", "battery", "headset"])


@unittest.skipUnless(NODE, "node not available")
class Pomodoro(unittest.TestCase):
    P, M = "hornero-pomodoro", "POMODORO-LOGIC"

    def test_cycle(self):
        seq = []
        phase, count = "focus", 0
        for _ in range(8):
            n = js(self.P, self.M, f"nextPhase({json.dumps(phase)}, {count}, 4)")
            seq.append(n["phase"])
            phase, count = n["phase"], n["setCount"]
        self.assertEqual(seq, ["short", "focus", "short", "focus", "short", "focus", "long", "focus"])

    def test_clamp_and_modes(self):
        self.assertEqual(js(self.P, self.M, "clampInt('abc', 1, 9, 5)"), 5)
        self.assertEqual(js(self.P, self.M, "clampInt(99, 1, 9, 5)"), 9)
        self.assertEqual(js(self.P, self.M, "fmt(65)"), "01:05")
        self.assertEqual(js(self.P, self.M, "[validMode('focus'), validMode('rm -rf')]"), [True, False])


if __name__ == "__main__":
    unittest.main()
