import QtQuick
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services

QuickToggleButton {
    id: root

    dialogName: "Performance"
    toggled: PowerService.currentMode === "performance"
    buttonIcon: PowerService.icon
    buttonName: PowerService.currentMode
    onClicked: PowerService.switchMode()
}
