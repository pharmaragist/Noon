import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services

// Material 3 stops slider. See [https://m3.material.io/components/sliders/overview](https://m3.material.io/components/sliders/overview)
Slider {
    id: root

    property real step: 0.1
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
    property real stopIndicatorSize: 4 * scale
    // Color properties
    property color highlightColor: Colors.colPrimary
    property color trackColor: Colors.colSecondaryContainer
    property color handleColor: Colors.m3.m3onSecondaryContainer
    property color stopIndicatorColor: Colors.colPrimary
    property color stopIndicatorActiveColor: Colors.colOnPrimary
    property bool enableTooltip: false
    property real limitedHandleRangeWidth: (root.availableWidth - handleWidth - root.handleLimit * 2)
    property real fixedTrackWidth: root.availableWidth - (5 * scale) - root.handleLimit * 2
    property string tooltipContent: `${Math.round(value * 100)}%`
    // Wheel handler properties
    property real wheelStepSize: 0.05
    property bool showBackgroundDot: true
    Layout.fillWidth: true
    stepSize: 0
    from: 0
    to: 1

    onPressedChanged: {
        if (!pressed) {
            var range = root.to - root.from;
            var raw = (root.value - root.from) / root.step;
            var snapped = Math.round(raw) * root.step;
            root.value = root.from + Math.max(0, Math.min(range, snapped));
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            return mouse.accepted = false;
        }
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        // Add wheel event handler
        onWheel: wheel => {
            var delta = wheel.angleDelta.y / 120;
            var newValue = root.value + (delta * root.step);
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

        // Fill left (active/highlighted portion)
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

        // Fill right (inactive/track portion)
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

        // Stop indicators
        Repeater {
            model: Math.floor((root.to - root.from) / root.step) + 1

            Rectangle {
                required property int index

                property real stopValue: root.from + (index * root.step)
                property real stopPosition: (stopValue - root.from) / (root.to - root.from)

                anchors.verticalCenter: parent.verticalCenter
                x: root.handleLimit + stopPosition * root.fixedTrackWidth - root.stopIndicatorSize / 2
                width: root.stopIndicatorSize
                height: root.stopIndicatorSize
                radius: Rounding.full
                color: stopPosition <= root.visualPosition ? root.stopIndicatorActiveColor : root.stopIndicatorColor
            }
        }

        // Dot at the end
        Rectangle {
            visible: root.showBackgroundDot
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.backgroundDotMargins
            width: root.backgroundDotSize
            height: root.backgroundDotSize
            radius: Rounding.full
            color: Colors.colPrimary
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
