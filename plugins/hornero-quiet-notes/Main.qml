import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Quiet Notes 2.0 - dashboard card for one short
// intention for THIS SESSION. The intention itself remains
// in-memory only, exactly as 1.x: it is never written through
// Settings, to a file, or anywhere else, and closing or
// restarting the shell - or disabling this extension - erases
// it. That deliberate ephemerality is now labelled on the card
// ("Session only - never saved") so it cannot be confused with
// Hornero Quick Notes, the persistent member of the family.
// The only Settings keys here are display preferences
// (maxLength, showCounter) whose defaults reproduce 1.x (140
// characters, counter hint shown); preferences persist in the
// shell settings store, the intention never does. Editing was
// mouse-only in 1.x (a card-wide MouseArea with hard-coded
// editor colours); 2.0 uses UiButton tab stops, a themed
// TextField, Enter to accept and Escape to cancel, so capture
// is keyboard-first. PluginKit offers no "warn before the shell
// exits" hook, so there is no exit prompt to add: the session-
// only label is the contract, stated up front.
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

    // Session-only intention. Deliberately a plain QML property:
    // no Settings key holds it, by design.
    property string note: ""
    property bool editing: false

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Settings {
        id: pluginSettings

        pluginId: "hornero-quiet-notes"
    }

    Translations {
        id: i18n

        pluginId: "hornero-quiet-notes"
    }

    // Typed preference settings: defaults reproduce 1.x (140
    // characters, the counter/session hint shown). 1.x stored
    // nothing, so no stored values migrate; the intention is
    // not a setting now either. Read at load, apply from the
    // next reload, as in the other 2.0 families.
    readonly property int maxLength: {
        const n = Math.round(Number(pluginSettings.value("maxLength", 140)));
        return isFinite(n) ? Math.max(20, Math.min(500, n)) : 140;
    }
    readonly property bool showCounter: pluginSettings.value("showCounter", true) !== false

    // INTENTION-LOGIC-BEGIN (pure JS: no QML types)
    function normalizeIntention(text, maxLen) {
        const oneLine = (text === undefined || text === null ? "" : String(text)).replace(/\s+/g, " ").trim();
        return oneLine.length > maxLen ? oneLine.substring(0, maxLen) : oneLine;
    }
    function remainingChars(text, maxLen) {
        const value = text === undefined || text === null ? "" : String(text);
        return Math.max(0, maxLen - value.length);
    }
    // INTENTION-LOGIC-END

    function openEditor() {
        input.text = root.note;
        root.editing = true;
        input.forceActiveFocus();
        input.selectAll();
    }

    function closeEditor(save) {
        if (save)
            root.note = root.normalizeIntention(input.text, root.maxLength);
        root.editing = false;
        editButton.forceActiveFocus();
    }

    UiCard {
        id: card

        anchors.centerIn: parent
        width: root.hostAvailableWidth > 0 ? Math.min(root.hostAvailableWidth, 320) : 320
        Accessible.name: root.note.length > 0 ? i18n.tr("Session intention: %1").arg(root.note) : i18n.tr("Session intention: not set")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText {
                role: "title"
                text: i18n.tr("Session intention")
            }

            UiChip {
                text: i18n.tr("Session only — never saved")
                tone: "primary"
            }

            UiText {
                visible: !root.editing
                role: "body"
                width: parent.width
                text: root.note.length > 0 ? root.note : i18n.tr("Write one line for this session. It is never saved.")
            }

            TextField {
                id: input

                visible: root.editing
                width: parent.width
                maximumLength: root.maxLength
                placeholderText: i18n.tr("One line for this session...")
                color: Theme.onSurface
                Accessible.name: i18n.tr("Session intention editor")
                ToolTip.text: i18n.tr("Session intention (Enter accepts, Esc cancels; never saved)")
                ToolTip.visible: hovered
                onAccepted: root.closeEditor(true)
                Keys.onEscapePressed: root.closeEditor(false)
            }

            UiText {
                visible: root.editing && root.showCounter
                role: "caption"
                text: i18n.tr("%1 characters left · Enter accepts · Esc cancels").arg(i18n.formatNumber(root.remainingChars(input.text, root.maxLength)))
            }

            UiStack {
                orientation: root.hostOrientation
                compact: root.hostCompact

                UiButton {
                    id: editButton

                    visible: !root.editing
                    text: root.note.length > 0 ? i18n.tr("Edit intention") : i18n.tr("Set intention")
                    tooltipText: i18n.tr("Write one line for this session (never saved)")
                    accessibleName: root.note.length > 0 ? i18n.tr("Edit session intention") : i18n.tr("Set session intention")
                    onClicked: root.openEditor()
                }

                UiButton {
                    visible: !root.editing && root.note.length > 0
                    variant: "ghost"
                    text: i18n.tr("Clear")
                    tooltipText: i18n.tr("Erase this session intention")
                    accessibleName: i18n.tr("Clear session intention")
                    onClicked: root.note = ""
                }

                UiButton {
                    visible: root.editing
                    text: i18n.tr("Accept")
                    tooltipText: i18n.tr("Keep this line for this session (Enter)")
                    accessibleName: i18n.tr("Accept session intention")
                    onClicked: root.closeEditor(true)
                }

                UiButton {
                    visible: root.editing
                    variant: "ghost"
                    text: i18n.tr("Cancel")
                    tooltipText: i18n.tr("Discard this edit (Esc)")
                    accessibleName: i18n.tr("Cancel editing")
                    onClicked: root.closeEditor(false)
                }
            }

            UiText {
                role: "caption"
                width: parent.width
                text: i18n.tr("Closing the shell or disabling this extension erases this line. For a note that is saved, use Quick Notes.")
            }
        }
    }
}
