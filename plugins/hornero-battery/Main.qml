import QtQuick
import Hornero.PluginKit

// Battery 2.0 bar surface (primary, HorneroOS/plugins#31):
// contextual visibility over the shared PluginKit Power facade
// (hasBattery, percentage, charging, onBattery, stateText;
// event-pushed by UPower, never polled). With no battery reported
// the indicator takes no bar space unless the user opts in with
// showWhenNoBattery; 1.x always showed a permanent "No battery"
// item. Activating the indicator opens a host-owned UiPopover
// with every power detail the facade really exposes. The facade
// has no time-remaining, health/capacity, power-profile, explicit
// AC-online or ready/valid member (shell plugin/qml/Hornero/
// PluginKit/Power.qml), so none is invented: percentage reads 0
// when no battery is present and charging is also true when
// fully charged, so those states are carried by stateText and
// the no-battery case never shows a fabricated percentage.
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

    // LOGIC-BEGIN (kept verbatim in Dashboard.qml; pure logic only)
    function clampPercent(value) {
        const n = Number(value);
        return isFinite(n) ? Math.max(0, Math.min(100, Math.round(n))) : 0;
    }

    function barShown(hasBattery, showWhenNoBattery) {
        return hasBattery === true || showWhenNoBattery === true;
    }

    function isLow(hasBattery, onBattery, percentage, threshold) {
        return hasBattery === true && onBattery === true && clampPercent(percentage) <= threshold;
    }

    function stateKey(stateText) {
        if (stateText === "charging" || stateText === "fully-charged" || stateText === "discharging" || stateText === "pending-charge")
            return stateText;
        return stateText ? "unknown" : "";
    }
    // LOGIC-END

    function stateLabel(stateText) {
        const key = stateKey(stateText);
        if (key === "charging")
            return i18n.tr("Charging");
        if (key === "fully-charged")
            return i18n.tr("Fully charged");
        if (key === "discharging")
            return i18n.tr("Discharging");
        if (key === "pending-charge")
            return i18n.tr("Pending charge");
        if (key === "unknown")
            return i18n.tr("Unknown");
        return "";
    }

    // Typed settings: the plugin stored no settings before 2.0, so
    // no stored values migrate. showPercentage/showStateText
    // defaults keep the 1.x label; showWhenNoBattery defaults off
    // per issue #31 (opt-in restores the permanent 1.x item).
    readonly property bool showWhenNoBattery: pluginSettings.value("showWhenNoBattery", false) === true
    readonly property bool showPercentage: pluginSettings.value("showPercentage", true) !== false
    readonly property bool showStateText: pluginSettings.value("showStateText", true) !== false
    readonly property int lowBatteryPercent: {
        const value = Number(pluginSettings.value("lowBatteryPercent", 20));
        return isFinite(value) && value >= 5 ? Math.min(50, Math.floor(value)) : 20;
    }

    readonly property bool shown: barShown(Power.hasBattery, showWhenNoBattery)
    readonly property bool low: isLow(Power.hasBattery, Power.onBattery, Power.percentage, lowBatteryPercent)
    readonly property string statusText: {
        if (!Power.hasBattery)
            return i18n.tr("No battery");
        let text = showPercentage ? i18n.tr("Battery %1%").arg(clampPercent(Power.percentage)) : i18n.tr("Battery");
        if (Power.charging)
            text += " ⚡";
        if (showStateText && stateLabel(Power.stateText) !== "")
            text += " " + stateLabel(Power.stateText);
        if (low)
            text += " " + i18n.tr("Low");
        return text;
    }

    implicitWidth: shown ? stack.implicitWidth : 0
    implicitHeight: shown ? stack.implicitHeight : 0

    Subscription {
        domain: "power"
    }

    Translations {
        id: i18n

        pluginId: "hornero-battery"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-battery"
    }

    UiStack {
        id: stack

        visible: root.shown
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator

            variant: "ghost"
            text: !Power.hasBattery ? "✕" : Power.charging ? "🔌" : "🔋"
            tooltipText: root.statusText
            accessibleName: i18n.tr("Battery details")
            onClicked: popover.toggle()
        }

        UiText {
            visible: !root.hostCompact && root.hostOrientation !== "vertical"
            role: "body"
            text: root.statusText
        }

        UiChip {
            visible: root.low
            text: i18n.tr("Low")
            tone: "error"
        }
    }

    UiTooltip {
        target: indicator
        text: root.statusText
    }

    UiPopover {
        id: popover

        target: indicator
        accessibleName: i18n.tr("Battery details")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Battery")
            }

            UiState {
                visible: !Power.hasBattery
                width: parent.width
                kind: "empty"
                message: i18n.tr("No battery is reported by the Power service. The bar indicator stays hidden unless you enable 'show when no battery'.")
            }

            Column {
                visible: Power.hasBattery
                width: parent.width
                spacing: Theme.spacingSmall

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("Charge")
                        value: i18n.tr("%1%").arg(root.clampPercent(Power.percentage))
                    }

                    UiChip {
                        visible: root.low
                        text: i18n.tr("Low")
                        tone: "error"
                    }

                    UiChip {
                        visible: !root.low && root.stateLabel(Power.stateText) !== ""
                        text: root.stateLabel(Power.stateText)
                        tone: Power.charging ? "primary" : "neutral"
                    }
                }

                UiProgress {
                    width: parent.width
                    value: root.clampPercent(Power.percentage) / 100
                    accessibleName: i18n.tr("Charge")
                }

                UiStack {
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        label: i18n.tr("State")
                        value: root.stateLabel(Power.stateText) !== "" ? root.stateLabel(Power.stateText) : i18n.tr("Unknown")
                    }

                    UiMetric {
                        label: i18n.tr("On battery")
                        value: Power.onBattery ? i18n.tr("Yes") : i18n.tr("No")
                    }

                    UiMetric {
                        label: i18n.tr("Charging")
                        value: Power.charging ? i18n.tr("Yes") : i18n.tr("No")
                    }
                }

                UiText {
                    width: parent.width
                    role: "caption"
                    text: i18n.tr("PluginKit Power does not expose time remaining, battery health or power profiles, so they are not shown. 'Not on battery' is reported as No above; the facade has no separate AC-online signal.")
                }
            }
        }
    }
}
