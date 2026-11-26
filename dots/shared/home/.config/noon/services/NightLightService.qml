pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property var state: Mem.states.services?.nightLight ?? null
    readonly property bool enabled: root.state?.enabled ?? false
    readonly property int temperature: root.state?.temperature ?? 3200
    readonly property real gamma: root.state?.gamma ?? 1
    readonly property bool autoEnabled: Mem.options.services.nightLight.autoNightLightCycle ?? false
    readonly property string executable: "gammastep"
    readonly property bool running: gammastep.running

    function clamp(value: real, min: real, max: real): real {
        return Math.max(min, Math.min(max, value));
    }

    function command(): list<string> {
        const temp = Math.round(root.clamp(root.temperature, 1000, 10000));
        const gamma = root.clamp(root.gamma, 0.1, 10);
        return [
            root.executable, "-m", "wayland", "-O", String(temp),
            "-g", `${gamma}:${gamma}:${gamma}`, "-P", "-r"
        ];
    }

    function apply(): void {
        if (!root.enabled) {
            restartTimer.stop();
            gammastep.running = false;
            return;
        }

        gammastep.running = false;
        gammastep.command = root.command();
        gammastep.running = true;
    }

    function scheduleApply(): void {
        restartTimer.restart();
    }

    function sync(): void {
        if (!root.autoEnabled)
            return;

        const [startH, startM] = (Mem.options.services.nightLight.autoStart ?? "20:00")
            .split(":").map(Number);
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

    Component.onCompleted: root.apply()

    onEnabledChanged: root.scheduleApply()
    onTemperatureChanged: root.scheduleApply()
    onGammaChanged: root.scheduleApply()
    onAutoEnabledChanged: root.sync()


    Process {
        id: gammastep

        running: false
        stderr: SplitParser {
            onRead: line => {
                if (line.trim())
                    console.warn("NightLightService: gammastep", line.trim());
            }
        }
        onExited: code => {
            // 15 is our own SIGTERM when restarting or disabling the filter.
            if (code !== 0 && code !== 15 && root.enabled)
                console.warn("NightLightService: gammastep exited with", code);
        }
    }

    Timer {
        id: restartTimer

        interval: 150
        onTriggered: root.apply()
    }

    Timer {
        id: autoCheckTimer

        interval: 60_000
        running: root.autoEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sync()
    }
}
