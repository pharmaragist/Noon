import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
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
    readonly property var supported: ({
            "image": imageComponent,
            "video": videoComponent,
            "text": textComponent
        })
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
        sourceComponent: root.supported[(root.content?.type ?? "image")]
        readonly property string _text: Paths.methods.readFile(root.path)

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
            font: Fonts.request("main", 48)
            color: Colors.colOnLayer0
            anchors.fill: parent
            wrapMode: Text.Wrap
        }
    }
}
