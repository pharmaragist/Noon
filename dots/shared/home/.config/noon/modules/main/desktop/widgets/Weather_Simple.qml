import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    expanded: false
    StyledText {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignCenter
        color: Colors.m3.m3onSurfaceVariant
        text: WeatherService.weatherData.currentTemp
        font: Fonts.request("numbers", Fonts.sizes.subTitle)
    }
}
