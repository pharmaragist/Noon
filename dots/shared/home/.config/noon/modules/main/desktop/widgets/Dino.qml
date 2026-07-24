import QtQuick
import Qt5Compat.GraphicalEffects
import qs.common
import qs.common.widgets

WidgetContainer {
    Item {
        id: dino
        anchors.fill: parent

        Image {
            id: img
            fillMode: Image.PreserveAspectFit
            source: Directories.assets + "/icons/dino.png"
            sourceSize: Qt.size(width, height)
            anchors.fill: parent
            anchors.margins: Padding.massive
        }

        ColorOverlay {
            anchors.fill: img
            source: img
            color: Colors.colSecondary
        }
    }
    MouseArea {
        z: 99
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: NoonUtils.callIpc("global dino")
    }
    StyledText {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: Padding.huge
        }
        text: "Dino"
        font: Fonts.request("title", "small")
        color: Colors.colSecondary
    }
}
