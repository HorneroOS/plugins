import QtQuick
import Hornero.PluginKit

// Hornero Sun Card - dashboard card over PluginKit Weather
// (sunrise, sunset, temp, description, humidity).
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text { color: Theme.onSurface; text: "Sun Card"; font.bold: true; font.pixelSize: 14 }

        Text {
            visible: !Weather.locationConfigured
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.onSurfaceVariant
            Accessible.name: "Weather location not configured"
            text: "Weather location not configured. Set a location in the shell settings to see sunrise and sunset here."
        }
        Text {
            visible: Weather.locationConfigured && Weather.lastError.length > 0 && !Weather.ready
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.error
            text: "Weather unavailable: " + Weather.lastError
        }
        Text {
            visible: Weather.locationConfigured && Weather.lastError.length === 0 && !Weather.ready
            color: Theme.onSurfaceVariant
            text: "Loading weather..."
        }

        Column {
            visible: Weather.ready
            width: parent.width
            spacing: 4

            Text { color: Theme.onSurface; font.pixelSize: 20; font.bold: true; Accessible.name: "Temperature " + Weather.temp; text: Weather.temp }
            Text { color: Theme.onSurface; visible: Weather.description.length > 0; Accessible.name: "Conditions " + Weather.description; text: Weather.description }
            Text { color: Theme.onSurfaceVariant; Accessible.name: "Sunrise " + Weather.sunrise; text: "Sunrise: " + Weather.sunrise }
            Text { color: Theme.onSurfaceVariant; Accessible.name: "Sunset " + Weather.sunset; text: "Sunset: " + Weather.sunset }
            Text { color: Theme.onSurfaceVariant; Accessible.name: "Humidity " + Weather.humidity + " percent"; text: "Humidity: " + Weather.humidity + "%" }
        }
    }
}
