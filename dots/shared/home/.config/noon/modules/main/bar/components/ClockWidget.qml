import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.data

BarGroup {
    id: root
    vertical: false
    implicitWidth: maintxt.contentWidth + Padding.massive * 2

    StyledText {
        id: maintxt
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        font: Fonts.request("title", "normal")
        color: Colors.colOnLayer1
        text: DateTimeService.gnome_format
    }

    MouseArea {
        id: event_area
        anchors.fill: parent
        hoverEnabled: true
    }

    ClockPopup {
        hoverTarget: event_area
    }
}
