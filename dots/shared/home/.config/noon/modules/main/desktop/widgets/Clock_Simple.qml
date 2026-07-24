import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    expanded: true
    StyledText {
        anchors.centerIn: parent
        text: DateTimeService.time.toUpperCase()
        font: Fonts.request("numbers", Fonts.sizes.title * 0.85)
        color: Colors.colOnSurfaceVariant
    }
}
