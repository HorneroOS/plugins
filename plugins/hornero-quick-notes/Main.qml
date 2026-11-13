import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Quick Notes 2.0 - dashboard card with one PERSISTENT
// note. The note is stored through PluginKit Settings under the
// same declared string key ("note") and pluginId as 1.x, so an
// existing note is loaded unchanged on upgrade: no migration and
// no data move. Edits save debounced (600 ms in 1.x, now the
// typed autoSaveDelayMs setting with that same default), a
// pending edit is flushed synchronously on destruction (plugin
// disable/unload destroys the item), Ctrl+S saves immediately,
// and a failed Settings write is surfaced as an error chip
// instead of being silently dropped. Text is clamped to the
// 4096-character Settings limit before saving, exactly as 1.x,
// with the clamp announced. Clearing is a two-step confirm so a
// stray activation cannot erase the note. This is the persistent
// member of the notes family: for a never-saved session line see
// Hornero Quiet Notes; for a rotating reminder see Focus Card.
// PluginKit exposes no clipboard, file or multi-note store, so
// there is deliberately no export, history or second note.
Item {
    id: root

    // Host context (opt-in): defaults keep a dashboard card.
    property string hostOrientation: "horizontal"
    property string hostEdge: "none"
    property string hostSurface: "dashboard"
    property int hostAvailableWidth: 0
    property int hostAvailableHeight: 0
    property bool hostCompact: false
    property string hostScreenName: ""

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Save lifecycle: clean (stored), dirty (edit pending),
    // error (last Settings write was refused).
    property string saveState: "clean"
    property bool truncated: false
    property bool confirmingClear: false
    property bool loading: false

    Settings {
        id: pluginSettings

        pluginId: "hornero-quick-notes"
    }

    Translations {
        id: i18n

        pluginId: "hornero-quick-notes"
    }

    // Typed settings: defaults reproduce 1.x exactly (the same
    // "note" key, a 600 ms debounce, the character count shown).
    // Settings are read when the card loads and apply from the
    // next reload, as in the other 2.0 families.
    readonly property int autoSaveDelayMs: {
        const n = Math.round(Number(pluginSettings.value("autoSaveDelayMs", 600)));
        return isFinite(n) ? Math.max(200, Math.min(5000, n)) : 600;
    }
    readonly property bool showCounts: pluginSettings.value("showCounts", true) !== false

    // NOTE-LOGIC-BEGIN (pure JS: no QML types)
    function clampedNote(text, maxLen) {
        const value = text === undefined || text === null ? "" : String(text);
        return value.length > maxLen ? value.substring(0, maxLen) : value;
    }
    function noteTruncated(text, maxLen) {
        const value = text === undefined || text === null ? "" : String(text);
        return value.length > maxLen;
    }
    function wordCount(text) {
        const value = (text === undefined || text === null ? "" : String(text)).trim();
        return value === "" ? 0 : value.split(/\s+/).length;
    }
    // NOTE-LOGIC-END

    function saveNote() {
        saveTimer.stop();
        const raw = noteArea.text;
        root.truncated = root.noteTruncated(raw, 4096);
        const ok = pluginSettings.setValue("note", root.clampedNote(raw, 4096));
        root.saveState = ok === true ? "clean" : "error";
    }

    function markDirty() {
        if (root.loading)
            return;
        root.confirmingClear = false;
        root.saveState = "dirty";
        root.truncated = root.noteTruncated(noteArea.text, 4096);
        saveTimer.restart();
    }

    Component.onCompleted: {
        root.loading = true;
        const stored = pluginSettings.value("note", "");
        noteArea.text = stored ? String(stored) : "";
        root.loading = false;
        root.saveState = "clean";
        root.truncated = false;
    }

    // Disable/unload destroys this item; flush a pending edit so
    // the debounce window can never eat the last keystrokes.
    Component.onDestruction: {
        if (root.saveState === "dirty" || root.saveState === "error")
            root.saveNote();
    }

    Timer {
        id: saveTimer

        interval: root.autoSaveDelayMs
        repeat: false
        onTriggered: root.saveNote()
    }

    UiCard {
        id: card

        anchors.centerIn: parent
        width: root.hostAvailableWidth > 0 ? Math.min(root.hostAvailableWidth, 340) : 340

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Quick Notes")
            }

            UiChip {
                text: i18n.tr("Persistent — saved and restored")
                tone: "primary"
            }

            TextArea {
                id: noteArea

                width: parent.width
                height: 110
                placeholderText: i18n.tr("Write a note...")
                wrapMode: TextArea.Wrap
                color: Theme.onSurface
                Accessible.name: i18n.tr("Quick note")
                ToolTip.text: i18n.tr("Quick note (saved automatically; Ctrl+S saves now)")
                ToolTip.visible: hovered
                onTextChanged: root.markDirty()
                Keys.onPressed: (event) => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                        root.saveNote();
                        event.accepted = true;
                    }
                }
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    text: i18n.tr("Save now")
                    tooltipText: i18n.tr("Save the note now (Ctrl+S in the editor)")
                    accessibleName: i18n.tr("Save note now")
                    enabled: root.saveState !== "clean"
                    onClicked: root.saveNote()
                }

                UiButton {
                    visible: !root.confirmingClear
                    variant: "ghost"
                    text: i18n.tr("Clear")
                    tooltipText: i18n.tr("Clear the note (asks for confirmation first)")
                    accessibleName: i18n.tr("Clear note")
                    enabled: noteArea.text.length > 0
                    onClicked: root.confirmingClear = true
                }

                UiButton {
                    visible: root.confirmingClear
                    text: i18n.tr("Confirm clear")
                    tooltipText: i18n.tr("Erase the stored note permanently")
                    accessibleName: i18n.tr("Confirm clear note")
                    onClicked: {
                        root.confirmingClear = false;
                        noteArea.text = "";
                        root.saveNote();
                        noteArea.forceActiveFocus();
                    }
                }

                UiButton {
                    visible: root.confirmingClear
                    variant: "ghost"
                    text: i18n.tr("Cancel")
                    tooltipText: i18n.tr("Keep the note")
                    accessibleName: i18n.tr("Cancel clear")
                    onClicked: root.confirmingClear = false
                }
            }

            UiChip {
                visible: root.saveState !== "clean"
                text: root.saveState === "error" ? i18n.tr("Save failed — edit or press Save now to retry") : i18n.tr("Unsaved changes")
                tone: root.saveState === "error" ? "error" : "neutral"
            }

            UiText {
                visible: root.confirmingClear
                role: "caption"
                width: parent.width
                text: i18n.tr("Clearing erases the stored note. This cannot be undone.")
            }

            UiText {
                visible: root.truncated
                role: "caption"
                width: parent.width
                text: i18n.tr("Note truncated to %1 characters; only the first %1 are saved.").arg(i18n.formatNumber(4096))
            }

            UiText {
                visible: root.showCounts
                role: "caption"
                Accessible.name: i18n.tr("Character count %1 of %2").arg(i18n.formatNumber(noteArea.text.length)).arg(i18n.formatNumber(4096))
                text: i18n.tr("%1 / %2 characters · %3 words").arg(i18n.formatNumber(noteArea.text.length)).arg(i18n.formatNumber(4096)).arg(i18n.formatNumber(root.wordCount(noteArea.text)))
            }

            UiText {
                role: "caption"
                width: parent.width
                text: i18n.tr("Saved automatically via Settings; restored when this extension loads again. Disabling flushes any pending edit and keeps the stored note.")
            }
        }
    }
}
