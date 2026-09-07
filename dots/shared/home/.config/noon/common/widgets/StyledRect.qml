import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick.Effects

Rectangle {
    id: root
    readonly property int diagonal: Math.sqrt(Math.pow(width, 2) + Math.pow(height, 2))
    property bool enableAnimations: true
    property bool enableBorders: false
    property bool bouncy: true

    property int rightRadius
    property int leftRadius
    property int topRadius
    property int bottomRadius
    property int implicitSize
    property int animationDuration: Animations.durations.normal
    property var colors: Colors
    property var animProps: ({})

    implicitHeight: implicitSize
    implicitWidth: implicitSize
    topRightRadius: Math.max(rightRadius, topRadius, radius)
    bottomRightRadius: Math.max(rightRadius, bottomRadius, radius)
    topLeftRadius: Math.max(leftRadius, topRadius, radius)
    bottomLeftRadius: Math.max(leftRadius, bottomRadius, radius)
    color: colors.colPrimaryContainer
    border.color: enableBorders ? colors.colOutline : "transparent"
    border.width: 1
    layer.enabled: clip
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root?.width
            height: root?.height
            radius: root?.radius
            topRightRadius: root?.topRightRadius
            bottomRightRadius: root?.bottomRightRadius
            topLeftRadius: root?.topLeftRadius
            bottomLeftRadius: root?.bottomLeftRadius
        }
    }

    readonly property Component animComp: Anim {}
    readonly property Component sAnimComp: SAnim {}

    function getAnimation(parent) {
        let comp = bouncy ? sAnimComp : animComp;
        return comp.createObject(parent, Object.assign({}, {
            duration: root.animationDuration
        }, root.animProps));
    }

    Behavior on color {
        enabled: root.enableAnimations
        CAnim {
            duration: root.animationDuration
        }
    }

    Behavior on opacity {
        enabled: root.enableAnimations
        animation: root.getAnimation(this)
    }

    Behavior on width {
        enabled: root.enableAnimations
        animation: root.getAnimation(this)
    }

    Behavior on height {
        enabled: root.enableAnimations
        animation: root.getAnimation(this)
    }

    Behavior on scale {
        enabled: root.enableAnimations
        animation: root.getAnimation(this)
    }

    Behavior on y {
        enabled: root.enableAnimations
        animation: root.getAnimation(this)
    }

    Behavior on implicitWidth {
        enabled: root.enableAnimations
        animation: root.getAnimation(this)
    }

    Behavior on implicitHeight {
        enabled: root.enableAnimations
        animation: root.getAnimation(this)
    }
}
