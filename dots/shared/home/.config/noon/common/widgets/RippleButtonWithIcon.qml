import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets

RippleButton {
    id: root

    property string materialIcon
    property bool materialIconFill: true
    property alias iconColor: symbol.color
    property alias iconSize: symbol.font.pixelSize
    property var colors: Colors
    property bool animateIcon: false
    buttonRadius: Rounding.normal
    colBackground: colors.colLayer2

    Symbol {
        id: symbol
        animateChange: root.animateIcon
        font.pixelSize: root.implicitSize / 2
        anchors.centerIn: parent
        text: materialIcon
        color: {
            if (root.toggled)
                return colors.colOnPrimary;
            else if (root.containsMouse)
                return colors.colOnLayer1Hover;
            else
                return colors.colOnLayer1;
        }
        fill: materialIconFill ? 1 : 0
    }
}
