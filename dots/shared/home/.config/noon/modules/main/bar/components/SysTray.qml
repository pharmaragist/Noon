import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.data

Item {
    id: root

    property var bar
    property int iconSize: BarData.currentBarExclusiveSize / 3
    property bool verticalMode: BarData.currentInfo.position === "left" || BarData.currentInfo.position === "right"
    readonly property var model: SystemTray.items

    implicitHeight: verticalMode ? content.implicitHeight + Padding.huge : parent.height
    implicitWidth: verticalMode ? parent.width : content.implicitWidth + Padding.huge
    states: [
        State {
            when: verticalMode

            PropertyChanges {
                target: content
                rows: -1
                columns: 1
            }
        },
        State {
            when: !verticalMode

            PropertyChanges {
                target: content
                rows: 1
                columns: -1
            }
        }
    ]

    GridLayout {
        id: content

        anchors.centerIn: parent
        rowSpacing: Padding.large
        columnSpacing: Padding.large

        Repeater {
            model: root.model
            Layout.row: root.verticalMode ? 1 : -1

            SysTrayItem {
                required property SystemTrayItem modelData

                implicitSize: root.iconSize
                item: modelData
            }
        }
    }
}
