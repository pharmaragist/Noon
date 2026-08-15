import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.common
import qs.common.widgets

StyledRect {
    id: root
    property var post: null
    property string author: {
        const match = /\/u\/([A-Za-z0-9_\-]+)/.exec(root.post?.content ?? "");
        return match ? match[1] : "";
    }
    anchors.right: parent?.right
    anchors.left: parent?.left
    implicitHeight: content.implicitHeight + (post.image.length > 0 ? 200 : Padding.massive)
    clip: true
    color: Colors.colLayer2
    radius: Rounding.veryhuge

    StyledImage {
        z: 0
        anchors.fill: parent
        source: root.post?.image ?? ""
        asynchronous: true
    }

    Rectangle {
        z: 1
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 0.75
                color: Colors.colLayer2
            }
            GradientStop {
                position: 1.0
                color: Colors.colLayer2
            }
        }
    }

    ColumnLayout {
        id: content
        z: 999
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        anchors.margins: Padding.large
        spacing: Padding.large

        StyledText {
            Layout.fillWidth: true
            text: root.post?.title ?? ""
            color: Colors.colOnLayer3
            font: Fonts.request("title", "verylarge")
            truncate: true
        }
        StyledText {
            text: root.post?.content ?? ""
            wrapMode: Text.WordWrap
            font: Fonts.request("reading", "large")
            color: Colors.colSubtext
            Layout.fillWidth: true
            Layout.fillHeight: true
            truncate: true
            maximumLineCount: root.post?.image.length > 0 ? 2 : 25
        }
        
        
        
        
        
        
        
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.post?.link)
                NoonUtils.open(root.post.link);
        }
    }
}
