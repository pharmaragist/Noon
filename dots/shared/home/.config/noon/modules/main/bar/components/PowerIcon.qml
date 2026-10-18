import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

MaterialShapeWrappedSymbol {
    id: root

    readonly property var mode: PowerService.currentMode
    visible: BatteryService.available
    fill: 1
    implicitSize: 32
    text: PowerService.icon ?? "eco"
    _shape: mode === "powersave" ? "Cookie4Sided": "Clover4Leaf"
    color: mode === "performance" ? Colors.colPrimary: Colors.colLayer2
    colSymbol: mode === "performance" ? Colors.colOnPrimary: Colors.colOnLayer2

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: PowerService.switchMode();
    }
}
