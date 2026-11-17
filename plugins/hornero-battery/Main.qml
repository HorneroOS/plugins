import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Battery 2.0 bar surface (primary, HorneroOS/plugins#31):
// contextual visibility over the shared PluginKit Power facade
// (hasBattery, percentage, charging, onBattery, stateText;
// event-pushed by UPower, never polled). With no battery reported
// the indicator takes no bar space unless the user opts in with
// showWhenNoBattery; 1.x always showed a permanent "No battery"
// item. Activating the indicator opens a host-owned UiPopover with
// every power detail the facade really exposes: charge, time to
// empty/full, energy rate, battery health and power profile (each
// shown only when UPower reports it, otherwise an em dash). The
// facade has no explicit AC-online or ready member, so none is
// invented: percentage reads 0 when no battery is present and
// charging is also true when fully charged, so those states are
// carried by stateText and the no-battery case never shows a
// fabricated percentage.
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

    function batteryGlyph() {
        if (!Power.hasBattery)
            return "plug-off";
        if (root.low)
            return "battery-exclamation";
        if (Power.charging)
            return "battery-charging";
        const p = root.clampPercent(Power.percentage);
        return p >= 88 ? "battery-4" : p >= 63 ? "battery-3" : p >= 38 ? "battery-2" : p >= 13 ? "battery-1" : "battery";
    }

    // Seconds from the Power facade (UPower) as "3 h 20 min"; empty when
    // the platform reports none (0), never a guess.
    function fmtDuration(seconds) {
        const s = Number(seconds);
        if (!isFinite(s) || s <= 0)
            return "";
        const h = Math.floor(s / 3600);
        const m = Math.round((s % 3600) / 60);
        return h > 0 ? i18n.tr("%1 h %2 min").arg(h).arg(m) : i18n.tr("%1 min").arg(m);
    }

    readonly property string remainingText: Power.charging ? fmtDuration(Power.timeToFull) : fmtDuration(Power.timeToEmpty)

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

            variant: "quiet"
            glyph: root.batteryGlyph()
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
            tone: "alert"
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
            spacing: Theme.spacing.small

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
                spacing: Theme.spacing.small

                UiStack {
                    width: parent.width
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiChip {
                        visible: root.low
                        text: i18n.tr("Low")
                        tone: "alert"
                    }

                    UiChip {
                        visible: !root.low && root.stateLabel(Power.stateText) !== ""
                        text: root.stateLabel(Power.stateText)
                        tone: Power.charging ? "phosphor" : "neutral"
                    }
                }

                UiMeterRow {
                    width: parent.width
                    label: i18n.tr("CHG")
                    value: root.clampPercent(Power.percentage) / 100
                    valueText: i18n.tr("%1 %").arg(root.clampPercent(Power.percentage))
                    threshold: root.low ? 0 : 1.01
                }

                UiStack {
                    width: parent.width
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: Power.charging ? i18n.tr("Time to full") : i18n.tr("Time left")
                        value: root.remainingText
                        available: root.remainingText !== ""
                        size: "value"
                    }

                    UiMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: i18n.tr("Rate")
                        value: Power.energyRate > 0 ? Power.energyRate.toFixed(1) : ""
                        unit: "W"
                        available: Power.energyRate > 0
                        size: "value"
                    }
                }

                UiStack {
                    width: parent.width
                    orientation: root.hostOrientation
                    compact: root.hostCompact

                    UiMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: i18n.tr("Health")
                        value: Power.healthAvailable ? String(Power.health) : ""
                        unit: "%"
                        available: Power.healthAvailable
                        size: "value"
                    }

                    UiMetric {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        label: i18n.tr("Profile")
                        value: Power.profile
                        available: Power.profile !== ""
                        size: "value"
                    }
                }
            }
        }
    }
}
