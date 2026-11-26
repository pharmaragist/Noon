import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services

QuickToggleButton {
    id: root

    Component.onCompleted: {
        return NoonUtils.isProcRunning("easyeffects", answer => {
            root.toggled = answer;
        });
    }
    visible: Mem.store.misc.systemCommands.indexOf("easyeffects") !== -1
    buttonName: "EasyEffects"
    buttonIcon: "graphic_eq"
    onClicked: {
        if (toggled) {
            toggled = !toggled;
            NoonUtils.execDetached(["pkill", "easyeffects"]);
        } else {
            toggled = !toggled;
            NoonUtils.execDetached(["easyeffects", "--gapplication-service"]);
        }
    }
}
