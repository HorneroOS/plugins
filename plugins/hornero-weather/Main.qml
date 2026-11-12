import QtQuick
import Hornero.PluginKit

// Hornero Weather - dashboard card over PluginKit Weather.
Item {
    id: root

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    function forecastLine(entry) {
        if (!entry)
            return "";
        const parts = [];
        if (entry.date)
            parts.push(String(entry.date));
        if (entry.tempMin !== undefined && entry.tempMax !== undefined)
            parts.push(String(entry.tempMin) + " / " + String(entry.tempMax));
        else if (entry.temp !== undefined)
            parts.push(String(entry.temp));
        if (entry.description)
            parts.push(String(entry.description));
        return parts.join("  ");
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
            color: Theme.onSurface
            text: "Weather"
            font.bold: true
            font.pixelSize: 14
        }

        Text {
            visible: !Weather.locationConfigured
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.onSurfaceVariant
            text: "Weather location not configured. Set a location in the shell settings to see conditions here."
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

            Text { color: Theme.onSurface; font.pixelSize: 20; font.bold: true; text: Weather.temp }
            Text { color: Theme.onSurface; visible: Weather.description.length > 0; text: Weather.description }
            Text { color: Theme.onSurfaceVariant; text: "Humidity: " + Weather.humidity + "%" }
            Text { color: Theme.onSurfaceVariant; text: "Wind: " + Weather.windSpeed }
            Text { color: Theme.onSurfaceVariant; text: "Sunrise: " + Weather.sunrise + "  Sunset: " + Weather.sunset }

            Repeater {
                model: Weather.ready && Weather.forecast ? Math.min(3, Weather.forecast.length) : 0

                delegate: Text {
                    color: Theme.onSurfaceVariant
                    font.pixelSize: 11
                    text: root.forecastLine(Weather.forecast[index])
                }
            }
        }
    }
}
