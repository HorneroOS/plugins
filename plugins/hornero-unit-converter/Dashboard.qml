import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Unit Converter 2.0 dashboard surface: the optional detailed panel
// (compact card, Utilities category) with the full 1.x controls
// over the same pure LOGIC block as the bar quick action and the
// declared launcher entrypoint. PluginKit has no text-input,
// combo-box or spin-box primitive, so those remain QtQuick.Controls
// with accessible names and tooltips; buttons, text, cards and
// states use PluginKit Ui primitives and Theme tokens.
Item {
    id: root

    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: hostAvailableWidth > 0 ? Math.min(360, hostAvailableWidth) : 320
    implicitHeight: card.implicitHeight

    Translations { id: i18n; pluginId: "hornero-unit-converter" }
    Settings { id: pluginSettings; pluginId: "hornero-unit-converter" }

    readonly property string defaultCategory: String(pluginSettings.value("defaultCategory", "length"))
    readonly property int precision: { const v = Number(pluginSettings.value("precision", 6)); return isFinite(v) && v >= 0 && v <= 10 ? Math.floor(v) : 6; }
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
    property var categories: [
        { "name": "Length", "units": ["m", "km", "mi", "ft"] },
        { "name": "Mass", "units": ["kg", "lb"] },
        { "name": "Temperature", "units": ["C", "F", "K"] }
    ]
    property var units: categories[categoryBox.currentIndex].units
    function resultText() {
        var value = parseFloat(input.text);
        if (input.text.trim() === "" || !isFinite(value)) return i18n.tr("Enter a value");
        var result = convert(value, units[fromBox.currentIndex], units[toBox.currentIndex]);
        var factor = Math.pow(10, root.precision);
        var rounded = Math.round(result * factor) / factor;
        return value + " " + units[fromBox.currentIndex] + " = " + rounded + " " + units[toBox.currentIndex];
    }

    UiCard {
        id: card
        anchors.fill: parent
        Accessible.name: i18n.tr("Unit Converter")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Unit Converter") }

            ComboBox {
                id: categoryBox
                width: parent.width
                model: ["Length", "Mass", "Temperature"]
                currentIndex: root.defaultCategory === "mass" ? 1 : (root.defaultCategory === "temperature" ? 2 : 0)
                Accessible.name: i18n.tr("Conversion category")
                ToolTip.text: i18n.tr("Conversion category")
                ToolTip.visible: hovered
                onCurrentIndexChanged: { fromBox.currentIndex = 0; toBox.currentIndex = 1; }
            }
            TextField {
                id: input
                width: parent.width
                text: "1"
                placeholderText: i18n.tr("Value")
                Accessible.name: i18n.tr("Value to convert")
                ToolTip.text: i18n.tr("Value to convert")
                ToolTip.visible: hovered
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            Row {
                width: parent.width
                spacing: 8
                ComboBox { id: fromBox; width: (parent.width - parent.spacing) / 2; model: root.units; currentIndex: 0; Accessible.name: i18n.tr("From unit"); ToolTip.text: i18n.tr("From unit"); ToolTip.visible: hovered }
                ComboBox { id: toBox; width: (parent.width - parent.spacing) / 2; model: root.units; currentIndex: 1; Accessible.name: i18n.tr("To unit"); ToolTip.text: i18n.tr("To unit"); ToolTip.visible: hovered }
            }
            UiText { width: parent.width; Accessible.name: i18n.tr("Conversion result"); text: root.resultText() }
        }
    }
}
