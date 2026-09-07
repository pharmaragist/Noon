import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.functions
import qs.common.utils
import qs.common.widgets
import qs.services

QuickToggleButton {
    id: root
    dialogName: "Backlight"
    buttonIcon: BacklightService?.stats?.icon
    toggled: BacklightService.stats.current > 0
    onClicked: BacklightService.cycle()
}
