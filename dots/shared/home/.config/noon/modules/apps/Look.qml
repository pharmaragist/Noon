import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import qs.data

FloatingWindow {
    id: root
    minimumSize: fittedSize
    maximumSize: fittedSize
    color: Colors.m3.m3surface
    title: "Preview"

    function dismiss() {
        root.destroy();
    }
    onVisibleChanged: if (!visible)
        root.destroy()

    property var content
    property string fileText: ""
    FileView {
        id: textFile
        path: String(root.path).replace(/^file:\/\//, "")
        onLoaded: root.fileText = textFile.text()
        onLoadFailed: root.fileText = "Cannot open file:\n" + root.content?.payload
    }
    readonly property var supported: ({
            "image": imageComponent,
            "video": videoComponent,
            "text": textComponent,
            "md": textComponent,
            "mmd": textComponent,
            "markdown": textComponent,
            "mermaid": textComponent
        })
    // ponytail: mermaid renders via scripts/preview_mermaid.sh manually;
    // auto-render Process removed — it crashed the shell. Upgrade path: re-add
    // guarded (running flag + onExited code check) once root cause is confirmed.
    readonly property string path: Qt.resolvedUrl(root.content?.payload ?? "")
    readonly property size fittedSize: {
        let w = root.content?.type === "video" ? 1280 : 900;
        let h = root.content?.type === "video" ? 720 : 700;
        if ((root.content?.type ?? "image") === "image" && probe.status === Image.Ready && probe.sourceSize.width > 0) {
            w = probe.sourceSize.width;
            h = probe.sourceSize.height;
        }
        const s = Math.min(1, (Screen.width * 0.85) / w, (Screen.height * 0.85) / h);
        return Qt.size(Math.round(Math.max(480, w * s)), Math.round(Math.max(360, h * s)));
    }

    Image {
        id: probe
        visible: false
        asynchronous: true
        cache: false
        source: (root.content?.type ?? "image") === "image" ? root.path : ""
    }

    StyledLoader {
        anchors.fill: parent
        sourceComponent: root.supported[(root.content?.type ?? "image")] ?? textComponent
        readonly property string _text: root.fileText

        binds: {
            "source": () => root.path,
            "text": () => _text
        }
    }

    Component {
        id: imageComponent

        StyledImage {
            anchors.fill: parent
        }
    }

    Component {
        id: videoComponent
        VideoPreview {
            id: player
            anchors.fill: parent
            autoPlay: true
            muted: false
        }
    }

    Component {
        id: textComponent
        StyledTextArea {
            font: Fonts.request("mono", 40)
            color: Colors.colOnLayer0
            readOnly: true
            anchors.fill: parent
            wrapMode: Text.Wrap
        }
    }
}
