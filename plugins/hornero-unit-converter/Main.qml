import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Unit Converter - dashboard card, pure-JS conversions.
// Length via metres, mass via kilograms, temperature via Celsius:
//   F = C * 9/5 + 32, K = C + 273.15, mi = km * 0.621371,
//   lb = kg * 2.20462 (via base-unit factors below).
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    property var categories: [
        { "name": "Length", "units": ["m", "km", "mi", "ft"] },
        { "name": "Mass", "units": ["kg", "lb"] },
        { "name": "Temperature", "units": ["C", "F", "K"] }
    ]
    property var units: categories[categoryBox.currentIndex].units

    function toBase(value, unit) {
        // Length -> m, mass -> kg, temperature -> C.
        if (unit === "km") return value * 1000;
        if (unit === "mi") return value * 1000 / 0.621371;
        if (unit === "ft") return value * 0.3048;
        if (unit === "lb") return value / 2.20462;
        if (unit === "F") return (value - 32) * 5 / 9;
        if (unit === "K") return value - 273.15;
        return value; // m, kg, C
    }

    function fromBase(base, unit) {
        if (unit === "km") return base / 1000;
        if (unit === "mi") return (base / 1000) * 0.621371;
        if (unit === "ft") return base / 0.3048;
        if (unit === "lb") return base * 2.20462;
        if (unit === "F") return base * 9 / 5 + 32;
        if (unit === "K") return base + 273.15;
        return base; // m, kg, C
    }

    function convert(value, fromUnit, toUnit) {
        return fromBase(toBase(value, fromUnit), toUnit);
    }

    function resultText() {
        var value = parseFloat(input.text);
        if (input.text.trim() === "" || !isFinite(value))
            return "Enter a value";
        var result = convert(value, units[fromBox.currentIndex], units[toBox.currentIndex]);
        var rounded = Math.round(result * 1000000) / 1000000;
        return value + " " + units[fromBox.currentIndex] + " = " + rounded + " " + units[toBox.currentIndex];
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            color: Theme.onSurface
            text: "Unit Converter"
            font.bold: true
            font.pixelSize: 14
        }

        ComboBox {
            id: categoryBox

            width: parent.width
            model: ["Length", "Mass", "Temperature"]
            Accessible.name: "Conversion category"
            onCurrentIndexChanged: { fromBox.currentIndex = 0; toBox.currentIndex = 1; }
        }

        TextField {
            id: input

            width: parent.width
            text: "1"
            placeholderText: "Value"
            Accessible.name: "Value to convert"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }

        Row {
            width: parent.width
            spacing: 8

            ComboBox {
                id: fromBox

                width: (parent.width - parent.spacing) / 2
                model: root.units
                currentIndex: 0
                Accessible.name: "From unit"
            }

            ComboBox {
                id: toBox

                width: (parent.width - parent.spacing) / 2
                model: root.units
                currentIndex: 1
                Accessible.name: "To unit"
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.onSurface
            font.pixelSize: 13
            Accessible.name: "Conversion result"
            text: root.resultText()
        }
    }
}
