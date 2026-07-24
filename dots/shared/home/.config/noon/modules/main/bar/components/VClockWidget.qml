import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

BarGroup {
    id: root

    implicitHeight: columnLayout.implicitHeight + (active ? Padding.massive : Padding.small)

    MouseArea {
        id: event_area
        hoverEnabled: true
        anchors.fill: parent
    }

    ColumnLayout {
        id: columnLayout

        anchors.centerIn: parent
        spacing: Padding.tiny

        Repeater {
            model: [DateTimeService.hour, DateTimeService.minute, DateTimeService.request("ddd")]
            StyledText {
                required property var modelData
                required property int index
                text: modelData
                font: Fonts.request("numbers", index === 2 ? "large" : "verylarge")
                color: Colors.colSecondary
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    ClockPopup {
        hoverTarget: event_area
    }
}
