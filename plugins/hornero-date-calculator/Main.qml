import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Date Calculator - UTC math only to avoid DST drift.
Item {
    id: root
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 24
    property string errorText: ""
    property string resultText: ""
    function parseDate(t) {
        var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(t.trim());
        if (!m) return null;
        var y = Number(m[1]), mo = Number(m[2]), d = Number(m[3]);
        var dt = new Date(Date.UTC(y, mo-1, d));
        if (dt.getUTCFullYear()!==y || dt.getUTCMonth()!==mo-1 || dt.getUTCDate()!==d) return null;
        return dt;
    }
    function fmt(dt) {
        function p(v){ return v<10 ? "0"+v : String(v); }
        return dt.getUTCFullYear() + "-" + p(dt.getUTCMonth()+1) + "-" + p(dt.getUTCDate());
    }
    function daysBetween() {
        var a = root.parseDate(startInput.text), b = root.parseDate(endInput.text);
        if (!a || !b) { root.errorText="Enter real dates as YYYY-MM-DD (e.g. 2026-02-30 is rejected)."; root.resultText=""; return; }
        root.errorText="";
        var days = Math.round((b.getTime() - a.getTime()) / 86400000);
        root.resultText = "Days between: " + days;
    }
    function addDays() {
        var a = root.parseDate(baseInput.text);
        var n = Number(daysInput.text.trim());
        if (!a) { root.errorText="Enter a real base date as YYYY-MM-DD."; root.resultText=""; return; }
        if (daysInput.text.trim()==="" || !isFinite(n) || Math.floor(n)!==n) { root.errorText="Enter an integer number of days to add."; root.resultText=""; return; }
        root.errorText="";
        var dt = new Date(a.getTime() + n * 86400000);
        root.resultText = "Resulting date: " + root.fmt(dt);
    }
    Column {
        id: content
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        Text { color: Theme.onSurface; text: "Date Calculator"; font.bold: true; font.pixelSize: 14 }
        Text { width: parent.width; wrapMode: Text.Wrap; color: Theme.onSurfaceVariant; font.pixelSize: 11; text: "All math uses UTC to avoid DST drift." }
        TextField { id: startInput; width: parent.width; placeholderText: "Start YYYY-MM-DD"; Accessible.name: "Start date"; ToolTip.text: "Start date YYYY-MM-DD"; ToolTip.visible: hovered }
        TextField { id: endInput; width: parent.width; placeholderText: "End YYYY-MM-DD"; Accessible.name: "End date"; ToolTip.text: "End date YYYY-MM-DD"; ToolTip.visible: hovered }
        Button { text: "Days between"; Accessible.name: "Calculate days between"; ToolTip.text: "Days between start and end dates (UTC)"; ToolTip.visible: hovered; onClicked: root.daysBetween() }
        TextField { id: baseInput; width: parent.width; placeholderText: "Base YYYY-MM-DD"; Accessible.name: "Base date"; ToolTip.text: "Base date YYYY-MM-DD"; ToolTip.visible: hovered }
        TextField { id: daysInput; width: parent.width; placeholderText: "Days to add (integer)"; Accessible.name: "Days to add"; ToolTip.text: "Integer days to add, may be negative"; ToolTip.visible: hovered }
        Button { text: "Add days"; Accessible.name: "Add days to base date"; ToolTip.text: "Add days to base date (UTC)"; ToolTip.visible: hovered; onClicked: root.addDays() }
        Text { visible: root.errorText!==""; width: parent.width; wrapMode: Text.Wrap; color: Theme.error; font.pixelSize: 12; Accessible.name: "Date error"; text: root.errorText }
        Text { visible: root.resultText!==""; width: parent.width; wrapMode: Text.Wrap; color: Theme.onSurface; font.pixelSize: 13; Accessible.name: "Date result"; text: root.resultText }
    }
}
