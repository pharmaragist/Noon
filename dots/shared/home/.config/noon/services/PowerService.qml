pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root
    readonly property string currentMode: (governerWatcher?.text() ?? "").trim()
    readonly property bool turbo: Mem.states?.services?.power?.turbo ?? true
    readonly property bool bluetoothOnBoot: Mem.states?.services?.power?.bluetoothOnBoot ?? false
    readonly property list<string> modes: ["powersave", "performance"]
    readonly property string icon: {
        switch (currentMode) {
            case "powersave": return "eco";
            case "performance": return "bolt";
            default: return "eco";
        }
    }

    function switchMode() {
        const nextMode = currentMode === "powersave" ? "performance" : "powersave";
        set(nextMode);
    }

    function set(mode) {
        proc.running = false
        proc.running = true
    }

    Process {
        id: proc
        command: ["bash","-c", `${Paths.scriptsDir}/power_service.sh  ${currentMode} ${(root.turbo ? "always" : "never")}  ${(root.bluetoothOnBoot ? "--bluetooth_boot_on" : "--bluetooth_boot_off")}`]
    }

    function toast() {
        if (!currentMode) return;
        NoonUtils.toast({
            id: 9,
            content: `Power mode changed to ${currentMode}`,
            icon: icon
        });
    }
    onCurrentModeChanged: toast()

    FileView {
        id: governerWatcher
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }
}
