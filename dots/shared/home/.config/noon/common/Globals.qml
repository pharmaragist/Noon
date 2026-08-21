pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import qs.common.utils
import qs.common.widgets
import qs.services

Singleton {
    id: root

    property bool deload: false
    property bool superPressed: superHeldShortcut.pressed
    readonly property var topLevel: ToplevelManager.activeToplevel
    readonly property bool superHeld: superHeldShortcut.pressed
    readonly property IdleMonitor idleMonitor: IdleMonitor {
        timeout: Mem.options.services.idle.timeOut
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && !Mem.options.services.idle.inhibit && !(Globals.topLevel?.fullscreen ?? false))
            Globals.main.locked = true
    }

    function handle_init(mode) {
        FirstRunService.setup();
        NightLightService.reload();
        NoonUtils.playSound("device_unlocked");
        ScreenTimeService.tracker.init(root);
        TimerService.reload();
        ClipboardService.refresh();
        console.log(mode.toUpperCase() + " Initialized");
    }

    readonly property QtObject common: QtObject {
        readonly property QtObject toasts: QtObject {
            property var data: []
        }

        readonly property GamePadLongPress _longPress: GamePadLongPress {
            gamepad: GamePadService.main
            _watchButton: "MenuStart"
            onTriggered: Globals.common.openGameUI = true
        }
        property bool openGameUI: false
    }

    readonly property QtObject applications: QtObject {
        property QtObject mediaplayer: QtObject {
            property bool show: false
            property var queue: []
        }
        property QtObject reader: QtObject {
            property bool show: false
            property string currentPath: Qt.resolvedUrl(Paths.standard.documents)

            property var document_page_view
        }
        property QtObject editor: QtObject {
            property bool show: false
            property string currentPath: Qt.resolvedUrl(Paths.shellConfigs)
            property string currentFile: ""
        }
    }

    readonly property QtObject main: QtObject {

        property var sidebar
        property var sidebarTempItem
        property var lock
        property var dock

        property bool locked: false
        property bool exposeView: false
        property bool showOsdValues: false
        property bool showBgOverview: false
        property bool showScreenshot: false
        property bool canNotify: sidebar?.hoverMode ?? true

        property QtObject beam: QtObject {
            property bool show: false
            property string reason: "default"
        }

        property QtObject clipboard: QtObject {
            property string mode: ""
        }

        property QtObject dmenu: QtObject {
            property var items
            property var action
        }

        property QtObject sysDialogs: QtObject {
            property string mode
            property var pendingData
        }

        property QtObject dialogs: QtObject {
            property string current: ""
        }
    }

    readonly property QtObject xp: QtObject {

        property bool locked: false

        property bool showRun: false
        property bool showStartMenu: false
        property bool showControlPanel: false
    }

    readonly property QtObject nobuntu: QtObject {

        property QtObject db: QtObject {
            property bool show: false
        }

        property QtObject clipboard: QtObject {
            property bool show: false
        }

        property QtObject overview: QtObject {
            property bool show: false
        }

        property QtObject notifs: QtObject {
            property bool show: false
        }
    }

    CustomShortcut {
        id:superHeldShortcut
        name: "superHeld"
    }

    Connections {
        target: Quickshell

        Component.onCompleted: {
            Globals.deload = false
        }

        function onReloadFailed(error) {
            let lines = error.split('\n');
            let lastLine = lines[lines.length - 1];
            root.toast({
                id: 0,
                content: lastLine,
                status: "error",
                title: "Quickshell"
            });
        }
    }
}
