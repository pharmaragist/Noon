import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.common

GridView {
    id: root

    property bool hint: false
    property int radius: Rounding.large
    property color colBackground: "transparent"

    property real touchpadScrollFactor: Mem.options.interactions.scrolling.touchpadScrollFactor ?? 100
    property real mouseScrollFactor: Mem.options.interactions.scrolling.mouseScrollFactor ?? 50
    property real mouseScrollDeltaThreshold: Mem.options.interactions.scrolling.mouseScrollDeltaThreshold ?? 120
    property real scrollTargetY: 0
    property var _model
    property int columns: 1
    cellWidth: width / columns
    cellHeight: width / columns
    model: (script && script.values) ? script : []

    ScriptModel {
        id: script
        values: _model ?? []
    }

    StyledLoader {
        z: 999
        active: root.hint
        anchors.fill: parent
        anchors.margins: -parent?.anchors.margins
        sourceComponent: ScrollEdgeFade {
            target: root
        }
    }

    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds
    layer.enabled: root.clip

    Rectangle {
        z: -1
        anchors.fill: root
        color: root.colBackground
    }


    MouseArea {
        visible: Mem.options.interactions.scrolling.fasterTouchpadScroll ?? true
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: false
        onWheel: function (wheelEvent) {
            const delta = wheelEvent.angleDelta.y / root.mouseScrollDeltaThreshold;


            var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold ? root.mouseScrollFactor : root.touchpadScrollFactor;
            const maxY = Math.max(0, root.contentHeight - root.height);
            const base = root.contentY;
            var targetY = Math.max(0, Math.min(base - delta * (scrollFactor * 0.08), maxY));
            root.scrollTargetY = targetY;
            root.contentY = targetY;
            wheelEvent.accepted = true;
        }
    }



    add: Transition {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            duration: Animations.durations.small
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Animations.curves.expressiveFastSpatial
        }
    }
    addDisplaced: Transition {
        Anim {
            properties: "x,y"
            duration: Animations.durations.small
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Animations.curves.expressiveFastSpatial
        }
    }
    remove: Transition {
        Anim {
            property: "opacity"
            from: 1
            to: 0
            duration: 150
            easing.type: Easing.InCubic
        }
    }
    removeDisplaced: Transition {
        Anim {
            properties: "x,y"
            duration: Animations.durations.small
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Animations.curves.expressiveFastSpatial
        }
    }

    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }
}
