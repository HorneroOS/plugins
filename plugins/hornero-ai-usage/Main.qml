import QtQuick
import Quickshell.Io
import Hornero.PluginKit

// Hornero AI Usage - dashboard card reading the typed contract
// `horneroctl assistant usage --json` every 60 seconds. Read-only.
// The provider does not expose a quota/limit, so quota is reported
// as unknown rather than invented. Failures show an error state,
// never fabricated zeros.
Item {
    id: root

    property bool hasData: false
    property string errorText: ""
    property int sessions: 0
    property int apiCalls: 0
    property int inputTokens: 0
    property int outputTokens: 0
    property int totalTokens: 0
    property string modelsText: ""
    property string buffer: ""

    implicitWidth: 300
    implicitHeight: content.implicitHeight + 24

    function refresh(): void {
        if (!usageProc.running) {
            root.buffer = "";
            usageProc.running = true;
        }
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Process {
        id: usageProc

        command: ["horneroctl", "assistant", "usage", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }
        onExited: exitCode => {
            try {
                const parsed = JSON.parse(root.buffer.trim());
                const data = (parsed && parsed.data) || parsed || {};
                if (parsed && parsed.ok === false)
                    throw new Error("horneroctl reported failure");
                root.sessions = Number(data.sessions || 0);
                root.apiCalls = Number(data.apiCalls || 0);
                root.inputTokens = Number(data.inputTokens || 0);
                root.outputTokens = Number(data.outputTokens || 0);
                root.totalTokens = Number(data.totalTokens || (root.inputTokens + root.outputTokens));
                let models = data.models || [];
                if (!Array.isArray(models))
                    models = Object.keys(models);
                root.modelsText = models.map(m => (typeof m === "string" ? m : String(m.name || m.id || ""))).filter(s => s.length > 0).join(", ");
                root.hasData = true;
                root.errorText = "";
            } catch (e) {
                root.hasData = false;
                root.errorText = "AI usage unavailable: horneroctl assistant usage returned no usable data.";
            }
        }
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Text {
            color: Theme.onSurface
            text: "AI Usage"
            font.bold: true
            font.pixelSize: 14
        }

        Text {
            visible: !root.hasData
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.error
            text: root.errorText.length > 0 ? root.errorText : "Loading AI usage..."
        }

        Column {
            visible: root.hasData
            width: parent.width
            spacing: 4

            Text { color: Theme.onSurface; text: "Sessions: " + root.sessions }
            Text { color: Theme.onSurface; text: "API calls: " + root.apiCalls }
            Text { color: Theme.onSurface; text: "Input tokens: " + root.inputTokens }
            Text { color: Theme.onSurface; text: "Output tokens: " + root.outputTokens }
            Text { color: Theme.onSurface; text: "Total tokens: " + root.totalTokens }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.onSurfaceVariant
                visible: root.modelsText.length > 0
                text: "Models: " + root.modelsText
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.onSurfaceVariant
                text: "Quota: unknown - the provider does not expose a limit."
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.refresh()
    }
}
