import QtQuick
import "History.js" as History
import Hornero.PluginKit

// Command surface (PluginKit 4): pause or resume recording and clear the
// in-memory history from the launcher (`>do clipboard`), IPC
// (`qs ipc call plugincommands run hornero-clipboard clear`) or a key you
// bind yourself. Clear empties the very list the launcher searches
// (History.js is one shared module); pause and resume flip the same
// `recording` setting the Control Center shows, which stops or starts the
// wl-paste watcher in Launcher.qml.
Item {
    Translations {
        id: i18n

        pluginId: "hornero-clipboard"
    }

    Settings {
        id: pluginSettings

        pluginId: "hornero-clipboard"
    }

    function run(commandId: string, args: string): string {
        if (commandId === "clear") {
            History.clear();
            Notifications.toast(i18n.tr("Clipboard history"), i18n.tr("Cleared"), "clipboard");
            return "";
        }
        if (commandId === "pause" || commandId === "resume") {
            if (!pluginSettings.setValue("recording", commandId === "resume"))
                return "could not change the recording setting";
            Notifications.toast(i18n.tr("Clipboard history"), commandId === "resume" ? i18n.tr("Recording") : i18n.tr("Paused"), "clipboard");
            return "";
        }
        return "unknown command";
    }
}
