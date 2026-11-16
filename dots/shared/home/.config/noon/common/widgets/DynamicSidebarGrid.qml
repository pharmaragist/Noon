import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.common

Item {
    id: root
    property alias model: repeater.model
    readonly property alias grid: grid
    property real baseItemWidth: 240
    property real baseItemHeight: 180
    anchors.fill: parent

    GridLayout {
        id: grid

        Repeater { id: repeater }
    }
}
