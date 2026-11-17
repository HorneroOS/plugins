# Official extension catalogue audit (2026-11-17)

Scope: the 36 official extensions in HorneroOS/plugins at `4a45df4` plus the five added here. Evidence: offscreen fixture renders of every surface (`evidence/plugins-r3/all`, night and day), `quality-audit.json`, manifests, source, and QA VM captures for the new work (`docs/evidence/catalog-audit/`).

## Method and honesty notes

Scores are 1 to 5, maintainer judgment from static metadata (settings, permissions, source size) and the captures. Use = everyday value the extension delivers today. Polish = how it reads next to the Signal Bezel in the captures. Settings = typed schema richness and sensible ranges. Perms = minimality of declared capabilities (5 = none or one read-only tool). Upkeep = low maintenance cost (5 = cheap). Unique = absence of duplication with core or with other extensions. The old captures are fixture data over stub services, not real-shell captures; the new extensions were also captured in the QA VM.

## Findings

1. **Duplication.** Six extensions repeat each other or the shell: System Monitor, System Health and System Insight; Network Monitor and Network Scope; Quick Notes and Quiet Notes; Volume and Microphone against native audio state; Sun Card against Weather; Dual Clock against World Clock.
2. **Bare utility forms.** Base, Date, Text, JSON, Unit and Colour converters and the Calculator are unstyled forms on dashboard cards with empty space under them (see `docs/evidence/catalog-audit/legacy-dashboard-sheet.png`). Their `launcher` surfaces, where they would shine, have no host yet (shell#250).
3. **Instruments are the strength.** System Insight, Network Scope, Audio Deck, Calendar and Moon Phase read as part of the Signal desktop (frame, eyebrow, scopes, segment meters).
4. **Settings.** Almost every extension has typed settings, but many only two toggles. Studio Jobs has none.
5. **Permissions are already small**: `horneroctl` (3), `cat` (1), no network hosts anywhere.
6. **Aesthetic.** Signal is sober and precise; the cozy / kawaii warmth lives in the shell (mascot, amber accent) rather than in the extensions. This pass adds charm only where honest: warm state copy ("Cosy."), amber rails, and nothing that fakes data. A shared glyph/mascot affordance in PluginKit would let extensions carry more of it (see API wishes).
7. **Capture gaps.** `loadingErrorStates` and `performance` remain `unverified` for most legacy entries.

## Scores and decisions

| Extension | Use | Polish | Settings | Perms | Upkeep | Unique | Total/30 | Decision | Why |
|---|--:|--:|--:|--:|--:|--:|--:|---|---|
| hornero-agenda | 2 | 4 | 3 | 5 | 5 | 3 | 22 | KEEP (improve) | Date facts only, no events; in the Signal deck so it cannot be retired. Fold into Calendar when a calendar provider exists. |
| hornero-ai-usage | 3 | 3 | 2 | 4 | 2 | 4 | 18 | IMPROVE | 585 lines for one Process; bar text `AI 168,000` is cryptic; quota honesty is good. One setting only. |
| hornero-audio-deck | 4 | 4 | 3 | 5 | 5 | 4 | 25 | KEEP | Real PipeWire spectrum, deck member. |
| hornero-base-converter | 1 | 2 | 2 | 5 | 5 | 2 | 17 | RETIRED (deprecated) | Bare form; fold into Calculator as a programmer mode, then deprecate. |
| hornero-battery | 3 | 3 | 3 | 5 | 3 | 2 | 19 | IMPROVE | Laptop level duplicates native; unique value is health, rate, profile. Re-scope to those. |
| hornero-calculator | 3 | 3 | 2 | 5 | 3 | 3 | 19 | RETIRED (deprecated) | Launcher surface has no host yet (shell#250); dashboard keypad is the only live surface. |
| hornero-calendar | 4 | 4 | 4 | 5 | 5 | 3 | 25 | KEEP | Deck member; add events when a provider exists. |
| hornero-color-converter | 3 | 3 | 2 | 5 | 4 | 3 | 20 | RETIRED (deprecated) | Creative candidate: palette and screen pick (needs a picker API). |
| hornero-countdown | 3 | 2 | 4 | 5 | 5 | 4 | 23 | IMPROVE | Merge target for Stopwatch (one Timers extension). |
| hornero-date-calculator | 2 | 2 | 2 | 5 | 5 | 3 | 19 | RETIRED (deprecated) | Bare form; fold into Calendar. |
| hornero-disk-usage | 3 | 3 | 3 | 5 | 4 | 3 | 21 | IMPROVE | Per-mount list is unique; polish card. |
| hornero-dual-clock | 3 | 3 | 3 | 5 | 5 | 2 | 21 | MERGE (planned) | Same job as World Clock; fold in as a bar surface. |
| hornero-focus-card | 1 | 2 | 3 | 5 | 5 | 2 | 18 | RETIRED (deprecated) | Rotating phrase card; replaced by Pomodoro. |
| hornero-json-tools | 3 | 2 | 3 | 5 | 5 | 4 | 22 | RETIRED (deprecated) | Dev utility worth keeping; the card needs real styling and validation errors. |
| hornero-metronome | 3 | 2 | 4 | 5 | 5 | 5 | 24 | KEEP | Creative, unique; polish. |
| hornero-microphone | 2 | 3 | 2 | 5 | 5 | 1 | 18 | MERGE (planned) | Duplicates native mic state; fold into Audio Deck bar surface. |
| hornero-moon-phase | 3 | 4 | 5 | 5 | 5 | 5 | 27 | KEEP | Charming, approximate and labelled so. |
| hornero-network-monitor | 2 | 3 | 2 | 5 | 5 | 1 | 18 | RETIRED (deprecated) | Replaced by Network Scope. |
| hornero-network-scope | 4 | 4 | 3 | 5 | 5 | 4 | 25 | KEEP | Deck member, scales stated. |
| hornero-now-playing | 4 | 3 | 3 | 5 | 4 | 3 | 22 | IMPROVE | Media deck: artwork and position are in the facade but unused. |
| hornero-pomodoro | 3 | 3 | 3 | 5 | 5 | 4 | 23 | IMPROVED (4.0.0) | Breaks, set meter, Skip, optional Experience hook. |
| hornero-quick-notes | 3 | 3 | 3 | 5 | 5 | 3 | 22 | IMPROVE | Persistent note; absorbs Quiet Notes. |
| hornero-quiet-notes | 1 | 2 | 2 | 5 | 5 | 1 | 16 | RETIRED (deprecated) | Session-only intention line; replaced by Quick Notes. |
| hornero-stopwatch | 2 | 2 | 3 | 5 | 5 | 4 | 21 | MERGE (planned) | Fold into Countdown as Timers. |
| hornero-studio-audio | 3 | 3 | 2 | 4 | 4 | 4 | 20 | KEEP (improve) | Honest read-only Studio mode state. |
| hornero-studio-jobs | 3 | 3 | 1 | 4 | 5 | 5 | 21 | IMPROVE | Declares no settings at all; add refresh and row-count settings. |
| hornero-sun-card | 2 | 3 | 4 | 5 | 4 | 2 | 20 | MERGE (planned) | Derived values duplicate Weather; fold into Weather. |
| hornero-system-health | 2 | 3 | 3 | 5 | 3 | 1 | 17 | RETIRED (deprecated) | Replaced by System Insight (meters with a warning threshold). |
| hornero-system-insight | 5 | 4 | 5 | 5 | 5 | 5 | 29 | KEEP | Flagship instrument; six typed settings. |
| hornero-system-monitor | 2 | 3 | 2 | 5 | 5 | 1 | 18 | RETIRED (deprecated) | Replaced by System Insight. |
| hornero-text-tools | 2 | 2 | 2 | 5 | 5 | 3 | 19 | RETIRED (deprecated) | Bare form; fold into JSON Tools as a text/dev tools card. |
| hornero-unit-converter | 3 | 3 | 2 | 5 | 3 | 3 | 19 | RETIRED (deprecated) | Everyday utility; launcher-native later. |
| hornero-uptime | 2 | 3 | 3 | 4 | 3 | 3 | 18 | IMPROVE | Spawns `cat`; no facade exists, so uptime is derived. Move to a provider. |
| hornero-volume | 2 | 3 | 3 | 5 | 4 | 1 | 18 | MERGE (planned) | Duplicates native volume OSD and quick settings; fold into Audio Deck bar surface. |
| hornero-weather | 4 | 3 | 5 | 5 | 4 | 2 | 23 | KEEP (improve) | Six settings; absorbs Sun Card. |
| hornero-world-clock | 3 | 3 | 5 | 5 | 4 | 3 | 23 | KEEP | Seven settings; absorbs Dual Clock. |
| hornero-git-board | 4 | 4 | 5 | 5 | 4 | 5 | 27 | NEW | Dev: local repository board. |
| hornero-port-watch | 4 | 4 | 5 | 5 | 4 | 5 | 27 | NEW | Dev: listening ports and watched ports. |
| hornero-containers | 3 | 4 | 5 | 5 | 4 | 5 | 26 | NEW | Dev: read-only Podman/Docker roster. |
| hornero-device-battery | 4 | 4 | 4 | 5 | 4 | 5 | 26 | NEW | Gaming/everyday: controller, mouse, keyboard, headset charge. |

Decision key: KEEP, IMPROVE (keep, planned work), MERGE (planned: the replacement does not yet cover the function, so no deprecation is published until it does), RETIRED (deprecated now with a replacement that does cover it), NEW, IMPROVED (done in this change).

## Deprecation path (nothing breaks)

The five retired extensions keep working for everyone who has them installed. Each gets a patch version bump, a changelog line, and `marketplace.deprecation {message, replacedBy}`. Per the shell contract (docs/PLUGINS.md, "Marketplace metadata"), Control Center warns on installed and catalogue rows, stops offering new installs, shows "View replacement", and never disables or removes an installed copy. `quality-audit.json` classifies them `deprecated-with-replacement`. None is in the Signal deck or a shipped default. Removal from `plugins/` is a later, separate decision after a release or two.

## Shortlist and what shipped

| Idea | Status |
|---|---|
| Git status board | **Shipped** (hornero-git-board) |
| Port / process monitor | **Shipped** as ports (hornero-port-watch); per-process CPU is not honestly available to extensions |
| Container status | **Shipped** (hornero-containers, Podman and Docker, read-only) |
| Controller / peripheral battery | **Shipped** (hornero-device-battery) |
| Pomodoro / focus timer with Experience hook | **Shipped** (hornero-pomodoro 4.0.0) |
| Unified utilities | **Shipped** (hornero-toolbox 1.0.0) replacing seven extensions, now deprecated |
| PR / CI board | **Shipped** (hornero-forge-board 1.0.0): uses the user's own `gh auth` session, no token field, no token storage, repo names validated, read-only |
| Agenda with events | Blocked: no calendar provider (API wish) |
| Clipboard history | Blocked: privacy; needs a consent-gated clipboard provider |
| Scratchpad / snippets | Quick Notes covers scratch; snippets need an action surface |
| GPU / FPS / MangoHud controls | Blocked: no frame-time provider; MangoHud config needs file writes |
| Game library launcher | Blocked: needs the launcher host (shell#250) and a library provider |
| Colour picker from screen | Needs a picker (`hyprpicker`) and interactive host validation |
| Audio routing / OBS / REAPER status | Needs a declared local network host (OBS WebSocket) and a design for secrets |
| Reference board | Needs a file-pick API |
| Weather + sky, media deck, system monitors | Exist; media deck is an IMPROVE item |

## Shipped in this change

- **hornero-git-board 1.0.0** (`git`): branch, upstream drift, staged/changed/untracked/conflicted, last commit; dashboard and desktop; sorted by attention; unreadable paths are explicit error rows. Runs with `--no-optional-locks` and `core.fsmonitor=false`; never fetches or writes.
- **hornero-port-watch 1.0.0** (`ss`): ports, bind reach (local, LAN, exposed), owner when visible, watched ports shown as free.
- **hornero-containers 1.0.0** (`podman`, `docker`): state, image, status, ports; error state when no runtime answers.
- **hornero-device-battery 1.0.0** (`upower`): controllers, mice, keyboards, headsets; devices without a percentage show state only.
- **hornero-pomodoro 4.0.0** (`horneroctl`): short and long breaks, set meter, Skip, optional Experience hook that restores the previous mode only if still Focus. State keys stay compatible with 3.x.

All five declare typed settings (enums, ranges, string length, booleans) with defaults, are themed only with Signal tokens, have Argentine Spanish catalogues, and are tested (`tests/test_catalog_logic.py`, 14 cases over real tool output formats). A bug found in the QA VM and fixed: a missing executable never reports an exit, so cards sat on "loading"; each now has a watchdog and shows its error state.

## What did not get done

Improving the keepers visually and functionally beyond Pomodoro; the planned merges; per-instance configuration (not supported by the manifest); Control Center settings-page capture of the new extensions (pointer clicks did not reach the Settings link in the VM); end-to-end proof of the Experience hook (the VM image's horneroctl predates `experience set`); performance measurements; success-state captures of Containers and Device Battery in the VM (no Podman/UPower in the image).

## API wishes (PluginKit)

1. **Per-instance configuration**: several instances of one extension (one Git Board per project, one world clock per place) with their own settings and screen.
2. **Hidden state storage**: timers persist `deadlineEpochMs`, `phase` and similar as ordinary settings, which show in the generated settings UI. An `internal: true` flag or a `Storage` type is needed.
3. **Experience control**: a declared `experience` capability and `Experience.set(mode)` instead of spawning `horneroctl`.
4. **Peripheral power**: `Power.devices` (kind, model, percent, state) so Device Battery needs no process.
5. **Calendar events provider**, **clipboard provider with consent**, **game library and frame-time providers**.
6. **Settings types**: `string-list` and `path` for repository and port lists (today semicolon-separated strings).
7. **Process failure signal**: a `failed` signal for a missing executable (today no exit is reported), and `StdioCollector` in the import allowlist.
8. **Desktop widget content contract**: minimum content height and scrolling so lists do not clip.
9. **Real-shell screenshots in `marketplace.screenshots`** produced by the QA tooling instead of fixtures.
10. **Cosy affordances**: a shared mascot/empty-state illustration primitive so extensions can carry the warm tone without bespoke art.

## Follow-up pass (2026-11-17, PR "catalog merges")

- **hornero-toolbox 1.0.0**: Calculator, Units (adds imperial lengths, grams/ounces, data sizes), Base, Colour (adds WCAG contrast), Dates, JSON and Text in one tabbed Signal card. Replaces calculator, unit-converter, base-converter, color-converter, date-calculator, json-tools and text-tools, which are now deprecated with `replacedBy: hornero-toolbox` (they keep working where installed; their stored settings do not carry over because the id is new). Logic is unit-tested against Python oracles (WCAG reference, colorsys, datetime, JSON round trips).
- **hornero-forge-board 1.0.0**: token handling decision: no token field, no storage; it runs `gh run list` and `gh pr list --author @me` through the CLI session the user created with `gh auth login`. Declared `processCommands: ["gh"]`, `networkHosts: ["api.github.com"]`. Repository names must match `owner/name` before reaching argv. Missing or signed-out gh shows an explicit state. A QA VM capture caught the header claiming CI GREEN with gh missing; fixed in 1.0.1.
- **Still planned, not done**: Dual Clock into World Clock, Sun Card into Weather, Stopwatch into Countdown, Volume/Microphone into Audio Deck, the visual pass on the instruments (System Insight, Network Scope, Audio Deck, Calendar, Moon Phase, Weather) and Studio Jobs settings. Those need replacement coverage built first, so no deprecation is published for them.
- **QA VM**: success states of Containers and Device Battery were captured with **labelled fixture shims** for `podman` and `upower` (fake executables in the guest, see `docs/evidence/catalog-audit/vm-shims/`); the Git Board and Port Watch captures use real tools. Control Center settings pages could not be captured: pointer clicks in the VM only hover (no activation), and the shell has no IPC to open a plugin's settings. Desktop widgets that do not fit are reported by the shell ("Hidden, no room on the desktop"), seen with seven widgets at 1280x800.

## Second follow-up: replacements built, then deprecated

- **Weather 3.1.0 absorbs Sun Card**: day length, next sun event and daylight progress (derived, labelled) behind `showSunProgress`; bar indicator `barIndicator = sun` shows sunrise and sunset. Sun Card is deprecated.
- **World Clock 3.2.0 absorbs Dual Clock**: new bar surface (`barZone`, `barShowSeconds`) sharing the zone rule table verbatim (tested). Dual Clock is deprecated.
- **Countdown 3.1.0 absorbs Stopwatch**: one indicator, popover switches countdown/stopwatch, Stopwatch stored keys carry over. Stopwatch is deprecated.
- **Studio Jobs 2.1.0**: the settings gap is closed (`refreshSeconds`, `maxRows`, `showAdapter`, `showFinished`).
- **Not absorbed**: Volume and Microphone. Audio Deck is a desktop widget; folding interactive volume and mute controls into it would not be the same function, so they stay until Audio Deck has a bar surface worth shipping.
- **Platform status**: apiLevel 4 settings v2 (shell#602), per-instance widgets (#603), command contributions (#605), tile and panel contributions (#613) and atmosphere (#608) are open PRs, not on main, so nothing here uses them yet. Planned adoption once merged: settings v2 `list` for Git Board repositories and Port Watch ports (replacing semicolon strings), `colour` for the Colour tool default, `visibleWhen` for the Pomodoro hook, per-instance Git Board and World Clock, a Toolbox launcher command, a Pomodoro tile, and the atmosphere tokens for the instrument pass.
- **Instrument visual pass** (System Insight, Network Scope, Audio Deck, Calendar, Moon Phase): deliberately not started. Their look depends on the atmosphere tokens (#608) and the shared mascot empty state; restyling them now would be redone.

## CPU measurements (QA VM, 2026-11-17)

Shell process CPU, one extension enabled at a time with its widget visible, experience Everyday, single 40 s sample each (VM noise about 1 pp; raw data in `docs/evidence/catalog-audit/vm3-cpu.txt`):

| Enabled | CPU (% of one core) |
|---|--:|
| none (baseline) | 5.5 |
| git-board | 5.5 |
| port-watch | 6.9 |
| containers (podman shim) | 6.8 |
| device-battery (upower shim) | 6.5 |
| forge-board (gh missing) | 6.8 |
| toolbox | 5.6 |
| pomodoro | 8.5 |
| countdown | 6.6 |
| weather | 6.6 |
| world-clock | 5.2 |
| studio-jobs | 5.6 |
| all 11 | 7.8 |

Reading: the process-spawning cards cost about 1 pp, everything else is within noise, and all eleven together cost 2.3 pp. Pomodoro's 8.5 is an unexplained outlier (it keeps a 2 s settings re-read timer while idle) and stays `unverified` until repeated. These are VM numbers, not host numbers.
