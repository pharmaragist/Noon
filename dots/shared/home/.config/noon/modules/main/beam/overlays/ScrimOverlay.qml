import QtQuick
import qs.common
import qs.common.widgets

StyledRect {
    id: root

    signal hide

    property real level: 0.5
    property bool shown: false

    anchors.fill: parent
    color: Colors.m3.m3scrim
    z: -1
    opacity: shown ? level : 0

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }
}
