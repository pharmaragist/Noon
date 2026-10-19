pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root
    readonly property string currentMode: (governerWatcher?.text() ?? "")?.trim()
    readonly property bool turbo: Mem.states?.services?.power?.turbo ?? true
    readonly property bool bluetoothOnBoot: Mem.states?.services?.power?.bluetoothOnBoot ?? false
    readonly property Process proc: Process {}

    readonly property string icon: {
        const data = {
            "powersave": "eco",
            "performance": "bolt"
        };
        return data[currentMode] ?? "eco";
    }

    function switchMode() {
        const nextMode = currentMode === "powersave" ? "performance" : "powersave";
        set(nextMode);
    }

    function set(mode) {
        proc.running = false;
        proc.command = ["bash", "-c", `${Paths.scriptsDir}/power_service.sh  ${mode} ${(root.turbo ? "always" : "never")}  ${(root.bluetoothOnBoot ? "--bluetooth_boot_on" : "--bluetooth_boot_off")}`];
        proc.running = true;
    }

    FileView {
        id: governerWatcher
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }
}
