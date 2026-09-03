import QtQuick
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services

QuickToggleButton {
    id: root

    dialogName: "Caffaine"
    toggled: Mem.options.services.idle.inhibit
    buttonIcon: "coffee"
    buttonName: toggled ? "Awake" : "Sleepy"
    onClicked: Mem.options.services.idle.inhibit = !Mem.options.services.idle.inhibit;
}
