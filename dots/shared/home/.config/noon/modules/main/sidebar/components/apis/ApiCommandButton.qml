import QtQuick
import qs.common
import qs.common.widgets

GroupButton {
    id: button

    property string buttonText

    horizontalPadding: 12
    verticalPadding: 8
    baseWidth: contentItem.implicitWidth + horizontalPadding * 2
    clickedWidth: baseWidth + 20
    baseHeight: contentItem.implicitHeight + verticalPadding * 2
    buttonRadius: down ? Rounding.small : Rounding.large
    colBackground: Colors.colLayer2
    colBackgroundHover: Colors.colLayer2Hover
    colBackgroundActive: Colors.colLayer2Active

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: Colors.m3.m3onSurface
    }

}
