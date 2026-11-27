import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Studio Audio 2.0 dashboard surface: the card form of the bar
// popover — Studio mode and Temporary Performance from the typed
// `horneroctl --json studio mode` contract on the typed
// refreshSeconds cadence, plus read-only output state from the
// shared PluginKit Audio facade. Read-only: mode switching stays
// in the CLI and Control Center.
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

    property string mode: ""
    property bool performance: false
    property bool available: false
    property string buffer: ""

    readonly property int refreshSeconds: {
        const value = Number(pluginSettings.value("refreshSeconds", 60));
        return isFinite(value) && value >= 15 ? Math.min(3600, Math.floor(value)) : 60;
    }

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    function modeName(value: string): string {
        if (value === "low-latency")
            return i18n.tr("Low Latency");
        if (value === "advanced")
            return i18n.tr("Advanced");
        if (value === "balanced")
            return i18n.tr("Balanced");
        return i18n.tr("Unknown mode");
    }

    function refresh(): void {
        if (!modeProc.running) {
            root.buffer = "";
            modeProc.running = true;
        }
    }

    Component.onCompleted: refresh()

    Subscription {
        domain: "audio"
    }

    Translations {
        id: i18n

        pluginId: "hornero-studio-audio"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-studio-audio"
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.visible && Theme.experience !== "gaming"
        onTriggered: root.refresh()
    }

    onVisibleChanged: if (visible && Theme.experience !== "gaming")
        refresh()

    Process {
        id: modeProc

        command: ["horneroctl", "--json", "studio", "mode"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.available = false;
                root.mode = "";
                root.performance = false;
                return;
            }
            try {
                const env = JSON.parse(root.buffer.trim());
                const data = (env && env.data) || {};
                root.mode = String(data.audio_mode || "");
                root.performance = data.performance_active === "true" || data.performance_active === true;
                root.available = env.ok === true && root.mode.length > 0;
            } catch (e) {
                root.available = false;
                root.mode = "";
                root.performance = false;
            }
        }
    }

    UiCard {
        id: card

        anchors.fill: parent
        Accessible.name: i18n.tr("Studio Audio")
        title: i18n.tr("Studio Audio")
        glyph: "wave-sine"
        channel: 13

        Column {
            width: parent.width
            spacing: Theme.spacing.small

            UiState {
                visible: !root.available
                width: parent.width
                kind: "error"
                message: i18n.tr("Studio mode is unavailable.")
            }

            Column {
                visible: root.available
                width: parent.width
                spacing: Theme.spacing.small

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        size: "value"
                        label: i18n.tr("Mode")
                        value: root.modeName(root.mode)
                    }

                    UiChip {
                        text: root.performance ? i18n.tr("Temporary Performance on") : i18n.tr("Temporary Performance off")
                        tone: root.performance ? "signal" : "neutral"
                    }
                }

                UiMeterRow {
                    visible: Audio.hasSink
                    width: parent.width
                    label: i18n.tr("OUT")
                    value: Audio.muted ? 0 : Audio.volume
                    valueText: Audio.muted ? i18n.tr("Muted") : i18n.tr("%1 %").arg(Math.round(Audio.volume * 100))
                    valueWidth: 72
                    threshold: 1.01
                }

                UiText {
                    visible: !Audio.hasSink
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("No output device is available.")
                }
            }

            UiText {
                width: parent.width
                role: "caption"
                text: i18n.tr("Read-only. Change modes in Control Center.")
            }

            UiButton {
                variant: "quiet"
                glyph: "refresh"
                text: i18n.tr("Refresh")
                tooltipText: i18n.tr("Reload studio mode")
                accessibleName: i18n.tr("Refresh studio mode")
                onClicked: root.refresh()
            }
        }
    }
}
