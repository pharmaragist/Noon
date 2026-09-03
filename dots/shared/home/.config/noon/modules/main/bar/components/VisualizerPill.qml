import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.data
import qs.services

import qs.common
import qs.common.widgets

BarGroup {
    id: root
    implicitWidth: 85
    implicitHeight: 85
    color: Colors.colLayer4

    Symbol {
        x: !root.vertical ? 6 : (root.width - contentWidth) / 2
        y: root.vertical ? root.height - contentHeight - 5: (root.height - implicitHeight) / 2
        icon: "music_note"
        iconSize: 14
        fill: 1
        color: Colors.colOnSurface
    }

    StyledRect {
        anchors.fill: parent
        color: Colors.colSurfaceContainerHigh
        radius: parent.radius - anchors.margins

        anchors.bottomMargin: root.vertical ? 25 : anchors.margins
        anchors.leftMargin: !root.vertical ? 25 : anchors.margins
        anchors.margins: Padding.verysmall

        Visualizer {
            id: vis
            z: 999
            active: true
            radius: parent.radius
            visualizerColor: Colors.colOnSurface
            anchors.margins: root.vertical ? 2 : 7
        }
    }
}
