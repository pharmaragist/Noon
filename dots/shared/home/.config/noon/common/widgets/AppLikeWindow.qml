import QtQuick
import QtQuick.Layouts
import qs.common

StyledRect {
    id: root
    z: 99

    property Item contentItem: null
    property bool showTitleBar: title.length > 0
    property bool draggable: false
    property bool center: false
    property string title: ""
    property string icon: ""
    property int padding: Padding.silly

    readonly property alias dragHandler: dragHandler

    radius: Rounding.silly
    color: Colors.colSurfaceContainer
    enableBorders: true
    width: 400
    height: 400
    clip: true

    x: center ? (parent.width - root.width) / 2 : 0
    y: center ? (parent.height - root.height) / 2 : 0

    Rectangle {
        id: topBorder
        visible: root.showTitleBar
        anchors.left: parent.left
        anchors.right: parent.right
        height: 55
        color: Colors.colLayer3

        RLayout {
            anchors.right: parent.right
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Padding.massive * 1.25

            spacing: Padding.huge
            Symbol {
                color: Colors.colOnLayer3
                iconSize: 22
                icon: root.icon
                fill: dragHandler.drag.active ? 1 : 0
            }
            StyledText {
                color: Colors.colOnLayer3
                font: Fonts.request("title", "large")
                text: root.title
                Layout.fillWidth: true
            }
            Symbol {
                icon: "drag_indicator"
                iconSize: 22
                opacity: 0.6
                color: Colors.colSubtext

                DragInteraction {
                    id: dragHandler
                    enabled: root.draggable
                    drag.target: root
                }
            }
        }
    }

    Anim on scale {
        from: 0.96
        to: 1
    }
    Anim on opacity {
        from: 0
        to: 1
    }

    Item {
        id: container
        anchors.top: topBorder?.bottom ?? parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        Item {
            id: incubator
            anchors.fill: parent
            children: root.contentItem

            Component.onCompleted: if (root.contentItem) {
                contentItem.parent = incubator;
                contentItem.anchors.fill = incubator;
            }
        }
    }
}
