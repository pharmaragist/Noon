pragma ComponentBehavior: Bound

/*
 * Default compositor API. Backends inherit this and override only what their
 * window manager supports; everything else stays a safe stub.
 */

import QtQuick

Item {
    property var monitors: []
    property var windowList: []
    property var workspaces: []
    property var windowByAddress: ({})
    property var activeWorkspace: null
    property var focusedWorkspace: null
    property var focusedMonitor: null
    property var currentKeyboardLayout: ""
    property var keyboardLayouts: []
    property var keyboardLayoutShortName: ""
    property var availableAnimations: []

    function switchKeyboardLayout() {}

    function focusWs(ws) {}

    function monitorFor(screen) {
        return null;
    }

    function dispatch(cmd) {}

    function windowForToplevel(t) {
        return null;
    }

    function focusWindow(address) {}

    function moveWindowToTag(address, tag) {}

    function closeWindow(address) {}
}
