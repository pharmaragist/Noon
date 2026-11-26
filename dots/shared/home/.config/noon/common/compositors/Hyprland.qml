pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.data
import qs.common
import qs.common.utils

AbstractCompositor {
    id: root

    property string keyboardLayout: ""
    property var keyboardLayoutNames: []

    monitors: root.mapMonitors()
    windowList: root.mapWindows()
    workspaces: root.mapWorkspaces()
    windowByAddress: root.mapByAddress(root.windowList)
    activeWorkspace: root.mapActiveWorkspace()
    focusedWorkspace: Hyprland.focusedWorkspace ?? null
    focusedMonitor: Hyprland.focusedMonitor ?? null
    currentKeyboardLayout: root.keyboardLayout
    keyboardLayouts: root.keyboardLayoutNames
    keyboardLayoutShortName: (root.keyboardLayout || "").substring(0, 2).toUpperCase()
    availableAnimations: root.availableAnimationsModel.getArray("fileBaseName")

    function mapMonitors() {
        return (Hyprland.monitors?.values ?? []).map(m => {
                const o = Object.assign({}, m.lastIpcObject ?? {});
                o.name = o.name ?? m.name ?? "";
                o.focused = m.focused ?? o.focused ?? false;
                return o;
            });
    }

    function mapWorkspaces() {
        return (Hyprland.workspaces?.values ?? []).map(w => {
                const o = Object.assign({}, w.lastIpcObject ?? {});
                o.id = o.id ?? w.id;
                o.name = o.name ?? w.name ?? String(o.id ?? "");
                o.monitor = o.monitor ?? w.monitor?.name ?? "";
                o.active = w.active ?? o.active ?? false;
                o.focused = w.focused ?? o.focused ?? false;
                return o;
            });
    }

    function mapWindows() {
        return (Hyprland.toplevels?.values ?? []).map(t => {
                const o = Object.assign({}, t.lastIpcObject ?? {});
                const address = String(o.address ?? "");
                o.address = address.startsWith("0x") ? address : `0x${address}`;
                o.class = o.class ?? t.wayland?.appId ?? "";
                o.title = o.title ?? t.title ?? "";
                o.focused = t.activated ?? o.focused ?? false;
                o.urgent = t.urgent ?? o.urgent ?? false;
                return o;
            });
    }

    function mapByAddress(windows) {
        const byAddress = {};
        for (const w of windows)
            byAddress[w.address] = w;
        return byAddress;
    }

    function mapActiveWorkspace() {
        const focused = Hyprland.focusedWorkspace;
        if (!focused)
            return null;
        const o = Object.assign({}, focused.lastIpcObject ?? {});
        o.id = focused.id ?? o.id;
        o.name = focused.name ?? o.name;
        return o;
    }

    function refreshKeyboardLayout() {
        keyboardLayoutProc.running = false;
        Qt.callLater(() => keyboardLayoutProc.running = true);
    }

    readonly property FolderListModel availableAnimationsModel: FolderListModel {
        folder: Paths.standard.config + "/hypr/core/animations/"
        nameFilters: ["*.lua"]
    }

    Connections {
        target: Hyprland

        function onEvent(event) {
            const name = event?.name ?? "";
            if (name === "activelayout" || name === "configreloaded")
                root.refreshKeyboardLayout();
        }
    }

    function switchKeyboardLayout() {
        Hyprland.dispatch("switchxkblayout current next");
    }

    function focusWs(ws) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws} })`);
    }

    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }

    function dispatch(cmd) {
        Hyprland.dispatch(cmd);
    }

    function windowForToplevel(t) {
        if (!t?.HyprlandToplevel)
            return null;
        return windowByAddress[`0x${t.HyprlandToplevel.address}`]
            ?? root.windowList.find(w => w.class === t.appId && w.title === t.title)
            ?? null;
    }

    function focusWindow(address) {
        if (address)
            Hyprland.dispatch(`hl.dsp.exec_raw("focuswindow address:${address}")`);
    }

    function moveWindowToTag(address, tag) {
        if (address) {
            Hyprland.dispatch(
                `hl.dsp.window.move({ workspace = ${tag}, window = "address:${address}", silent = true })`
            );
        }
    }

    function closeWindow(address) {
        if (address)
            Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${address}" })`);
    }

    Process {
        id: keyboardLayoutProc
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                let devices;
                try {
                    devices = JSON.parse(text);
                } catch (error) {
                    return;
                }
                const keyboards = devices?.keyboards ?? [];
                const keyboard = keyboards.find(k => k.main) ?? keyboards[0];
                if (!keyboard)
                    return;
                root.keyboardLayout = keyboard.active_keymap ?? "";
                root.keyboardLayoutNames = String(keyboard.layout ?? "")
                    .split(",")
                    .map(name => name.trim())
                    .filter(name => name.length > 0);
            }
        }
    }

    BatchBinding {
        target: Mem.hypr
        data: ({
                bar_location: () => BarData.position,
                bar_width: () => BarData.currentBarExclusiveSize,
                terminal_opacity: () => Mem.env.TERMINAL_OPACITY,
                rounding: () => Rounding.huge
            })
    }
}
