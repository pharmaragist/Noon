import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

BarGroup {
    id: root

    implicitHeight: text.contentHeight + Padding.huge
    implicitWidth: text.contentWidth + Padding.huge
    StyledText {
        id: text
        anchors.centerIn: parent
        text: HyprlandService.keyboardLayoutShortName
        animateChange: true
        font: Fonts.request("mono", "normal", { weight: 900 })
        color: Colors.colSecondary
        Layout.alignment: Qt.AlignHCenter
    }
    MouseArea {
        anchors.fill: parent
        onClicked: HyprlandService.switchKeyboardLayout()
    }
}
