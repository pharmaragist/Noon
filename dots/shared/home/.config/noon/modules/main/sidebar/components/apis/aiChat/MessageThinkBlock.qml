import qs.services
import qs.common
import qs.common.widgets
import QtQuick
import QtQuick.Controls
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

    property bool collapsed: true
    property int _dots: 0

    Timer {
        running: !root.completed
        interval: 400
        repeat: true
        onTriggered: root._dots = (root._dots + 1) % 4
    }

    Layout.fillWidth: true
    implicitHeight: Math.max(40, columnLayout.implicitHeight)

    MouseArea {
        id: mouseArea
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
                text: root.completed ? qsTr("Thought") : (qsTr("Thinking") + ".".repeat(root._dots))
            }
        }

        Revealer {
            reveal: !root.collapsed
            Layout.fillWidth: true
            vertical: true
            // Deliberately NOT MessageTextBlock: thinking is collapsed by
            // default and rarely read, so plain text avoids the markdown /
            // LaTeX / chunk-fade machinery per think block.
            revealChild: TextArea {
                visible: parent?.reveal
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                readOnly: true
                selectByMouse: root.enableMouseSelection
                renderType: Text.NativeRendering
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                font: Fonts.request("main", "small")
                color: Colors.colSubtext
                text: root.segmentContent
            }
        }
    }
}
