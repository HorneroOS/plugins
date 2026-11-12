import QtQuick
import Hornero.PluginKit

// Hornero Disk Usage - dashboard card over PluginKit System.disks.
// Each disk entry is expected to expose a mount point plus used
// and total space; common field spellings are accepted defensively
// (mount/mountPoint/path, used/usedBytes, total/totalBytes,
// available/free for deriving used, perc/percent/usedPerc).
// Shows an explicit empty state when no disks are reported.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    function disks() {
        return (System.disks && System.disks.length !== undefined) ? System.disks : [];
    }

    function mountOf(d) {
        if (typeof d === "string")
            return d;
        return String(d.mount || d.mountPoint || d.path || d.device || "?");
    }

    function totalOf(d) {
        if (!d || typeof d === "string")
            return 0;
        return Number(d.total || d.totalBytes || d.size || d.capacity || 0);
    }

    function usedOf(d) {
        if (!d || typeof d === "string")
            return 0;
        if (d.used !== undefined && d.used !== null)
            return Number(d.used);
        if (d.usedBytes !== undefined && d.usedBytes !== null)
            return Number(d.usedBytes);
        const total = totalOf(d);
        const free = Number(d.available || d.free || d.freeBytes || 0);
        return total > 0 ? Math.max(0, total - free) : 0;
    }

    function fracOf(d) {
        if (d && typeof d !== "string") {
            const p = (d.perc !== undefined ? d.perc : (d.percent !== undefined ? d.percent : d.usedPerc));
            if (p !== undefined && p !== null)
                return Number(p) > 1 ? Number(p) / 100 : Number(p);
        }
        const total = totalOf(d);
        return total > 0 ? usedOf(d) / total : 0;
    }

    function fmtBytes(bytes) {
        const b = Number(bytes || 0);
        if (b >= 1099511627776)
            return (b / 1099511627776).toFixed(1) + " TB";
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + " MB";
        if (b >= 1024)
            return (b / 1024).toFixed(1) + " KB";
        return b + " B";
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            color: Theme.onSurface
            text: "Disk Usage"
            font.bold: true
            font.pixelSize: 14
        }

        Text {
            visible: root.disks().length === 0
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.onSurfaceVariant
            text: "No disks reported by the System service."
        }

        Repeater {
            model: root.disks()

            delegate: Column {
                required property var modelData

                width: content.width
                spacing: 2

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        color: Theme.onSurface
                        width: 90
                        elide: Text.ElideRight
                        text: root.mountOf(modelData)
                    }

                    Text {
                        color: Theme.onSurfaceVariant
                        text: root.fmtBytes(root.usedOf(modelData)) + " / " + root.fmtBytes(root.totalOf(modelData)) + "  (" + Math.round(root.fracOf(modelData) * 100) + "%)"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.surfaceContainer

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.fracOf(modelData)))
                        height: parent.height
                        radius: 3
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
