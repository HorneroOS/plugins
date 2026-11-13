# Hornero Disk Usage

Disk Usage 2.0 (manifest v2): a dashboard card over the shared
PluginKit `System.disks` facade (holding a
`Subscription { domain: "system" }` lease). The shell service
reports each disk as `{ mount, used, total, free, perc }` in
KiB, with `mount` carrying the disk name (shell
`services/SystemUsage.qml`). 1.x formatted those KiB values as
if they were bytes — every figure read 1024× too small — and
2.0 formats them as KiB, so displayed sizes change to the
correct values while the per-disk rows and bars stay the same.
2.0 also adds free space per disk, a disk count, a most-full
summary and a nearly-full alert at the user's threshold.

The PluginKit facade exposes no SMART or drive-health data, so
the card shows capacity only and says so in the UI. Treat
"nearly full" as a capacity warning, never as a health verdict
about the drive.

## Compatibility

- The plugin declared no settings before 2.0, so no stored
  values migrate. New typed settings are additive:
  `warnPercent` (integer 50–100, default `90`) and
  `showFreeSpace` (boolean, default `true`).
- Absolute sizes are corrected from the 1.x KiB-as-bytes
  formatting (above); percentages were and remain the
  service-reported fraction.
- Installing this manifest v2 package needs a shell /
  `horneroctl` that accepts `schemaVersion` 2, the dashboard
  surface hints, the `translations` declaration and the
  `marketplace` block.

## The 8 Hornero quality questions

1. **Unique value.** Per-disk capacity triage — used/total/free per disk, which disk is most full, and an alert before a full disk starts breaking updates and caches.
2. **Native overlap.** System Monitor and System Health show one aggregate storage percentage; the native Performance storage gauge shows one disk at a time. This card's distinct value is every disk side by side with free space, for deciding where to clean up.
3. **Why an extension.** Capacity triage is an occasional maintenance task; an opt-in card serves it without adding a permanent per-disk panel to the native shell.
4. **Surfaces.** One dashboard surface (`"placement": "dashboard"`, redeclared in `surfaces.dashboard` with `size: "standard"`, `category: "System"`).
5. **Actions.** None. Read-only capacity display: no broker actions, no processes, no delete or cleanup actions (the facade offers none and faking one would be destructive).
6. **Configuration.** Typed settings listed under Compatibility, read via PluginKit `Settings`.
7. **Missing-data behaviour.** When the service reports no disks the card is an explicit empty state (`No disks reported by the System service.`), as in 1.x. A disk without usable totals reads as zero rather than an invented size. SMART/health is absent, labelled as not exposed.
8. **Disable behaviour.** Disabling the extension destroys the card and releases its `system` Subscription lease. Nothing is stored.

No processes and no network access of its own. Original
HorneroOS code, MIT licensed. Plugin QML runs with your user
privileges inside Quickshell; it is not sandboxed.
