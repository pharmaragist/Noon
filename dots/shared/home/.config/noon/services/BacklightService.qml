pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root
    readonly property string deviceName: Mem.options.services.backlightDevice
    readonly property string sysfsDir: "/sys/class/backlight/" + root.deviceName

    property var stats: ({
            id: root.deviceName,
            type: (typeFile.text() || "").trim(),
            current: parseInt(currentFile.text()) || 0,
            max: parseInt(maxFile.text()) || 2,
            percentage: (parseInt(maxFile.text()) || 2) > 0 ? (parseInt(currentFile.text()) || 0) / (parseInt(maxFile.text()) || 2) : 0,
            icon: root.getIcon(parseInt(currentFile.text()) || 0)
        })

    onStatsChanged: NoonUtils.toast({
        content: "Changed"
    })

    FileView {
        id: currentFile
        path: root.sysfsDir + "/brightness"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: maxFile
        path: root.sysfsDir + "/max_brightness"
    }

    FileView {
        id: typeFile
        path: root.sysfsDir + "/type"
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
        command: ["brightnessctl", "-q", "-d", root.deviceName, "set", level.toString()]
    }

    function refreshDevices() {
        getAllProc.running = true;
    }

    function set(level) {
        setProc.level = level;
        setProc.running = true;
    }

    function cycle() {
        const nextLevel = (root.stats.current + 1) % (root.stats.max + 1);
        set(nextLevel);
    }

    function getIcon(level) {
        const icons = ["backlight_high_off", "backlight_low", "backlight_high"];
        return icons[level] ?? "backlight_high";
    }
}
