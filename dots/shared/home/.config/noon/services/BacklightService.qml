pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root
    readonly property string deviceName: Mem.options.services.backlightDevice

    property var stats: ({
            id: "",
            type: "",
            current: 0,
            max: 2,
            percentage: 1.0,
            icon: "backlight_high"
        })

    Component.onCompleted: pollProc.running = true

    Process {
        id: pollProc
        command: ["brightnessctl", "-d", root.deviceName, "-m", "g"]

        stdout: SplitParser {
            onRead: data => {
                let parsed = root.parseLine(data);
                if (parsed) {
                    root.stats = parsed;
                }
            }
        }
    }

    Process {
        id: getAllProc
        command: ["brightnessctl", "-l", "-m"]

        stdout: SplitParser {
            onRead: data => {
                let lines = data.trim().split('\n');
                let deviceList = [];

                lines.forEach(line => {
                    let parts = line.split(',');
                    if (parts.length >= 5) {
                        deviceList.push({
                            "name": parts[0],
                            "type": parts[1],
                            "current": parseInt(parts[2]),
                            "max": parseInt(parts[4])
                        });
                    }
                });

                Mem.store.services.backlight.devices = deviceList;
            }
        }
    }

    Process {
        id: setProc
        property int level: 0
        command: ["brightnessctl", "-m", "-d", root.deviceName, "set", level.toString()]

        stdout: SplitParser {
            onRead: data => {
                let parsed = root.parseLine(data);
                if (parsed) {
                    root.stats = parsed;
                }
            }
        }
    }

    function refreshDevices() {
        getAllProc.running = true;
    }

    function set(level) {
        setProc.level = level;
        setProc.running = true;
    }

    function cycle() {
        let current = parseInt(root.stats.current);
        let max = parseInt(root.stats.max);

        if (isNaN(current) || current < 0)
            current = 0;
        if (isNaN(max) || max <= 0)
            max = 2;

        let nextLevel = (current + 1) % (max + 1);
        set(nextLevel);
    }

    function getIcon(level) {
        const lvl = parseInt(level);
        const icons = ["backlight_high_off", "backlight_low", "backlight_high"];
        return icons[lvl] ?? "backlight_high";
    }

    function parseLine(line) {
        const i = line.trim().split(',');
        if (i.length < 5)
            return null;

        const currentVal = parseInt(i[2]);
        const pctStr = i[3].replace('%', '');
        const pctVal = parseFloat(pctStr) / 100;

        return {
            id: i[0],
            type: i[1],
            current: currentVal,
            percentage: isNaN(pctVal) ? 0 : pctVal,
            max: parseInt(i[4]),
            icon: root.getIcon(currentVal)
        };
    }
}
