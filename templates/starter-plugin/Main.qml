import QtQuick
import Hornero.PluginKit

// Starter plugin (PluginKit 3, Hornero Signal): shows HH:mm in the bar.
// Colours, type and spacing come from Theme tokens, never literals.
Item {
    implicitWidth: label.implicitWidth + Theme.spacing.small * 2
    implicitHeight: label.implicitHeight

    Subscription { domain: "time" }

    UiText {
        id: label

        anchors.centerIn: parent
        role: "value"
        text: Time.format("HH:mm")
    }
}
