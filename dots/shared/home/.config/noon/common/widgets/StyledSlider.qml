import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services


Slider {
    id: root

    property real scale: 0.85
    property real backgroundDotSize: 4 * scale
    property real backgroundDotMargins: 4 * scale
    property real handleMargins: (root.pressed ? 0 : 2) * scale
    property real handleWidth: (root.pressed ? 3 : 5) * scale
    property real handleHeight: 44 * scale
    property real handleLimit: root.backgroundDotMargins
    property real trackHeight: 30 * scale
    property real trackRadius: Rounding.verysmall * scale
    property real unsharpenRadius: Rounding.tiny
    
    property color highlightColor: Colors.colPrimary
    property color trackColor: Colors.colSecondaryContainer
    property color handleColor: Colors.m3.m3onSecondaryContainer
    property bool enableTooltip: true
    property real limitedHandleRangeWidth: (root.availableWidth - handleWidth - root.handleLimit * 2)
    property string tooltipContent: `${Math.round(value * 100)}%`
    
    property real wheelStepSize: 0.05
    property bool showBackgroundDot: true
    Layout.fillWidth: true
    from: 0
    to: 1

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            return mouse.accepted = false;
        }
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        
        onWheel: wheel => {
            var delta = wheel.angleDelta.y / 120; 
            var newValue = root.value + (delta * root.wheelStepSize);
            root.value = Math.max(root.from, Math.min(root.to, newValue));
            wheel.accepted = true;
        }
    }

    Behavior on value {
        SmoothedAnimation {
            velocity: Animations.durations.small
        }
    }

    Behavior on handleMargins {
        Anim {}
    }

    background: Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: trackHeight

        
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: root.handleLimit * 2 + root.visualPosition * root.limitedHandleRangeWidth - (root.handleMargins + root.handleWidth / 2)
            height: trackHeight
            color: root.highlightColor
            topLeftRadius: root.trackRadius
            bottomLeftRadius: root.trackRadius
            topRightRadius: root.unsharpenRadius
            bottomRightRadius: root.unsharpenRadius
        }

        
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: root.handleLimit * 2 + (1 - root.visualPosition) * root.limitedHandleRangeWidth - (root.handleMargins + root.handleWidth / 2)
            height: trackHeight
            color: root.trackColor
            topLeftRadius: root.unsharpenRadius
            bottomLeftRadius: root.unsharpenRadius
            topRightRadius: root.trackRadius
            bottomRightRadius: root.trackRadius
        }

        
        Rectangle {
            visible: root.showBackgroundDot
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.backgroundDotMargins
            width: root.backgroundDotSize
            height: root.backgroundDotSize
            radius: Rounding.full
            color: root.handleColor
        }
    }

    handle: Rectangle {
        id: handle

        x: root.leftPadding + root.handleLimit + root.visualPosition * root.limitedHandleRangeWidth
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: root.handleWidth
        implicitHeight: root.handleHeight
        radius: Rounding.full
        color: root.handleColor

        StyledToolTip {
            extraVisibleCondition: root.enableTooltip && root.pressed
            content: root.tooltipContent
        }

        Behavior on implicitWidth {
            Anim {}
        }
    }
}
