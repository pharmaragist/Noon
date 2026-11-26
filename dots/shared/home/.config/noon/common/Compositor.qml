pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.utils
import "compositors"

Singleton {
    id: root

    readonly property bool isHyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""
    readonly property bool isMango: (Quickshell.env("MANGO_INSTANCE_SIGNATURE") ?? "") !== ""
    readonly property bool isNiri: (Quickshell.env("NIRI_SOCKET") ?? "") !== ""

    readonly property Item protocol: _loader?._item
    readonly property var currentInfo: compositors.find(wm => (Quickshell.env(wm.signature ?? "") ?? "").length > 0)
    readonly property var compositors: [
        {
            name: "hyprland",
            signature: "HYPRLAND_INSTANCE_SIGNATURE",
            protocol: "Hyprland",
            command: "start-hyprland",
            icon: Paths.assets + "/icons/hyprland-symbolic.svg"
        },
        {
            name: "mango",
            signature: "MANGO_INSTANCE_SIGNATURE",
            protocol: "Mango",
            command: "mango",
            icon: Paths.assets + "/icons/mango-symbolic.svg"
        },
        {
            name: "niri",
            signature: "NIRI_SOCKET",
            protocol: "Niri",
            command: "niri",
            icon: Paths.assets + "/icons/niri-symbolic.svg"
        }
    ].filter(i => {
        return Mem.store.misc.systemCommands.indexOf(i.command) !== -1;
    })
    readonly property string currentEnv: Mem.env.COMPOSITOR

    onCurrentEnvChanged: if (currentEnv && currentEnv !== currentInfo.command) {
        NoonUtils.requestDialog("assure", {
            title: "Switch Session to " + currentEnv,
            description: "For changes to take Effect",
            acceptText: "Accept",
            onAccepted: () => {
                NoonUtils.inlineStdProc([Paths.scripts.killSession]);
            },
            onCanceled: () => Mem.env.COMPOSITOR = currentInfo.command
        });
    }

    StyledLoader {
        id: _loader
        active: true
        source: Qt.resolvedUrl("compositors/") + root.currentInfo.protocol + ".qml"
        onLoaded: Mem.env.COMPOSITOR = root.currentInfo.command
    }

    readonly property var monitors: protocol.monitors ?? []
    readonly property var windowList: protocol.windowList ?? []
    readonly property var workspaces: protocol.workspaces ?? []
    readonly property var windowByAddress: protocol.windowByAddress ?? ({})
    readonly property var activeWorkspace: protocol.activeWorkspace ?? null
    readonly property var focusedWorkspace: protocol.focusedWorkspace ?? null
    readonly property var focusedMonitor: protocol.focusedMonitor ?? null
    readonly property var currentKeyboardLayout: protocol.currentKeyboardLayout ?? ""
    readonly property var keyboardLayouts: protocol.keyboardLayouts ?? []
    readonly property var keyboardLayoutShortName: protocol.keyboardLayoutShortName ?? ""
    readonly property var availableAnimations: protocol.availableAnimations ?? []

    readonly property IdleMonitor idleMonitor: IdleMonitor {
        timeout: Mem.options.services.idle.timeOut
        respectInhibitors: true
        onIsIdleChanged: {
            if (this.isIdle && !Mem.options.services.idle.inhibit && !(Globals.topLevel?.fullscreen ?? false))
                Globals.main.locked = true;
        }
    }

    function switchKeyboardLayout() {
        protocol.switchKeyboardLayout();
    }

    function focusWs(ws) {
        protocol.focusWs(ws);
    }

    function monitorFor(screen) {
        return protocol ? protocol.monitorFor(screen) : null;
    }

    function dispatch(cmd) {
        protocol.dispatch(cmd);
    }

    function windowForToplevel(t) {
        return protocol ? protocol.windowForToplevel(t) : null;
    }

    function focusWindow(address) {
        protocol.focusWindow(address);
    }

    function moveWindowToTag(address, tag) {
        protocol.moveWindowToTag(address, tag);
    }

    function closeWindow(address) {
        protocol.closeWindow(address);
    }
}
