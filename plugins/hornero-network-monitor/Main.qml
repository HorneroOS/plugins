import QtQuick
import Hornero.PluginKit

// Hornero Network Monitor - dashboard card over PluginKit Network.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    function fmt(bytes) {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let v = Math.max(0, Number(bytes) || 0);
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(v) : v.toFixed(1)) + " " + units[i];
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
            color: Theme.onSurface
            text: "Network"
            font.bold: true
            font.pixelSize: 14
        }

        Text { color: Theme.onSurface; text: "Download: " + root.fmt(Network.downloadSpeed) + "/s" }
        Text { color: Theme.onSurface; text: "Upload: " + root.fmt(Network.uploadSpeed) + "/s" }
        Text { color: Theme.onSurfaceVariant; text: "Downloaded (session): " + root.fmt(Network.downloadTotal) }
        Text { color: Theme.onSurfaceVariant; text: "Uploaded (session): " + root.fmt(Network.uploadTotal) }
    }
}
