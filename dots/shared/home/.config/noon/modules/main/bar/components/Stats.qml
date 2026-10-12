import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

BarGroup {
    id: root

    implicitHeight: columnLayout.implicitHeight + (active ? Padding.massive : Padding.small)
    readonly property var stats: [
        {
            id: "task",
            icon: "task_alt",
            handler: () => {
                Ipc.call(["sidebar", "reveal", "Tasks"]);
            },
            value: TodoService.list.length
        },
        {
            id: "notif",
            icon: "notifications_active",
            handler: () => {
                Ipc.call(["sidebar", "reveal", "Notifs"]);
            },
            value: Notifications.list.length
        },
        {
            id: "timer",
            icon: "timer",
            handler: () => {
                Ipc.call(["sidebar", "reveal", "Timers"]);
            },
            value: TimerService.timers.length
        }
    ]

    MouseArea {
        id: event_area
        hoverEnabled: true
        anchors.fill: parent
    }

    GridLayout {
        id: columnLayout

        anchors.centerIn: parent

        rows: !root.vertical ? 1 : stats.length
        columns: root.vertical ? 1 : stats.length
        rowSpacing: Padding.verysmall
        columnSpacing: Padding.verysmall

        Repeater {
            model: root.stats

            Symbol {
                fill: 1
                visible: modelData.value > 0
                icon: modelData?.icon ?? ""
                color: Colors.colSecondary
                iconSize: 18
                StyledToolTip {
                    extraVisibleCondition: hvr.containsMouse
                    content: "You have " + modelData?.value + " pending " + modelData?.id + (modelData?.value > 1 ? "s" : "")
                }
                MouseArea {
                    id: hvr
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: () => modelData?.handler()
                }
            }
        }
    }
}
