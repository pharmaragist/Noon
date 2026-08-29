import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.store

MouseArea {
    id: root
    required property SystemTrayItem item
    property bool targetMenuOpen: false
    property int implicitSize: 20

    signal menuOpened(qsWindow: var)
    signal menuClosed

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: implicitSize
    implicitHeight: implicitSize
    onPressed: event => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) {
                menu.active = !menu.active;
                if (menu.active)
                    menu.open();
            }
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        tooltip.text = item.tooltipTitle.length > 0 ? item.tooltipTitle : (item.title.length > 0 ? item.title : item.id);
        if (item.tooltipDescription.length > 0)
            tooltip.text += " • " + item.tooltipDescription;
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open()
            trayItemMenuHandle: root.item.menu
            anchor {
                item: root
                edges: Mem.options.bar.behavior.position === "bottom" ? (Edges.Top | Edges.Left) : (Edges.Bottom | Edges.Right)
                gravity: Mem.options.bar.behavior.position === "bottom" ? (Edges.Top | Edges.Left) : (Edges.Bottom | Edges.Right)
            }

            onMenuOpened: window => root.menuOpened(window)
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    StyledIconImage {
        id: trayIcon
        tint: 0.5
        source: root.item.icon
        anchors.centerIn: parent
        implicitSize: root.implicitSize
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: {
            const pairs = {
                 "top": "Bottom",
                 "bottom": "Top",
                 "left": "Right",
                 "right": "Left"
            }
            return Edges[pairs[BarData.position]]
        }
    }
}
