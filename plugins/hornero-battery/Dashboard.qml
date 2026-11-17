import QtQuick
import QtQuick.Layouts
import Hornero.PluginKit

// Battery 2.0 dashboard surface (HorneroOS/plugins#31): the card
// form of the bar popover over the shared PluginKit Power facade.
// The card always renders when the user opens the dashboard --
// contextual hiding applies to the permanent bar item only -- and
// shows an explicit empty state when no battery is reported.
// See Main.qml for the documented PluginKit Power facade gaps.
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

    readonly property bool showPercentage: pluginSettings.value("showPercentage", true) !== false
    readonly property int lowBatteryPercent: {
        const value = Number(pluginSettings.value("lowBatteryPercent", 20));
        return isFinite(value) && value >= 5 ? Math.min(50, Math.floor(value)) : 20;
    }
    readonly property bool low: isLow(Power.hasBattery, Power.onBattery, Power.percentage, lowBatteryPercent)

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

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

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

    UiCard {
        id: card

        anchors.fill: parent
        title: i18n.tr("Battery")
        channel: 6
        context: root.low ? i18n.tr("Low") : Power.hasBattery ? root.stateLabel(Power.stateText) : ""
        Accessible.name: i18n.tr("Battery")

        Column {
            width: parent.width
            spacing: Theme.spacing.smaller

            UiState {
                visible: !Power.hasBattery
                width: parent.width
                kind: "unavailable"
                message: i18n.tr("No battery is reported by the Power service. The bar indicator stays hidden unless you enable 'show when no battery'.")
            }

            Column {
                visible: Power.hasBattery
                width: parent.width
                spacing: Theme.spacing.smaller

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
