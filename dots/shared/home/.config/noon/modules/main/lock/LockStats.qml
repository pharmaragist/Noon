import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

RowLayout {
    Layout.alignment: Qt.AlignHCenter
    Layout.preferredHeight: 50
    spacing: Padding.normal

    BottomInfo {
        text: `${Math.round(BatteryService.percentage * 100, 2)}%`
        icon: "battery_full"
    }

    BottomInfo {
        text: Notifications.list.length
        icon: "notifications"
    }

    BottomInfo {
        visible: TimerService.timers.length > 0
        text: TimerService.timers.length
        icon: "alarm"
    }

    BottomInfo {
        text: Todo.list.length
        icon: "task_alt"
    }
    component BottomInfo: Row {
        id: root

        property string text
        property string icon

        spacing: Padding.small

        Symbol {
            text: root.icon
            fill: 1
            font.pixelSize: 20
        }

        StyledText {
            color: Colors.colOnPrimaryContainer
            horizontalAlignment: Text.AlignHCenter
            font: Fonts.request("main",18)
            opacity: 0.75
            text: root.text
        }
    }
}
