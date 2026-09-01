import QtQuick
import Quickshell
import qs.common
import qs.common.utils
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    readonly property var manager: HyprlandService?.nightLightManager ?? null
    readonly property bool autoEnabled: Mem.options.services.nightLight.autoNightLightCycle ?? false

    function sync() {
        if (!root.autoEnabled)
            return;

        const [startH, startM] = (Mem.options.services.nightLight.autoStart ?? "20:00").split(":").map(Number);
        const [endH, endM] = (Mem.options.services.nightLight.autoEnd ?? "06:00").split(":").map(Number);
        const start = startH * 60 + (startM || 0);
        const end = endH * 60 + (endM || 0);

        const d = DateTimeService.clock.date;
        const now = d.getHours() * 60 + d.getMinutes();

        // Window crossing midnight (start > end): progress wraps past 1440.
        let offset = now - start;
        if (offset < 0)
            offset += 1440;
        const span = start > end ? end + 1440 - start : end - start;
        const progress = span === 0 ? 0 : Math.min(Math.max(offset / span, 0), 1);

        const isNight = progress > 0 && progress < 1;
        Mem.states.services.nightLight.enabled = isNight;

        // Ramp temperature: day temp at window start, coldest deep into the window.
        const day = Mem.options.services.nightLight.autoDayTemp ?? 6400;
        const night = Mem.options.services.nightLight.autoNightTemp ?? 3500;
        Mem.states.services.nightLight.temperature = Math.round(day - (day - night) * progress);
    }

    onAutoEnabledChanged: root.sync()

    Timer {
        id: autoCheckTimer

        interval: 60_000
        running: root.autoEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sync()
    }
}
