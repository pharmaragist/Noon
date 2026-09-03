import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.data

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
                edges: Edges.Bottom
                gravity: Edges.Bottom
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
        colorize: Mem?.options.appearance.icons.tint
        source: root.item.icon
        anchors.centerIn: parent
        implicitSize: root.implicitSize
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: {
            switch (BarData.currentInfo.position) {
            case "top":
                return Edges.Bottom;
            case "bottom":
                return Edges.Top;
            case "left":
                return Edges.Right;
            case "right":
                return Edges.Left;
            }
        }
    }
}
