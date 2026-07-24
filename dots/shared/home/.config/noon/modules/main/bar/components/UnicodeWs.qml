import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.services
import qs.common.widgets

BarGroup {
    id: root
    property var bar

    readonly property int maxWorkspaces: Mem.options.bar.workspaces.number ?? 6
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / maxWorkspaces)
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar.screen)
    readonly property string mode: Mem.options.bar.workspaces?.unicodeMode ?? "unicode"
    readonly property var modeMap: {
        "unicode": unicodeComp,
        "rect": rectComp
    }

    implicitWidth: grid.implicitWidth + Padding.verylarge
    implicitHeight: grid.implicitHeight + Padding.verylarge

    MouseArea {
        anchors.fill: parent
        onWheel: event => {
            const dir = event.angleDelta.y < 0 ? "+1" : "-1";
            HyprlandService.focusWs(`r${dir}`);
        }
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : maxWorkspaces
        rows: root.vertical ? maxWorkspaces : 1
        columnSpacing: Padding.small
        rowSpacing: Padding.small

        Repeater {
            model: maxWorkspaces
            StyledLoader {
                sourceComponent: modeMap[root.mode]
                onLoaded: {
                    _item.wsId = Qt.binding(() => root.workspaceGroup * root.maxWorkspaces + index + 1);
                    _item.isActive = Qt.binding(() => root.monitor.activeWorkspace?.id === _item.wsId);
                    _item.isVertical = Qt.binding(() => root.vertical);
                }
            }
        }
    }
    readonly property Component unicodeComp: StyledText {
        property int wsId: -1
        property bool isActive: false
        property bool isVertical: false
        width: root.width
        height: 18
        font: Fonts.request("mono", 22)
        color: isActive ? Colors.colPrimary : Colors.colOnLayer0
        opacity: isActive ? 1.0 : 0.4
        horizontalAlignment: Text.AlignHCenter
        text: Mem.options.bar.workspaces.unicodeChar
        MouseArea {
            anchors.fill: parent
            onClicked: HyprlandService.focusWs(wsId)
        }
    }
    readonly property Component rectComp: StyledRect {
        property int wsId: -1
        property bool isActive: false
        property bool isVertical: false
        readonly property int inActiveSize: root.barSize / 2
        readonly property int activeSize: root.barSize

        implicitWidth: !isVertical && isActive ? activeSize : inActiveSize
        implicitHeight: isVertical && isActive ? activeSize : inActiveSize

        radius: Rounding.large
        opacity: isActive ? 1.0 : 0.4
        color: isActive ? Colors.colPrimary : Colors.colLayer4

        MouseArea {
            anchors.fill: parent
            onClicked: HyprlandService.focusWs(wsId)
        }
    }
}
