import QtQuick

MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton 
    hoverEnabled: true
    cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
}
