import QtQuick
import Hornero.PluginKit

// Hornero Battery - bar widget over PluginKit Power
// (hasBattery, percentage, charging, onBattery, stateText).
// When Power.hasBattery is false (e.g. a desktop) it shows
// "No battery" honestly and never fabricates a percentage.
Item {
    id: root

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 34

    Text {
        id: label

        anchors.centerIn: parent
        color: Theme.onSurface
        font.pixelSize: 11
        Accessible.name: Power.hasBattery ? ("Battery " + Power.percentage + " percent" + (Power.charging ? ", charging" : "") + (Power.stateText ? ", " + Power.stateText : "")) : "No battery"
        text: {
            if (!Power.hasBattery)
                return "No battery";
            var t = Power.percentage + "%";
            if (Power.charging)
                t += " ⚡";
            else if (Power.onBattery)
                t += "";
            if (Power.stateText)
                t += " " + Power.stateText;
            return t;
        }
    }
}
