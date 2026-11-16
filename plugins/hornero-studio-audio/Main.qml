import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Studio Audio 2.0 bar surface (primary): a compact indicator for
// the Studio audio mode and Temporary Performance state, read from
// the existing typed contract `horneroctl --json studio mode`
// (HorneroOS/hornero#286/#287) on the typed refreshSeconds cadence,
// plus current output state from the shared PluginKit Audio facade
// in the popover. Read-only: switching modes is an explicit opt-in
// that belongs to the CLI and Control Center, never to this
// indicator, and no PipeWire object is manipulated here.
Item {
    id: root

    // Host context (opt-in): defaults match the 1.x roomy
    // horizontal bar layout when no host values are injected.
    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    property string mode: ""
    property bool performance: false
    property bool available: false
    property string buffer: ""

    readonly property bool showWhenUnavailable: pluginSettings.value("showWhenUnavailable", true) !== false
    readonly property bool shown: available || showWhenUnavailable
    readonly property int refreshSeconds: {
        const value = Number(pluginSettings.value("refreshSeconds", 60));
        return isFinite(value) && value >= 15 ? Math.min(3600, Math.floor(value)) : 60;
    }
    readonly property string shortMode: mode === "low-latency" ? "LL" : mode === "advanced" ? "ADV" : mode === "balanced" ? "BAL" : "?"
    readonly property string statusText: available ? modeName(mode) + (performance ? " · " + i18n.tr("Temporary Performance on") : "") : i18n.tr("Studio mode unavailable")

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

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
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: modeProc

        command: ["horneroctl", "--json", "studio", "mode"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }
        onExited: {
            try {
                const env = JSON.parse(root.buffer.trim());
                const data = (env && env.data) || {};
                root.mode = String(data.audio_mode || "");
                root.performance = data.performance_active === "true";
                root.available = env.ok === true && root.mode.length > 0;
            } catch (e) {
                root.available = false;
                root.mode = "";
                root.performance = false;
            }
        }
    }

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "ghost"
            // One native icon per mode; the mode name lives in the tooltip.
            iconName: !root.available ? "music_off" : root.mode === "low-latency" ? "speed" : root.mode === "advanced" ? "tune" : "graphic_eq"
            iconFill: root.performance ? 1 : 0
            tooltipText: popover.opened ? "" : root.statusText
            accessibleName: i18n.tr("Studio audio details")
            onClicked: popover.toggle()
        }

        Column {
            visible: !root.hostCompact && root.hostOrientation !== "vertical"
            spacing: 0

            UiText {
                role: "caption"
                text: i18n.tr("ST")
            }

            UiText {
                visible: root.performance
                role: "caption"
                text: i18n.tr("PERF")
            }
        }
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Studio audio details")

        // Native popout pattern (shell modules/bar/popouts): a medium
        // subtitle, a caption state line, then label/value rows — no card
        // title, hero metrics, outlined chip or floating tooltip.
        Column {
            width: 320
            spacing: Theme.spacing

            UiText {
                role: "subtitle"
                text: i18n.tr("Studio Audio")
            }

            UiText {
                visible: root.available
                role: "caption"
                text: root.performance ? i18n.tr("Temporary Performance on") : i18n.tr("Temporary Performance off")
            }

            UiState {
                visible: !root.available
                width: parent.width
                kind: "error"
                message: i18n.tr("Studio mode unavailable: horneroctl returned no usable studio mode.")
            }

            Column {
                visible: root.available
                width: parent.width
                spacing: Theme.spacingSmall

                UiDetailRow {
                    width: parent.width
                    label: i18n.tr("Mode")
                    value: root.modeName(root.mode)
                }

                UiDetailRow {
                    visible: Audio.hasSink
                    width: parent.width
                    label: i18n.tr("Output")
                    value: Audio.muted ? i18n.tr("Muted") : i18n.tr("%1%").arg(Math.round(Audio.volume * 100))
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
                text: i18n.tr("Read-only. Switching modes stays in horneroctl and Control Center.")
            }

            UiActionRow {
                width: parent.width
                iconName: "refresh"
                text: i18n.tr("Refresh")
                accessibleName: i18n.tr("Refresh studio mode")
                onClicked: root.refresh()
            }
        }
    }
}
