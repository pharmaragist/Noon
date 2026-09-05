import QtQuick
import qs.common
import qs.common.widgets
import qs.services
import qs.data

BarGroup {
    id: root
    implicitSize: BarData.currentBarExclusiveSize * 0.75
    scale: hoverArea.containsMouse ? 1.05 : 1

    ShellLogo {
        z: 999
        implicitSize: root.implicitSize
        fill: hoverArea.containsMouse ? 1 : 0
    }
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ipc.call(["noon", "toggle_beam"])
    }
}
