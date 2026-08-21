import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets

SidebarItemContainer {
    id: root
    readonly property var currentItem: Globals.main.sidebarTempItem

    Connections {
        target: panelWindow

        function onSelectedCategoryChanged() {
            if (!root.panelWindow.selectedCategory !== "Hints") {
                Globals.main.sidebarTempItem = null;
                console.warn("Hints: Destroyed")
            }
        }
    }

    StyledLoader {
        active: currentItem && currentItem !== null
        anchors.fill: parent
        sourceComponent: root.currentItem
        binds: ({
                "parent": () => root,
                "anchors.fill": () => root
            })
    }
}
