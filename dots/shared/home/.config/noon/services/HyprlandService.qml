pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.data
import qs.common
import qs.common.utils

import Noon.Hypr
import Noon.Protocols.Hypr

Singleton {
    id: root

    readonly property HyprBridge bridge: HyprBridge {}
    readonly property bool isHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
    readonly property list<var> monitors: bridge.monitors
    readonly property list<var> windowList: bridge.windowList
    readonly property list<var> workspaces: bridge.workspaces
    readonly property var windowByAddress: bridge.windowByAddress
    readonly property var workspaceById: bridge.workspaceById
    readonly property var activeWorkspace: bridge.activeWorkspace
    readonly property string currentKeyboardLayout: bridge?.currentKeyboardLayout
    readonly property string keyboardLayoutShortName: currentKeyboardLayout.substring(0, 2).toUpperCase()
    readonly property list<string> availableAnimations: root.availableAnimationsModel.getArray("fileBaseName")

    readonly property ScreenTimeManager screenTimeManager: ScreenTimeManager {
        bridge: root.bridge ?? null
        dbPath: Paths.services.screenTimeDB
        saveInterval: 12000
        Component.onCompleted: this.init(root)
    }

    readonly property NightLightManager nightLightManager: NightLightManager {
        screen: MonitorsInfo?.monitors?.main ?? null
        enabled: Mem?.states.services.nightLight.enabled
        temperature: Mem?.states.services.nightLight.temperature
        gamma: Mem?.states.services.nightLight.gamma
    }

    readonly property FolderListModel availableAnimationsModel: FolderListModel {
        folder: Paths.standard.config + "/hypr/lua/animations/"
        nameFilters: ["*.lua"]
    }

    function switchKeyboardLayout() {
        NoonUtils.execDetached(["hyprctl", "switchxkblayout", "current", "next"]);
    }

    function focusWs(ws) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws} })`);
    }

    BatchBinding {
        target: Mem.hypr
        data: ({
                bar_location: () => BarData.currentInfo.position,
                bar_width: () => BarData.currentBarExclusiveSize,
                terminal_opacity: () => Mem.env.TERMINAL_OPACITY
            })
    }
}
