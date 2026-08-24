import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

Item {
    id: root

    property var colors: Colors
    property real padding: 8
    property color colBackground: colors.colLayer1
    property alias spacing: toolbarLayout.spacing
    default property alias data: toolbarLayout.data
    property alias radius: background.radius

    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight

    LayerRect {
        id: background

        anchors.fill: parent
        colBackground: root.colBackground
        implicitHeight: Math.max(toolbarLayout.implicitHeight + root.padding * 2, 56)
        implicitWidth: toolbarLayout.implicitWidth + root.padding * 2
        radius: height / 2

        RowLayout {
            id: toolbarLayout

            spacing: 4

            anchors {
                fill: parent
                margins: root.padding
            }
        }
    }
}
