import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import "./../common"

StyledRect {
    id: root
    property var bar
    anchors.left: parent.left
    anchors.leftMargin: Padding.verylarge
    anchors.verticalCenter: parent.verticalCenter
    radius: Rounding.verylarge
    color: _bg_event_area.containsMouse ? Colors.colLayer0Hover : "transparent"

    implicitWidth: rowLayout.implicitWidth + Padding.verylarge * 2
    implicitHeight: 30

    RowLayout {
        id: rowLayout
        z: 99
        anchors.centerIn: parent
        spacing: Padding.small

        Repeater {
            model: Math.min(Math.max(...Compositor.workspaces.map(ws => ws.id), 2), 10)

            Rectangle {
                readonly property bool isActive: Compositor.monitorFor(root.bar.screen)?.activeWorkspace?.id === (index + 1)
                readonly property bool isOccupied: Compositor.workspaces.some(ws => ws.id === (index + 1))

                implicitWidth: isActive ? 40 : 10
                implicitHeight: 10
                radius: Rounding.small

                opacity: isActive ? 1.0 : (isOccupied ? 0.6 : 0.2)
                color: isActive ? Colors.colOnLayer0 : Colors.colSubtext

                Behavior on implicitWidth {
                    Anim {}
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Compositor.focusWs(index + 1)
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => Compositor.focusWs(`r${event.angleDelta.y < 0 ? '+1' : '-1'}`)
    }
    MouseArea {
        id: _bg_event_area
        z: -1
        propagateComposedEvents: true
        anchors.fill: parent
        hoverEnabled: true

        onClicked: Ipc.call(["nobuntu", "toggle_overview"])
    }
}
