import QtQuick

// Hornero Dual Clock — local time and UTC side by side in the bar.
Item {
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 8

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: ""

        Timer {
            interval: 1000
            repeat: true
            running: true
            triggeredOnStart: true
            onTriggered: {
                const now = new Date();
                label.text = pad(now.getHours()) + ":" + pad(now.getMinutes()) + " · " + pad(now.getUTCHours()) + ":" + pad(now.getUTCMinutes()) + " UTC";
            }
        }
    }
}
