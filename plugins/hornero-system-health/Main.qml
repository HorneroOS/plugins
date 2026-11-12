import QtQuick
import Hornero.PluginKit

// Hornero System Health - dashboard card over PluginKit System,
// Power and Network. Original HorneroOS design. Every row shows
// an honest unavailable state instead of fabricated values:
// battery falls back to "No battery" when Power.hasBattery is
// false, and numeric rows show "Unavailable" when the service
// reports no usable value (undefined, null or NaN).
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    function pct(v) {
        if (v === undefined || v === null || isNaN(Number(v)))
            return "Unavailable";
        return Math.round(Math.max(0, Math.min(1, Number(v))) * 100) + "%";
    }

    function fmtSpeed(bytes) {
        if (bytes === undefined || bytes === null || isNaN(Number(bytes)))
            return "Unavailable";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let v = Math.max(0, Number(bytes) || 0);
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i] + "/s";
    }

    function batteryText() {
        if (!Power.hasBattery)
            return "No battery";
        var t = Power.percentage + "%";
        if (Power.charging)
            t += " (charging)";
        else if (Power.stateText)
            t += " (" + Power.stateText + ")";
        return t;
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            color: Theme.onSurface
            text: "System Health"
            font.bold: true
            font.pixelSize: 14
        }

        Repeater {
            model: [
                { "label": "CPU", "detail": root.pct(System.cpuPerc) },
                { "label": "Memory", "detail": root.pct(System.memPerc) },
                { "label": "Storage", "detail": root.pct(System.storagePerc) },
                { "label": "Battery", "detail": root.batteryText() },
                { "label": "Download", "detail": root.fmtSpeed(Network.downloadSpeed) },
                { "label": "Upload", "detail": root.fmtSpeed(Network.uploadSpeed) }
            ]

            delegate: Row {
                width: content.width
                spacing: 8

                Text {
                    color: Theme.onSurface
                    text: modelData.label
                    width: 72
                    Accessible.name: modelData.label + ": " + modelData.detail
                }

                Text {
                    color: Theme.onSurfaceVariant
                    text: modelData.detail
                }
            }
        }
    }
}
