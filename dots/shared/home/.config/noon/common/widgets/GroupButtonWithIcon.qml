import QtQuick
import QtQuick.Controls
import qs.common
import qs.common.widgets

GroupButton {
    id: root
    property alias symbol: symb
    property alias iconSize: symb.font.pixelSize
    property alias materialIconFill: symb.fill
    property alias materialIcon: symb.text
    property alias animateIcon: symb.animateChange
    property alias colSymbol: symb.color
    property alias implicitSize: root.baseSize

    Symbol {
        id: symb
        color: parent.toggled ? Colors.colOnPrimary : Colors[("colOnLayer" + (root.layerNumber ?? 1))]
        font.pixelSize: Fonts.sizes.large
        anchors.centerIn: parent
        fill: 1
    }
}
