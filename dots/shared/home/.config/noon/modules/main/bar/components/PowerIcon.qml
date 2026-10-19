import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.services

MaterialShapeWrappedSymbol {
    id: root
    readonly property var svc: PowerService
    readonly property var mode: svc?.currentMode
    visible: BatteryService.available
    fill: 1
    implicitSize: 32
    text: svc?.icon ?? "eco"
    _shape: mode === "powersave" ? "Cookie4Sided": "Clover4Leaf"
    color: mode === "performance" ? Colors.colPrimary: Colors.colLayer2
    colSymbol: mode === "performance" ? Colors.colOnPrimary: Colors.colOnLayer2

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: svc?.switchMode();
    }
}
