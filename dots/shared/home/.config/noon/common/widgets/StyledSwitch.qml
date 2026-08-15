import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common




Switch {
    id: root

    property var colors: Colors
    property real scale: 0.85 
    
    property color activeColor: colors.colPrimary ?? "#685496"
    property color inactiveColor: colors.colSurfaceContainerHigh ?? "#45464F"
    property color activeBorderColor: colors.colPrimary ?? "#685496"
    property color inactiveBorderColor: colors.colSurfaceContainerHighest
    property color buttonActiveColor: colors.colOnPrimary
    property color buttonColor: colors.colSurfaceContainerHighest
    property color iconActiveColor: colors.colPrimary
    property color iconColor: colors.colOnSurfaceDisabled
    implicitHeight: 32 * root.scale
    implicitWidth: 52 * root.scale

    PointingHandInteraction {}
    text: ""
    
    background: Rectangle {
        width: parent.width
        height: parent.height
        radius: Rounding.full ?? 9999
        color: root.checked ? root.activeColor : root.inactiveColor
        border.width: 2 * root.scale
        border.color: root.checked ? root.activeBorderColor : root.inactiveBorderColor

        Behavior on color {
            CAnim {}
        }

        Behavior on border.color {
            CAnim {}
        }
    }

    
    indicator: StyledRect {
        width: (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16 * root.scale)
        height: (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16 * root.scale)
        radius: Rounding.full
        color: root.checked ? root.buttonActiveColor : root.buttonColor
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.checked ? ((root.pressed || root.down) ? (22 * root.scale) : 24 * root.scale) : ((root.pressed || root.down) ? (2 * root.scale) : 8 * root.scale)

        Symbol {
            text: root.checked ? 'done' : ''
            fill: 1
            anchors.centerIn: parent
            font.pixelSize: parent.width * scale
            color: root.checked ? root.iconActiveColor : root.iconColor
        }

        Behavior on anchors.leftMargin {
            Anim {}
        }
    }
}
