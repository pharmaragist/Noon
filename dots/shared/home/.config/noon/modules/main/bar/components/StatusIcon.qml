import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

StyledRect {
    id: root
    property bool useBg: true
    property string icon: ""
    property string text: ""
    property bool isVertical: true
    property string mode: ""
    readonly property alias grid: grid
    readonly property MouseArea hoverHandler: MouseArea {
        anchors.fill: parent
        z: 999
        hoverEnabled: true
    }

    clip: true
    radius: Rounding.large
    color: useBg ? Colors.colSurfaceContainerHigh : "transparent"

    GridLayout {
        id: grid
        anchors.centerIn: parent

        columns: isVertical ? 1 : 2
        rows: isVertical ? 2 : 1
        rowSpacing: Padding.small
        columnSpacing: Padding.small

        Symbol {
            id: sign
            visible: root.mode === "both" || root.mode === "symbol"
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            fill: 1
            icon: root.icon
            iconSize: 18
            color: Colors.colSecondary
        }

        StyledText {
            visible: root.mode === "both" || root.mode === "text"
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            font: Fonts.request("main", 15, {
                weight: Font.Bold
            })
            text: root.text
            color: Colors.colSecondary
        }
    }
}
