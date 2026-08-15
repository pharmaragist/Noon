import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell

import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    property int implicitSize: 40
    implicitWidth: children[0]?.implicitWidth
    implicitHeight: children[0]?.implicitHeight

    property string viewId: ""
    property bool rotate: false
    property real rotationScale: 1
    property string _shape: "Bun"
    property var colors: Colors
    property color color: colors.colPrimaryContainer
    property alias shape: shapeItem
    property alias rotationAnimation: rotationAnimation

    MaterialShape {
        id: shapeItem
        _shape: root._shape
        implicitSize: root.implicitSize
        color: root.color

        RotationAnimation on rotation {
            id: rotationAnimation
            running: root.rotate
            duration: 50000 * root.rotationScale
            easing.type: Easing.Linear
            loops: Animation.Infinite
            from: 0
            to: 360
        }
    }
    layer.enabled: root.clip
    layer.effect: OpacityMask {
        maskSource: MaterialShape {
            implicitSize: root.implicitSize
            shape: shapeItem.shape
            rotation: root.rotate ? (shapeItem?.rotation) : 0
        }
    }
    
    
    
    
    

    MouseArea {
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        anchors.fill: parent
        onClicked: if (viewId)
            Globals.main.beam.reason = viewId
    }
}
