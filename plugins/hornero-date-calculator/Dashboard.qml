import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Date Calculator 2.0 dashboard surface: the optional detailed panel
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
    property string errorText: ""
    property string resultText: ""
    function showOutcome(o) { root.errorText = o.error; root.resultText = o.text; }
    function daysBetween() { root.showOutcome(daysBetweenText(startInput.text, endInput.text)); }
    function addDays() { root.showOutcome(addDaysText(baseInput.text, daysInput.text)); }

    UiCard {
        id: card
        anchors.fill: parent
        Accessible.name: i18n.tr("Date Calculator")

        Column {
            width: parent.width
            spacing: Theme.spacingSmall

            UiText { role: "title"; text: i18n.tr("Date Calculator") }

            UiText { visible: root.showUtcNote; width: parent.width; role: "caption"; text: i18n.tr("All math uses UTC to avoid DST drift.") }
            TextField { id: startInput; width: parent.width; placeholderText: "Start YYYY-MM-DD"; Accessible.name: i18n.tr("Start date"); ToolTip.text: i18n.tr("Start date YYYY-MM-DD"); ToolTip.visible: hovered }
            TextField { id: endInput; width: parent.width; placeholderText: "End YYYY-MM-DD"; Accessible.name: i18n.tr("End date"); ToolTip.text: i18n.tr("End date YYYY-MM-DD"); ToolTip.visible: hovered }
            UiButton { text: i18n.tr("Days between"); accessibleName: i18n.tr("Calculate days between"); tooltipText: i18n.tr("Days between start and end dates (UTC)"); onClicked: root.daysBetween() }
            TextField { id: baseInput; width: parent.width; placeholderText: "Base YYYY-MM-DD"; Accessible.name: i18n.tr("Base date"); ToolTip.text: i18n.tr("Base date YYYY-MM-DD"); ToolTip.visible: hovered }
            TextField { id: daysInput; width: parent.width; placeholderText: i18n.tr("Days to add (integer)"); Accessible.name: i18n.tr("Days to add"); ToolTip.text: i18n.tr("Integer days to add, may be negative"); ToolTip.visible: hovered }
            UiButton { variant: "ghost"; text: i18n.tr("Add days"); accessibleName: i18n.tr("Add days to base date"); tooltipText: i18n.tr("Add days to base date (UTC)"); onClicked: root.addDays() }
            UiState { visible: root.errorText !== ""; width: parent.width; kind: "error"; message: root.errorText }
            UiText { visible: root.resultText !== ""; width: parent.width; Accessible.name: i18n.tr("Date result"); text: root.resultText }
        }
    }
}
