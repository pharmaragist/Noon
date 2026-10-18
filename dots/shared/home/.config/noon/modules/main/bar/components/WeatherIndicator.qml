import QtQuick
import qs.common
import qs.services

BarRevealerIndicator {
    readonly property var weatherData: WeatherService.weatherData
    expanded: true
    icon: weatherData?.material_icon ?? ""
    text: weatherData?.current_temp?.slice(0, -1)
    releaseAction: () => Ipc.call(["noon", "reveal_beam", "weather"])
    Component.onCompleted: WeatherService.loadWeather()
}
