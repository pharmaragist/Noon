import QtQuick

MouseArea {
    anchors.fill: parent
    drag.target: parent
    drag.axis: Drag.XAndYAxis
    drag.threshold: 6
    drag.smoothed: true
}
