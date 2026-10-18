import qs.common
import QtQuick

StyledRect {
    id: root
    property string key

    property int layerNumber: 3
    property real verticalPadding: Padding.small
    property real horizontalPadding: Padding.large

    property real pixelSize: Fonts.sizes.normal
    property color keyColor: Colors.m3.m3surfaceContainerLow

    implicitWidth: keyText.contentWidth + (horizontalPadding * 2)
    implicitHeight: keyText.contentHeight + (verticalPadding * 2)

    radius: Rounding.huge
    color: Colors["colLayer" + layerNumber]

    StyledText {
        id: keyText
        anchors.centerIn: parent
        color: Colors["colOnLayer" + root.layerNumber]
        font: Fonts.request("mono", root.pixelSize, {
            weight: 750
        })
        text: root.key
    }
}
