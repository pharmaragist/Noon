pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.common
import qs.common.utils

Singleton {
    id: root

    readonly property var weatherData: Mem?.store?.services?.weather?.data ?? ({})
    readonly property var opts: Mem.options.services.weather

    readonly property bool isLoading: fetcher.running
    readonly property bool isReady: !!weatherData && !("error" in weatherData)
    readonly property list<string> base: [Paths.scripts.weather, "-c", opts?.location]
    readonly property list<string> command: opts.useFehrenheit ? [...base , "-f"] : base

    onCommandChanged: if (command)
        loadWeather(true)

    function loadWeather(force = false) {
        var cached = Mem.store?.services?.weather?.data;
        var today = Qt.formatDateTime(new Date(), "yyyy-MM-dd");
        if (!force && cached && cached.date === today) {
            return;
        }
        fetcher.refresh();
    }

    Fetcher {
        id: fetcher
        command: root.command
        onDataChanged: if (!("error" in this.data))
            Mem.store.services.weather.data = this.data
    }

    Timer {
        interval: 18000
        running: !isLoading
        repeat: !isReady
        onTriggered: root.loadWeather()
    }
}
