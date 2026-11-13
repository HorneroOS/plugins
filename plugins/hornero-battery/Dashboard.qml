import QtQuick
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
        Accessible.name: i18n.tr("Battery")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiText {
                    role: "title"
                    text: i18n.tr("Battery")
                }

                UiChip {
                    visible: root.low
                    text: i18n.tr("Low")
                    tone: "error"
                }
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
                        value: root.showPercentage ? i18n.tr("%1%").arg(root.clampPercent(Power.percentage)) : root.stateLabel(Power.stateText) !== "" ? root.stateLabel(Power.stateText) : i18n.tr("Unknown")
                    }

                    UiMetric {
                        label: i18n.tr("State")
                        value: root.stateLabel(Power.stateText) !== "" ? root.stateLabel(Power.stateText) : i18n.tr("Unknown")
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
