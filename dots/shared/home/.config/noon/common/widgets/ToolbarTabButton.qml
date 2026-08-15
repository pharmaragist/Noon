import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets

RippleButton {
    id: root
    property var colors: Colors
    required property string materialSymbol
    required property bool current

    horizontalPadding: 10
    implicitHeight: 40
    implicitWidth: implicitContentWidth + horizontalPadding * 2
    buttonRadius: height / 2
    colBackground: Colors.methods.transparentize(colors.colSurfaceContainer)
    colBackgroundHover: Colors.methods.transparentize(colors.colOnSurface, current ? 1 : 0.95)
    colRipple: Colors.methods.transparentize(colors.colOnSurface, 0.95)

    contentItem: Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Symbol {
            id: icon
            fill: current ? 1 : 0
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 22
            text: root.materialSymbol
        }

        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
        }
    }
}
