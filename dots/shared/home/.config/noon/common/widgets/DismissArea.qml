import QtQuick
import qs.common

Rectangle {
    id: root

    property var target
    property bool active: false
    property bool dimAround: false

    signal dismiss

    visible: root.active && !!root.target && !Compositor.isHyprland
    anchors.fill: parent
    color: dimAround ? Colors.methods.transparentize(Colors.colScrim, 0.5) : "transparent"
    z: root.target ? root.target.z - 1 : -1

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        onPressed: root.dismiss()
    }
}
