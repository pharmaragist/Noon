import qs.common
import qs.common.widgets
import QtQuick

Item {
    property var messageData
    property int blockCount: 0
    property bool done: false
    property bool queued: false
    property bool loading: blockCount === 0 && !done && !queued
    anchors.left: parent.left
    implicitHeight: 40
    implicitWidth: 40
    Rectangle {
        Anim on width {
            running: loading
            duration: 1200
            easing.type: Easing.InOutCirc
            loops: Animation.Infinite
            from: 10
            to: 20
        }
        height: width
        anchors.centerIn: parent
        radius: Rounding.full
        color: Colors.colOnSurface
        visible: loading
    }
}
