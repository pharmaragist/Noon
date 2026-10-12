pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.common

Singleton {
    id: root

    property var timers: Mem.timers.timers
    property int nextTimerId: Mem.timers.nextTimerId

    signal timerFinished(int timerId, string name)

    readonly property list<var> presets: Mem.timers.presets

    Component.onCompleted: {
        cleanStale();
    }

    function reload() {
    }

    function remainingTime(timer) {
        if (!timer)
            return 0;

        if (!timer.startedIn)
            return timer.duration;

        return Math.max(0, timer.duration - Math.floor((Date.now() - timer.startedIn) / 1000));
    }

    function isRunning(timer) {
        return !!timer?.startedIn;
    }

    function addAndStartTimer(name, duration) {
        const id = addTimer(name, duration, false);

        Qt.callLater(() => startTimer(id));

        return id;
    }

    function addTimer(name, duration, isPreset, autoStart = false, wakeTime = null) {
        const newTimer = {
            id: nextTimerId,
            name: name,
            duration: duration,
            startedIn: autoStart ? Date.now() : 0,
            icon: root.presets.find(p => p.duration === duration)?.icon ?? (wakeTime ? "alarm" : "timer")
        };

        Mem.timers.nextTimerId = nextTimerId + 1;
        Mem.timers.timers = timers.concat([newTimer]);

        if (autoStart)
            NoonUtils.playSound("record_started");

        return newTimer.id;
    }

    function removeTimer(timerId) {
        Mem.timers.timers = timers.filter(t => t.id !== timerId);
    }

    function startTimer(timerId) {
        const timer = timers.find(t => t.id === timerId);

        if (!timer || remainingTime(timer) <= 0)
            return;

        Mem.timers.timers = timers.map(t => {
            if (t.id !== timerId)
                return t;

            return {
                id: t.id,
                name: t.name,
                duration: t.duration,
                startedIn: Date.now(),
                icon: t.icon
            };
        });

        NoonUtils.playSound("record_started");
    }

    function pauseTimer(timerId) {
        const timer = timers.find(t => t.id === timerId);

        if (!timer)
            return;

        const remaining = remainingTime(timer);

        Mem.timers.timers = timers.map(t => {
            if (t.id !== timerId)
                return t;

            return {
                id: t.id,
                name: t.name,
                duration: remaining,
                startedIn: 0,
                icon: t.icon
            };
        });
    }

    function resetTimer(timerId) {
        const timer = timers.find(t => t.id === timerId);

        if (!timer)
            return;

        // `duration` is the current duration. Resetting a timer means
        // restoring it to the duration it currently represents.
        Mem.timers.timers = timers.map(t => {
            if (t.id !== timerId)
                return t;

            return {
                id: t.id,
                name: t.name,
                duration: t.duration,
                startedIn: 0,
                icon: t.icon
            };
        });
    }

    function updateTimer(timerId, newDuration) {
        const timer = timers.find(t => t.id === timerId);

        if (!timer)
            return;

        const wasRunning = !!timer.startedIn;

        Mem.timers.timers = timers.map(t => {
            if (t.id !== timerId)
                return t;

            return {
                id: t.id,
                name: t.name,
                duration: newDuration,
                startedIn: 0,
                icon: t.icon
            };
        });

        if (wasRunning)
            Qt.callLater(() => startTimer(timerId));
    }

    function formatTime(seconds) {
        seconds = Math.max(0, Math.floor(seconds));

        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;

        return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
    }

    function parseTimeString(input) {
        if (!input)
            return 0;

        input = String(input).trim().toLowerCase();

        const regex = /(\d+)([hms])/g;

        let total = 0;
        let match;

        while ((match = regex.exec(input)) !== null) {
            const val = parseInt(match[1]);
            const unit = match[2];

            if (unit === "h")
                total += val * 3600;
            else if (unit === "m")
                total += val * 60;
            else if (unit === "s")
                total += val;
        }

        if (total === 0 && /^\d+$/.test(input))
            total = parseInt(input) * 60;

        return total;
    }

    function wake(timeStr, name) {
        const target = parseWakeTime(timeStr);

        if (!target || isNaN(target.getTime())) {
            console.warn("TimerService.wake: invalid time string:", timeStr);
            return -1;
        }

        const now = Date.now();

        const duration = Math.max(60, Math.floor((target.getTime() - now) / 1000));

        return addTimer(name || "Wake Alarm", duration, false, true, target.toISOString());
    }

    function formatWakeTime(isoTime) {
        const date = new Date(isoTime);

        const h = date.getHours() % 12 || 12;
        const m = String(date.getMinutes()).padStart(2, '0');

        return `${h}:${m} ${date.getHours() >= 12 ? "PM" : "AM"}`;
    }

    function parseWakeTime(timeStr) {
        if (!timeStr)
            return null;

        const now = new Date();
        let target = new Date();

        const cleaned = String(timeStr).trim().toLowerCase();

        if (cleaned.includes(":")) {
            const isPM = cleaned.includes("pm");
            const isAM = cleaned.includes("am");

            const timeOnly = cleaned.replace(/[ap]m/gi, "").trim();

            const parts = timeOnly.split(":");

            const hours = parseInt(parts[0]);
            const minutes = parts.length > 1 ? parseInt(parts[1]) : 0;

            if (isNaN(hours))
                return null;

            let hour = hours;

            if (isPM && hour !== 12)
                hour += 12;

            if (isAM && hour === 12)
                hour = 0;

            target.setHours(hour, isNaN(minutes) ? 0 : minutes, 0, 0);

            if (target <= now)
                target.setDate(target.getDate() + 1);

            return target;
        }

        return null;
    }

    function formatTimers() {
        if (timers.length === 0)
            return "No timers currently";

        let output = "Current timers:\n\n";

        timers.forEach(timer => {
            const status = isRunning(timer) ? "Running" : "Stopped";

            const remaining = formatTime(remainingTime(timer));

            const total = formatTime(timer.duration);

            output += `ID: ${timer.id}\n`;
            output += `Name: ${timer.name}\n`;
            output += `Status: ${status}\n`;
            output += `Time: ${remaining} / ${total}\n`;
            output += `Icon: ${timer.icon}\n\n`;
        });

        return output;
    }

    function cleanStale() {
        const now = Date.now();
        const remaining = [];

        for (const timer of timers) {
            if (!timer.startedIn) {
                remaining.push(timer);
                continue;
            }

            const elapsed = Math.floor((now - timer.startedIn) / 1000);

            if (elapsed >= timer.duration) {
                NoonUtils.playSound("record_stopped");
                NoonUtils.wake(`${timer.name} is Done !`);
                timerFinished(timer.id, timer.name);
                continue;
            }

            remaining.push(timer);
        }

        if (remaining.length !== timers.length)
            Mem.timers.timers = remaining;
    }
}
