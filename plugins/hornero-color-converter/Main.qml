import QtQuick
import QtQuick.Controls
import Hornero.PluginKit

// Hornero Color Converter - hex <-> RGB <-> HSL, pure JS.
Item {
    id: root
    implicitWidth: 320
    implicitHeight: content.implicitHeight + 24
    property string errorText: ""
    property var rgb: null
    function parseHex(t) {
        var m = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/.exec(t.trim());
        if (!m) return null;
        var h = m[1];
        if (h.length===3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2];
        return { "r": parseInt(h.substring(0,2),16), "g": parseInt(h.substring(2,4),16), "b": parseInt(h.substring(4,6),16) };
    }
    function toHex(r,g,b) {
        function h(v){ var s=v.toString(16).toUpperCase(); return s.length===1?"0"+s:s; }
        return "#" + h(r) + h(g) + h(b);
    }
    function toHsl(r,g,b) {
        var rn=r/255, gn=g/255, bn=b/255;
        var mx=Math.max(rn,gn,bn), mn=Math.min(rn,gn,bn), l=(mx+mn)/2, d=mx-mn;
        var h=0, s=0;
        if (d!==0) { s = l>0.5 ? d/(2-mx-mn) : d/(mx+mn);
            if (mx===rn) h=(gn-bn)/d + (gn<bn?6:0); else if (mx===gn) h=(bn-rn)/d+2; else h=(rn-gn)/d+4; h*=60; }
        return { "h": Math.round(h), "s": Math.round(s*100), "l": Math.round(l*100) };
    }
    function applyHex() {
        var c = root.parseHex(hexInput.text);
        if (!c) { root.rgb=null; root.errorText="Invalid hex: use #RGB or #RRGGBB with hex digits."; return; }
        root.errorText=""; root.rgb=c; rSpin.value=c.r; gSpin.value=c.g; bSpin.value=c.b;
    }
    function applyRgb() {
        root.rgb={ "r": rSpin.value, "g": gSpin.value, "b": bSpin.value }; root.errorText="";
        hexInput.text = root.toHex(rSpin.value,gSpin.value,bSpin.value);
    }
    Column {
        id: content
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        Text { color: Theme.onSurface; text: "Color Converter"; font.bold: true; font.pixelSize: 14 }
        TextField {
            id: hexInput; width: parent.width; text: "#336699"; placeholderText: "#RGB or #RRGGBB"
            Accessible.name: "Hex color input"
            ToolTip.text: "Hex color, #RGB or #RRGGBB"; ToolTip.visible: hovered
            onAccepted: root.applyHex()
        }
        Button {
            text: "Convert hex"; Accessible.name: "Convert hex color"
            ToolTip.text: "Convert hex to RGB and HSL"; ToolTip.visible: hovered
            onClicked: root.applyHex()
        }
        Rectangle {
            width: parent.width; height: 36; radius: 6
            color: root.rgb ? root.toHex(root.rgb.r,root.rgb.g,root.rgb.b) : "transparent"
            border.color: Theme.outline; visible: root.rgb!==null
            Accessible.name: "Color preview"
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; color: Theme.onSurface; font.pixelSize: 13
            Accessible.name: "RGB and HSL output"
            text: root.rgb ? ("RGB: " + root.rgb.r + ", " + root.rgb.g + ", " + root.rgb.b + "\nHSL: " + root.toHsl(root.rgb.r,root.rgb.g,root.rgb.b).h + ", " + root.toHsl(root.rgb.r,root.rgb.g,root.rgb.b).s + "%, " + root.toHsl(root.rgb.r,root.rgb.g,root.rgb.b).l + "%") : "No valid color yet"
        }
        Text {
            visible: root.errorText!==""; width: parent.width; wrapMode: Text.Wrap
            color: Theme.error; font.pixelSize: 12; Accessible.name: "Color error"; text: root.errorText
        }
        Row {
            spacing: 6
            SpinBox { id: rSpin; from: 0; to: 255; value: 51; editable: true; Accessible.name: "Red value"; ToolTip.text: "Red 0-255"; ToolTip.visible: hovered; onValueModified: root.applyRgb() }
            SpinBox { id: gSpin; from: 0; to: 255; value: 102; editable: true; Accessible.name: "Green value"; ToolTip.text: "Green 0-255"; ToolTip.visible: hovered; onValueModified: root.applyRgb() }
            SpinBox { id: bSpin; from: 0; to: 255; value: 153; editable: true; Accessible.name: "Blue value"; ToolTip.text: "Blue 0-255"; ToolTip.visible: hovered; onValueModified: root.applyRgb() }
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; color: Theme.onSurfaceVariant; font.pixelSize: 12
            Accessible.name: "Hex from RGB output"
            text: "Hex from RGB: " + root.toHex(rSpin.value, gSpin.value, bSpin.value)
        }
        Component.onCompleted: root.applyHex()
    }
}
