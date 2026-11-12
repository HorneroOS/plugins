import QtQuick
import Hornero.PluginKit

// Hornero System Monitor - dashboard card over PluginKit System.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    function pct(v) {
        return Math.round(Math.max(0, Math.min(1, v)) * 100) + "%";
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            color: Theme.onSurface
            text: "System"
            font.bold: true
            font.pixelSize: 14
        }

        Repeater {
            model: [
                { "label": "CPU", "value": System.cpuPerc, "detail": root.pct(System.cpuPerc) + (System.cpuTemp > 0 ? "  " + Math.round(System.cpuTemp) + " C" : "") },
                { "label": "Memory", "value": System.memPerc, "detail": root.pct(System.memPerc) },
                { "label": "GPU", "value": System.gpuPerc, "detail": root.pct(System.gpuPerc) + (System.gpuTemp > 0 ? "  " + Math.round(System.gpuTemp) + " C" : "") },
                { "label": "Storage", "value": System.storagePerc, "detail": root.pct(System.storagePerc) }
            ]

            delegate: Column {
                width: content.width
                spacing: 2

                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        color: Theme.onSurface
                        text: modelData.label
                        width: 64
                    }

                    Text {
                        color: Theme.onSurfaceVariant
                        text: modelData.detail
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.surfaceContainer

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, modelData.value))
                        height: parent.height
                        radius: 3
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
