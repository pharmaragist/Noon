import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

StyledRect {
    id: root

    property string text: ""
    property string icon: ""
    property bool toggled: false
    property var downAction

    implicitHeight: 34
    implicitWidth: row.implicitWidth + Padding.large * 2
    radius: Rounding.full
    color: toggled ? Colors.colPrimary : Colors.colLayer2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Padding.small

        Symbol {
            Layout.alignment: Qt.AlignVCenter
            icon: root.icon || "category"
            iconSize: 16
            fill: root.toggled ? 1 : 0
            color: root.toggled ? Colors.colOnPrimary : Colors.colOnLayer2
        }
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.text
            font: Fonts.request("main", "small")
            color: root.toggled ? Colors.colOnPrimary : Colors.colOnLayer2
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.downAction)
                root.downAction();
        }
    }
}
