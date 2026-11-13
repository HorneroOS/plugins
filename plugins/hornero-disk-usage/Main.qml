import QtQuick
import Hornero.PluginKit

// Disk Usage 2.0: dashboard card over the shared PluginKit
// System.disks facade. The shell service reports each disk as
// { mount, used, total, free, perc } where mount carries the disk
// name and used/total/free are in KiB (shell services/SystemUsage
// .qml); 1.x formatted those KiB values as if they were bytes, and
// 2.0 formats them as KiB. The card adds free space, a near-full
// alert and a most-full summary on top of the 1.x per-disk bars.
// The facade exposes no SMART or drive-health data, so none is
// shown. Field spellings stay defensive for older shells.
Item {
    id: root

    // Host context (opt-in): defaults keep a roomy dashboard card.
    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Subscription {
        domain: "system"
    }

    Translations {
        id: i18n

        pluginId: "hornero-disk-usage"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-disk-usage"
    }

    // Typed settings: defaults keep the 1.x per-disk rows; free
    // space and the near-full flag are additive. The plugin
    // stored no settings before 2.0, so nothing migrates.
    readonly property int warnPercent: {
        const value = Number(pluginSettings.value("warnPercent", 90));
        return isFinite(value) && value >= 50 ? Math.min(100, Math.floor(value)) : 90;
    }
    readonly property bool showFreeSpace: pluginSettings.value("showFreeSpace", true) !== false

    function disks() {
        return (System.disks && System.disks.length !== undefined) ? System.disks : [];
    }

    function nameOf(d) {
        if (typeof d === "string")
            return d;
        return String(d.mount || d.mountPoint || d.path || d.device || "?");
    }

    // KiB values, as reported by the shell System service.
    function totalKiB(d) {
        if (!d || typeof d === "string")
            return 0;
        return Number(d.total || d.totalBytes || d.size || d.capacity || 0);
    }

    function usedKiB(d) {
        if (!d || typeof d === "string")
            return 0;
        if (d.used !== undefined && d.used !== null)
            return Number(d.used);
        if (d.usedBytes !== undefined && d.usedBytes !== null)
            return Number(d.usedBytes);
        const total = totalKiB(d);
        const free = Number(d.available || d.free || d.freeBytes || 0);
        return total > 0 ? Math.max(0, total - free) : 0;
    }

    function freeKiB(d) {
        if (!d || typeof d === "string")
            return 0;
        if (d.free !== undefined && d.free !== null)
            return Number(d.free);
        if (d.available !== undefined && d.available !== null)
            return Number(d.available);
        const total = totalKiB(d);
        return total > 0 ? Math.max(0, total - usedKiB(d)) : 0;
    }

    function fracOf(d) {
        if (d && typeof d !== "string") {
            const p = (d.perc !== undefined ? d.perc : (d.percent !== undefined ? d.percent : d.usedPerc));
            if (p !== undefined && p !== null && isFinite(Number(p)))
                return Number(p) > 1 ? Number(p) / 100 : Number(p);
        }
        const total = totalKiB(d);
        return total > 0 ? usedKiB(d) / total : 0;
    }

    function fmtKiB(kib) {
        const k = Math.max(0, Number(kib) || 0);
        if (k >= 1073741824)
            return (k / 1073741824).toFixed(1) + " TiB";
        if (k >= 1048576)
            return (k / 1048576).toFixed(1) + " GiB";
        if (k >= 1024)
            return (k / 1024).toFixed(1) + " MiB";
        return Math.round(k) + " KiB";
    }

    readonly property var mostFull: {
        const list = disks();
        let best = null;
        for (let i = 0; i < list.length; i++)
            if (best === null || fracOf(list[i]) > fracOf(best))
                best = list[i];
        return best;
    }
    readonly property bool anyNearFull: mostFull !== null && fracOf(mostFull) * 100 >= warnPercent

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Disk Usage")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("Disk Usage")
                }

                UiChip {
                    visible: root.anyNearFull
                    text: i18n.tr("Nearly full")
                    tone: "error"
                }
            }

            UiState {
                visible: root.disks().length === 0
                width: parent.width
                kind: "empty"
                message: i18n.tr("No disks reported by the System service.")
            }

            UiStack {
                visible: root.mostFull !== null
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiMetric {
                    label: i18n.tr("Disks")
                    value: String(root.disks().length)
                }

                UiMetric {
                    label: i18n.tr("Most full")
                    value: root.mostFull !== null ? root.nameOf(root.mostFull) + " " + Math.round(root.fracOf(root.mostFull) * 100) + "%" : i18n.tr("Unavailable")
                }
            }

            UiText {
                visible: root.showFreeSpace && root.anyNearFull
                width: parent.width
                role: "caption"
                text: i18n.tr("A nearly full disk can block updates and caches; free space on the flagged disk.")
            }

            Repeater {
                model: root.disks()

                delegate: Column {
                    required property var modelData

                    width: parent.width
                    spacing: Theme.spacingSmall

                    UiStack {
                        orientation: root.hostOrientation
                        compact: root.hostCompact

                        UiMetric {
                            label: root.nameOf(modelData)
                            value: root.fmtKiB(root.usedKiB(modelData)) + " / " + root.fmtKiB(root.totalKiB(modelData)) + " (" + Math.round(root.fracOf(modelData) * 100) + "%)"
                        }

                        UiChip {
                            visible: root.fracOf(modelData) * 100 >= root.warnPercent
                            text: i18n.tr("Nearly full")
                            tone: "error"
                        }
                    }

                    UiText {
                        visible: root.showFreeSpace
                        role: "caption"
                        text: i18n.tr("Free") + ": " + root.fmtKiB(root.freeKiB(modelData))
                    }

                    UiProgress {
                        width: parent.width
                        value: Math.max(0, Math.min(1, root.fracOf(modelData)))
                        accessibleName: root.nameOf(modelData)
                    }
                }
            }

            UiText {
                visible: root.disks().length > 0
                width: parent.width
                role: "caption"
                text: i18n.tr("Drive health (SMART) is not exposed to extensions and is not shown.")
            }
        }
    }
}
