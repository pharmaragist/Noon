import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool editing: parent?.editing ?? false
    property bool renderMarkdown: parent?.renderMarkdown ?? true
    property bool enableMouseSelection: parent?.enableMouseSelection ?? false
    property string segmentContent: parent?.segmentContent ?? ({})
    property var messageData: parent?.messageData ?? {}
    property bool done: parent?.done ?? true
    property bool completed: parent?.completed ?? false

    property bool collapsed: completed

    Layout.fillWidth: true
    implicitHeight: Math.max(40, columnLayout.implicitHeight)

    MouseArea {
        id: mouseArea
        enabled: root.completed
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.collapsed = !root.collapsed
    }

    ColumnLayout {
        id: columnLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        RowLayout {
            id: headerRow
            Layout.preferredHeight: 30
            Layout.maximumHeight: 30
            Layout.fillWidth: true
            spacing: Padding.normal

            Item {
                width: 24
                height: 24
                rotation: root.collapsed ? 0 : 180

                Behavior on rotation {
                    Anim {}
                }

                Symbol {
                    id: chevron
                    anchors.centerIn: parent
                    icon: "keyboard_arrow_down"
                    iconSize: 24
                    fill: 1
                    color: Colors.colOnLayer1
                    rotation: root.collapsed ? 0 : 180
                }
            }

            StyledText {
                Layout.fillWidth: true
                truncate: true
                Layout.rightMargin: Padding.large
                Layout.alignment: Qt.AlignLeft
                text: root.completed ? qsTr("Thought") : (qsTr("Thinking") + ".".repeat(Math.random() * 4))
            }
        }

        Revealer {
            reveal: !root.collapsed
            Layout.fillWidth: true
            vertical: true
            revealChild: MessageTextBlock {
                id: messageTextBlock
                visible: parent?.reveal
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                editing: root.editing
                renderMarkdown: root.renderMarkdown
                enableMouseSelection: root.enableMouseSelection
                segmentContent: root.segmentContent
                messageData: root.messageData
                done: root.done
            }
        }
    }
}
