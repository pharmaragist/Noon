import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

StyledPopup {
    id: root

    contentItem: Item {
        anchors.centerIn: parent
        implicitHeight: 140
        implicitWidth: 180
        ColumnLayout {
            id: columnLayout
            anchors.fill: parent

            StyledText {
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                text: DateTimeService.request("hh:mm:ss ap").split(" ")[0]
                color: Colors.colOnLayer0
                font: Fonts.request("longNumbers", 86)
            }

            StyledText {
                Layout.bottomMargin: Padding.large
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(DateTimeService.clock.date, "dddd, MMMM d")
                color: Colors.colSubtext
                font: Fonts.request("title", "verylarge")
            }
        }
    }
}
