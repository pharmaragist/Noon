import QtQuick
import Qt5Compat.GraphicalEffects
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root

    normal: Item {
        anchors.fill: parent

        Item {
            id: dino
            anchors.fill: parent

            Image {
                id: img
                fillMode: Image.PreserveAspectFit
                source: Paths.assets + "/icons/dino.png"
                sourceSize: Qt.size(width, height)
                anchors.fill: parent
                anchors.margins: Padding.massive
            }

            transform: Scale {
                id: scale
                origin.x: dino.width / 2
                origin.y: dino.height / 2
                xScale: 1
                yScale: 1
            }
        }

        ColorOverlay {
            anchors.fill: dino
            source: dino
            color: Colors.colSecondary
        }

        SequentialAnimation {
            id: bounce
            running: false
            PropertyAnimation { target: scale; property: "xScale"; to: 0.86; duration: Animations.durations.verysmall; easing.type: Easing.OutQuad }
            PropertyAnimation { target: scale; property: "xScale"; to: 1.08; duration: Animations.durations.small; easing.type: Easing.OutBack }
            PropertyAnimation { target: scale; property: "xScale"; to: 1; duration: Animations.durations.small; easing.type: Easing.OutCubic }
            PropertyAnimation { target: scale; property: "yScale"; to: 0.86; duration: Animations.durations.verysmall; easing.type: Easing.OutQuad }
            PropertyAnimation { target: scale; property: "yScale"; to: 1.08; duration: Animations.durations.small; easing.type: Easing.OutBack }
            PropertyAnimation { target: scale; property: "yScale"; to: 1; duration: Animations.durations.small; easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: mouse
            z: 99
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: bounce.restart()
            onPressed: NoonUtils.callIpc("global dino")
        }

        StyledToolTip {
            content: "Dino"
            anchors.centerIn: parent
            extraVisibleCondition: mouse.containsMouse
        }
    }
    small: normal
    large: normal
    xlarge: normal
}
