pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.common
import qs.common.utils

Singleton {
    id: root

    readonly property bool useFehrenheit: Mem.options.services.weather.useFehrenheit ?? false
    readonly property string weatherLocation: Mem.options.services.location ?? "Cairo"
    readonly property var weatherData: fetcher.data ?? ({})
    readonly property bool isLoading: fetcher.running
    readonly property var isReady: Object.keys(weatherData).length > 0
    onUseFehrenheitChanged: loadWeather()
    onWeatherLocationChanged: loadWeather()

    function loadWeather() {
        fetcher.refresh();
    }

    Fetcher {
        id: fetcher
        command: [Paths.scriptsDir + "/weather_service_metio", "--city", root.weatherLocation, (root.useFehrenheit ? "-f" : "")]
    }

    Timer {
        interval: 18000
        running: !isLoading
        repeat: !isReady
        onTriggered: root.loadWeather()
    }
}
