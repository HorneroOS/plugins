import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Hornero.PluginKit

// Device Battery: charge of the wireless things on your desk: game
// controllers, mice, keyboards, headsets, pens, phones. Data is one
// `upower -d` run per refresh (UPower is the same service behind the shell's
// own battery). A device that does not report a percentage is listed with its
// state only; nothing is estimated. Laptop and UPS batteries are left to the
// native battery indicator unless you turn them on.
Item {
    id: root

    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    readonly property string widgetTitle: i18n.tr("Device Battery")
    readonly property string widgetContext: lowCount > 0 ? i18n.tr("%1 LOW").arg(lowCount) : ""
    readonly property int contentWidth: hostAvailableWidth > 0 ? hostAvailableWidth : 380

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight

    Translations {
        id: i18n

        pluginId: "hornero-device-battery"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-device-battery"
    }

    readonly property int lowPercent: Math.max(5, Math.min(50, Number(pluginSettings.value("lowPercent", 20)) || 20))
    readonly property bool includeInternal: pluginSettings.value("includeInternal", false) === true
    readonly property bool showModel: pluginSettings.value("showModel", true) !== false
    readonly property int refreshSeconds: Math.max(15, Math.min(600, Number(pluginSettings.value("refreshSeconds", 60)) || 60))
    readonly property string sortMode: String(pluginSettings.value("sortBy", "lowest"))

    property var all: []
    property bool loaded: false
    property bool failed: false
    property string buffer: ""

    // DEVICES-LOGIC-BEGIN
    function parseDevices(text) {
        const out = [];
        let cur = null;
        const lines = String(text).split("\n");
        for (let i = 0; i < lines.length; i++) {
            const l = lines[i];
            if (l.indexOf("Device:") === 0) {
                cur = {
                    path: l.slice(7).trim(),
                    type: "",
                    model: "",
                    percent: -1,
                    state: "",
                    supply: false,
                    present: true
                };
                out.push(cur);
                continue;
            }
            if (l.indexOf("Daemon:") === 0) {
                cur = null;
                continue;
            }
            if (!cur)
                continue;
            let m = /^  ([a-z][a-z-]*)\s*$/.exec(l);
            if (m) {
                cur.type = m[1];
                continue;
            }
            m = /^\s+([a-z -]+):\s+(.*)$/.exec(l);
            if (!m)
                continue;
            const key = m[1].trim();
            const val = m[2].trim();
            if (key === "model")
                cur.model = val;
            else if (key === "power supply")
                cur.supply = val === "yes";
            else if (key === "present")
                cur.present = val === "yes";
            else if (key === "state")
                cur.state = val;
            else if (key === "percentage") {
                const n = parseFloat(val);
                if (isFinite(n))
                    cur.percent = Math.round(n);
            }
        }
        return out;
    }

    function label(d) {
        const names = {
            "mouse": "Mouse",
            "keyboard": "Keyboard",
            "gaming-input": "Game controller",
            "headset": "Headset",
            "headphones": "Headphones",
            "touchpad": "Touchpad",
            "tablet": "Tablet",
            "pen": "Pen",
            "phone": "Phone",
            "media-player": "Media player",
            "battery": "Battery",
            "ups": "UPS",
            "monitor": "Display"
        };
        return names[d.type] || d.type;
    }

    function pick(devices, includeInternal) {
        return devices.filter(function (d) {
            if (!d.present || d.type === "line-power" || d.type === "" || d.type === "unknown")
                return false;
            if (d.type === "battery" || d.type === "ups")
                return includeInternal && d.supply;
            if (d.supply)
                return false;
            return true;
        });
    }

    function arrange(devices, mode) {
        const copy = devices.slice();
        copy.sort(function (a, b) {
            if (mode === "lowest") {
                const pa = a.percent < 0 ? 1000 : a.percent;
                const pb = b.percent < 0 ? 1000 : b.percent;
                if (pa !== pb)
                    return pa - pb;
            }
            return a.type < b.type ? -1 : a.type > b.type ? 1 : 0;
        });
        return copy;
    }
    // DEVICES-LOGIC-END

    readonly property int fitRows: hostAvailableHeight > 0 ? Math.max(1, Math.floor((hostAvailableHeight + 4) / 92)) : 99
    readonly property var shownRows: arrange(pick(all, includeInternal), sortMode).slice(0, fitRows)
    readonly property int lowCount: shownRows.filter(d => d.percent >= 0 && d.percent <= lowPercent && d.state !== "charging").length

    property bool pendingRun: false

    function refresh(): void {
        if (!proc.running) {
            buffer = "";
            pendingRun = true;
            proc.running = true;
        }
    }

    Timer {
        id: lostExit

        interval: 400
        repeat: false
        running: false
        onTriggered: {
            if (root.pendingRun) {
                root.pendingRun = false;
                root.loaded = true;
                root.failed = true;
            }
        }
    }

    Process {
        id: proc

        command: ["upower", "-d"]

        // A missing executable never reports an exit: if the process stops
        // without one, say so instead of staying on "asking" forever.
        onRunningChanged: if (!running && root.pendingRun)
            lostExit.restart()

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data + "\n";
            }
        }
        onExited: (code, status) => {
            root.pendingRun = false;
            root.loaded = true;
            if (code === 0) {
                root.all = root.parseDevices(root.buffer);
                root.failed = false;
            } else {
                root.failed = true;
            }
        }
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    function tone(d) {
        if (d.percent < 0)
            return "neutral";
        if (d.state === "charging")
            return "cue";
        return d.percent <= lowPercent ? "alert" : "phosphor";
    }

    function stateText(d) {
        if (d.state === "charging")
            return i18n.tr("CHARGING");
        if (d.state === "fully-charged")
            return i18n.tr("FULL");
        if (d.percent >= 0 && d.percent <= lowPercent)
            return i18n.tr("LOW");
        if (d.state === "discharging")
            return i18n.tr("IN USE");
        return d.state.length > 0 ? d.state.toUpperCase() : i18n.tr("UNKNOWN");
    }

    function glyphFor(d) {
        return d.type === "gaming-input" ? "device-gamepad" : d.type === "keyboard" ? "keyboard" : d.type === "mouse" ? "mouse" : d.type === "headset" || d.type === "headphones" ? "headphones" : d.type === "phone" ? "device-mobile" : d.type === "battery" ? "battery" : "plug-connected";
    }

    Column {
        id: column

        width: root.contentWidth
        spacing: Theme.spacing.smaller
        Accessible.name: i18n.tr("Device Battery")

        UiState {
            visible: root.loaded && root.failed
            width: parent.width
            kind: "error"
            message: i18n.tr("UPower did not answer (is upower installed and its service running?).")
        }

        UiState {
            visible: !root.loaded
            width: parent.width
            kind: "loading"
            message: i18n.tr("Asking UPower…")
        }

        UiState {
            visible: root.loaded && !root.failed && root.shownRows.length === 0
            width: parent.width
            kind: "empty"
            glyph: "plug-off"
            message: i18n.tr("No wireless devices report a battery. Pair a controller, mouse or headset and it will appear here.")
        }

        Repeater {
            model: root.failed ? [] : root.shownRows

            delegate: Rectangle {
                id: row

                required property var modelData
                readonly property var d: modelData

                width: column.width
                height: body.implicitHeight + Theme.padding.normal * 2
                radius: Theme.rounding.small
                color: Theme.palette.sunken
                border.width: 1
                border.color: Theme.palette.rule
                Accessible.name: d.percent >= 0 ? i18n.tr("%1 at %2 percent, %3").arg(root.label(d)).arg(d.percent).arg(root.stateText(d)) : i18n.tr("%1, %2").arg(root.label(d)).arg(root.stateText(d))

                ColumnLayout {
                    id: body

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.padding.normal
                        rightMargin: Theme.padding.normal
                    }
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        UiIcon {
                            name: root.glyphFor(d)
                            color: Theme.palette.inkMuted
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            UiText {
                                Layout.fillWidth: true
                                role: "subtitle"
                                text: root.label(d)
                                elide: Text.ElideRight
                            }

                            UiText {
                                visible: root.showModel && d.model.length > 0
                                Layout.fillWidth: true
                                role: "caption"
                                text: d.model
                                elide: Text.ElideRight
                                color: Theme.palette.inkFaint
                            }
                        }

                        UiChip {
                            text: root.stateText(d)
                            tone: root.tone(d)
                        }
                    }

                    UiMeterRow {
                        visible: d.percent >= 0
                        Layout.fillWidth: true
                        label: ""
                        labelWidth: 0
                        value: d.percent / 100
                        valueText: d.percent + " %"
                        threshold: 1.01
                        count: 20
                    }
                }
            }
        }
    }
}
