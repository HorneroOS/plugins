import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Unit Converter 2.0 bar surface (primary): a one-button quick action.
// The button opens a host-owned UiPopover with one quick-query field
// and the same pure logic as the dashboard detail panel; the full
// controls stay there. This is the launcher-style quick action that
// is hosted today. The declared launcher surface (Launcher.qml) is
// a validated declaration only until the shell launcher provider
// host (HorneroOS/shell#250) exists; no parallel launcher and no
// invented PluginKit launcher member is used here. PluginKit has
// no text-input primitive, so the query field is a QtQuick.Controls
// TextField with an accessible name and tooltip.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "top"
    property string hostSurface: "bar"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    property string quickText: ""

    Translations { id: i18n; pluginId: "hornero-unit-converter" }
    Settings { id: pluginSettings; pluginId: "hornero-unit-converter" }

    readonly property int precision: { const v = Number(pluginSettings.value("precision", 6)); return isFinite(v) && v >= 0 && v <= 10 ? Math.floor(v) : 6; }
    readonly property string defaultCategory: String(pluginSettings.value("defaultCategory", "length"))

    // LOGIC-BEGIN
    function toBase(value, unit) {
        if (unit === "km") return value * 1000;
        if (unit === "mi") return value * 1000 / 0.621371;
        if (unit === "ft") return value * 0.3048;
        if (unit === "lb") return value / 2.20462;
        if (unit === "F") return (value - 32) * 5 / 9;
        if (unit === "K") return value - 273.15;
        return value;
    }
    function fromBase(base, unit) {
        if (unit === "km") return base / 1000;
        if (unit === "mi") return (base / 1000) * 0.621371;
        if (unit === "ft") return base / 0.3048;
        if (unit === "lb") return base * 2.20462;
        if (unit === "F") return base * 9 / 5 + 32;
        if (unit === "K") return base + 273.15;
        return base;
    }
    function convert(value, fromUnit, toUnit) { return fromBase(toBase(value, fromUnit), toUnit); }
    function unitCategory(unit) {
        if (unit === "m" || unit === "km" || unit === "mi" || unit === "ft") return "length";
        if (unit === "kg" || unit === "lb") return "mass";
        if (unit === "C" || unit === "F" || unit === "K") return "temperature";
        return "";
    }
    function normalizeUnit(unit) {
        var u = String(unit);
        var lower = u.toLowerCase();
        if (lower === "c" || lower === "f" || lower === "k") return lower.toUpperCase();
        return lower;
    }
    function quickResult(query, precision) {
        var p = (precision === undefined || precision === null) ? 6 : precision;
        var m = /^\s*(-?\d+(?:\.\d+)?)\s*([A-Za-z]+)\s+(?:to\s+)?([A-Za-z]+)\s*$/.exec(String(query));
        if (!m) return { "ok": false, "text": "Enter a value" };
        var value = parseFloat(m[1]);
        var fromUnit = normalizeUnit(m[2]);
        var toUnit = normalizeUnit(m[3]);
        if (!isFinite(value) || unitCategory(fromUnit) === "" || unitCategory(fromUnit) !== unitCategory(toUnit))
            return { "ok": false, "text": "Enter a value" };
        var result = convert(value, fromUnit, toUnit);
        var factor = Math.pow(10, p);
        var rounded = Math.round(result * factor) / factor;
        return { "ok": true, "text": value + " " + fromUnit + " = " + rounded + " " + toUnit };
    }
    // LOGIC-END

    function runQuick() {
        var outcome = quickResult(quickInput.text, root.precision);
        root.quickText = outcome.ok ? outcome.text : (outcome.error && outcome.error !== "" ? outcome.error : outcome.text);
    }

    UiStack {
        id: stack
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator
            variant: "ghost"
            text: "⇄"
            tooltipText: i18n.tr("Unit Converter: activate for a quick conversion")
            accessibleName: i18n.tr("Unit Converter quick action")
            onClicked: popover.toggle()
        }

        UiText {
            visible: !root.hostCompact && root.hostOrientation !== "vertical" && root.quickText !== ""
            width: 140
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            text: root.quickText
        }
    }

    UiPopover {
        id: popover
        target: indicator
        accessibleName: i18n.tr("Unit Converter quick action")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Unit Converter") }

            TextField {
                id: quickInput
                width: parent.width
                placeholderText: i18n.tr("e.g. 10 km to mi")
                Accessible.name: i18n.tr("Quick unit conversion")
                ToolTip.text: i18n.tr("Quick unit conversion")
                ToolTip.visible: hovered
                onAccepted: root.runQuick()
            }

            UiButton {
                text: i18n.tr("Convert")
                tooltipText: i18n.tr("Convert")
                accessibleName: i18n.tr("Convert")
                onClicked: root.runQuick()
            }

            UiState {
                visible: root.quickText === ""
                width: parent.width
                kind: "empty"
                message: i18n.tr("Type a conversion like 10 km to mi and press Convert.")
            }

            UiText {
                visible: root.quickText !== ""
                width: parent.width
                text: root.quickText
            }

            UiText {
                width: parent.width
                role: "caption"
                text: i18n.tr("Full controls are in the dashboard Utilities panel.")
            }
        }
    }
}
