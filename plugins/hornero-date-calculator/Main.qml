import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Date Calculator 2.0 bar surface (primary): a one-button quick action.
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

    Translations { id: i18n; pluginId: "hornero-date-calculator" }
    Settings { id: pluginSettings; pluginId: "hornero-date-calculator" }

    readonly property bool showUtcNote: pluginSettings.value("showUtcNote", true) !== false

    // LOGIC-BEGIN
    function parseDate(t) {
        var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(t).trim());
        if (!m) return null;
        var y = Number(m[1]), mo = Number(m[2]), d = Number(m[3]);
        var dt = new Date(Date.UTC(y, mo - 1, d));
        if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== mo - 1 || dt.getUTCDate() !== d) return null;
        return dt;
    }
    function fmtDate(dt) {
        function p(v) { return v < 10 ? "0" + v : String(v); }
        return dt.getUTCFullYear() + "-" + p(dt.getUTCMonth() + 1) + "-" + p(dt.getUTCDate());
    }
    function daysBetweenText(aText, bText) {
        var a = parseDate(aText), b = parseDate(bText);
        if (!a || !b) return { "ok": false, "text": "", "error": "Enter real dates as YYYY-MM-DD (e.g. 2026-02-30 is rejected)." };
        var days = Math.round((b.getTime() - a.getTime()) / 86400000);
        return { "ok": true, "text": "Days between: " + days, "error": "" };
    }
    function addDaysText(baseText, daysText) {
        var a = parseDate(baseText);
        if (!a) return { "ok": false, "text": "", "error": "Enter a real base date as YYYY-MM-DD." };
        var s = String(daysText).trim();
        var n = Number(s);
        if (s === "" || !isFinite(n) || Math.floor(n) !== n) return { "ok": false, "text": "", "error": "Enter an integer number of days to add." };
        var dt = new Date(a.getTime() + n * 86400000);
        return { "ok": true, "text": "Resulting date: " + fmtDate(dt), "error": "" };
    }
    function quickResult(query) {
        var parts = String(query).trim().split(/\s+/);
        if (parts.length === 2 && parseDate(parts[0]) && parseDate(parts[1])) return daysBetweenText(parts[0], parts[1]);
        if (parts.length === 2) return addDaysText(parts[0], parts[1]);
        return { "ok": false, "text": "", "error": "Enter real dates as YYYY-MM-DD (e.g. 2026-02-30 is rejected)." };
    }
    // LOGIC-END

    function runQuick() {
        var outcome = quickResult(quickInput.text);
        root.quickText = outcome.ok ? outcome.text : (outcome.error && outcome.error !== "" ? outcome.error : outcome.text);
    }

    UiStack {
        id: stack
        orientation: root.hostOrientation
        compact: root.hostCompact

        UiButton {
            id: indicator
            variant: "ghost"
            text: "31"
            tooltipText: i18n.tr("Date Calculator: activate for a quick date calculation")
            accessibleName: i18n.tr("Date Calculator quick action")
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
        accessibleName: i18n.tr("Date Calculator quick action")

        Column {
            width: 300
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Date Calculator") }

            TextField {
                id: quickInput
                width: parent.width
                placeholderText: i18n.tr("2026-01-01 2026-02-01")
                Accessible.name: i18n.tr("Quick date calculation")
                ToolTip.text: i18n.tr("Quick date calculation")
                ToolTip.visible: hovered
                onAccepted: root.runQuick()
            }

            UiButton {
                text: i18n.tr("Calculate")
                tooltipText: i18n.tr("Calculate")
                accessibleName: i18n.tr("Calculate")
                onClicked: root.runQuick()
            }

            UiState {
                visible: root.quickText === ""
                width: parent.width
                kind: "empty"
                message: i18n.tr("Type two dates, or a date and days to add, and press Calculate.")
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
