import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.services
import qs.data

NpcHandler {
    target: "xp"

    //* Show/hide the Run dialog.
    function toggle_run() {
        Globals.xp.showRun = !Globals.xp.showRun;
    }
    //* Show/hide the XP control panel.
    function toggle_settings() {
        Globals.xp.showControlPanel = !Globals.xp.showControlPanel;
    }
    //* Show/hide the XP start menu.
    function toggle_start_menu() {
        Globals.xp.showStartMenu = !Globals.xp.showStartMenu;
    }
}
