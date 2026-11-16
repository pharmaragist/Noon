import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.data
import qs.common
import qs.common.widgets
import qs.services

OsdPanel {
    id: panelRoot

    fill: true

    // Time on screen after the last change (ms)
    property int hideDelay: 1500

    mask: Region {
        item: content
    }

    Connections {
        target: panelRoot
        function onTargetScreenChanged() {
            panelRoot.screen = panelRoot.targetScreen;
        }
    }

    function getM(side) {
        return BarData.currentState.position === side ? BarData.currentInfo.appearance.size + Padding.huge : Sizes.elevationMargin
    }

    function poke() {
        if (!visible)
            return;
        holder.shown = true;
        hideTimer.restart();
    }

    onVisibleChanged: poke()
    onValueChanged: poke()
    Component.onCompleted: poke()

    Timer {
        id: hideTimer
        interval: panelRoot.hideDelay
        onTriggered: {
            if (hover.hovered)
                hideTimer.restart();
            else
                holder.shown = false;
        }
    }

    // One item carries slide + scale + opacity, so shadow and content
    // animate together as a single unit driven by one progress value.
    Item {
        id: holder

        property bool shown: false

        // Single animation clock: 0 = hidden, 1 = revealed
        property real reveal: shown ? 1 : 0

        Behavior on reveal {
            NumberAnimation {
                duration: holder.shown ? 300 : 220
                easing.type: holder.shown ? Easing.OutCubic : Easing.InCubic
            }
        }

        readonly property real dir: volumeMode ? 1 : -1
        readonly property real travel: width + panelRoot.getM(volumeMode ? "right" : "left") + 8

        implicitWidth: 14
        implicitHeight: 180
        width: implicitWidth
        height: implicitHeight

        visible: reveal > 0.001
        opacity: reveal
        scale: 0.85 + 0.15 * reveal
        transformOrigin: volumeMode ? Item.Right : Item.Left

        transform: Translate {
            x: holder.dir * (1 - holder.reveal) * holder.travel
        }

        anchors {
            left: !volumeMode ? parent.left : undefined
            verticalCenter: parent.verticalCenter
            right: volumeMode ? parent.right : undefined
            leftMargin: panelRoot.getM("left")
            rightMargin: panelRoot.getM("right")
        }

        HoverHandler {
            id: hover
        }

        StyledRectangularShadow {
            target: content
        }

        StyledRect {
            id: content

            anchors.fill: parent
            radius: Rounding.tiny
            clip: true
            color: Colors.colBackground

            StyledRect {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.left: parent.left
                bouncy: true
                height: Math.max(0, (panelRoot?.value ?? 0) * parent.height - 1)
                color: Colors.colOnLayer0
                radius: Rounding.tiny
            }
        }
    }
}
