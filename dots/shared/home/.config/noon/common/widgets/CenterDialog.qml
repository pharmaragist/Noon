import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services

Item {
    id: root
    z: 99999
    property bool show: true
    property alias bg: bg
    property Item contentItem
    property QtObject colors: Colors
    property var buttonData: [
        {
            label: "Cancel",
            action: () => root.dismissed()
        }
    ]
    readonly property bool reveal: show || bg.visible
    anchors.fill: parent
    anchors.margins: -parent.margins || 0

    default property alias content: contentRoot.data

    signal dismissed

    onShowChanged: if (!root.show)
        root.visible = false
    onRevealChanged: if (root.reveal)
        root.visible = true

    StyledRect {
        id: bg
        z: 9999
        anchors.centerIn: parent
        implicitWidth: (contentItem ? contentItem.implicitWidth : 200) + Padding.huge * 2
        implicitHeight: (contentItem ? contentItem.implicitHeight : 80) + Padding.huge * 2
        width: implicitWidth
        height: implicitHeight
        radius: Rounding.verylarge
        color: colors.colLayer0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Padding.huge

            Item {
                id: contentRoot
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            RowLayout {
                id: buttonRow
                Layout.fillWidth: true
                Layout.maximumHeight: 40

                Item { Layout.fillWidth: true }

                Repeater {
                    model: root.buttonData
                    delegate: RippleButton {
                        buttonText: modelData?.label
                        releaseAction: () => modelData.action()
                    }
                }
            }
        }
    }

    Component.onCompleted: if (contentItem) {
        contentItem.parent = contentRoot;
        contentItem.anchors.fill = contentRoot;
    }

    Rectangle {
        id: scrim
        z: -1
        opacity: root.reveal ? 1 : 0
        color: Colors.t(colors.colScrim, 0.24)
        anchors.fill: parent
        visible: root.reveal

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: root.show ? Qt.LeftButton : Qt.NoButton
            onClicked: {
                root.show = false;
                root.dismissed();
            }
        }

        Behavior on opacity {
            Anim {}
        }
    }
}
