import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

import qs.data
import qs.services
import qs.common
import qs.common.widgets

BarGroup {
    id: root
    property var bar
    property list<bool> workspaceOccupied: []

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(bar?.screen)
    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - 1) / number)
    readonly property int workspaceIndexInGroup: (monitor?.activeWorkspace?.id - 1) % number


    readonly property int number: Mem.options.bar.workspaces.number
    readonly property bool showBigAppOnly: Mem.options.bar.workspaces.showBigAppOnly ?? false
    readonly property bool genericSymbols: Mem.options.bar.workspaces.genericSymbols ?? false

    readonly property int workspaceButtonWidth: 26
    readonly property real baseIconSize: workspaceButtonWidth * 0.69
    readonly property real shrinkedIconSize: workspaceButtonWidth * 0.55
    readonly property real shrinkedIconMargin: -4
    readonly property int buttonMargin: 2
    readonly property real iconSpacing: 3
    readonly property int buttonHPadding: 4
    readonly property real bgPadding: Padding.large
    readonly property real bgVPadding: Padding.normal

    vertical: false
    implicitWidth: buttonsRow.implicitWidth + 2 * bgVPadding
    implicitHeight: buttonsRow.implicitHeight

    function xAt(i) {
        if (i <= 0)
            return buttonsRow.x + (buttonsRepeater.itemAt(0)?.x ?? 0);
        const k = Math.min(Math.floor(i), number - 1);
        const btn = buttonsRepeater.itemAt(k);
        if (!btn)
            return 0;
        return buttonsRow.x + btn.x + (i - k) * btn.width;
    }

    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({
            length: number
        }, (_, i) => Hyprland.workspaces.values.some(ws => ws.id === workspaceGroup * number + i + 1));
    }

    Component.onCompleted: updateWorkspaceOccupied()

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateWorkspaceOccupied();
        }
    }

    WheelHandler {
        onWheel: event => HyprlandService.focusWs(`r${event.angleDelta.y < 0 ? '+' : '-'}1`)
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: HyprlandService.focusWs("special")
    }

    Repeater {
        model: root.number

        StyledRect {
            readonly property var targetButton: buttonsRepeater?.itemAt(index ?? 0)
            readonly property int workspaceId: root.workspaceGroup * root.number + index + 1
            readonly property bool isOccupied: HyprlandService.windowList.some(w => w.workspace?.id === workspaceId)
            readonly property bool adjacentOccupiedLeft: index === 0 ? false : HyprlandService.windowList.some(w => w.workspace?.id === workspaceId - 1)
            readonly property bool adjacentOccupiedRight: index === root.number - 1 ? false : HyprlandService.windowList.some(w => w.workspace?.id === workspaceId + 1)

            z: 1
            height: 34 * 0.8
            x: targetButton ? buttonsRow.x + targetButton.x : 0
            width: targetButton ? targetButton.width : 0
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.colLayer3Hover
            opacity: isOccupied ? 1 : 0
            leftRadius: adjacentOccupiedLeft ? 0 : Rounding.full
            rightRadius: adjacentOccupiedRight ? 0 : Rounding.full
        }
    }

    Rectangle {
        z: 2
        height: root.workspaceButtonWidth - root.buttonMargin * 2
        anchors.verticalCenter: parent.verticalCenter

        property real idx1: root.workspaceIndexInGroup
        property real idx2: root.workspaceIndexInGroup

        x: root.xAt(Math.min(idx1, idx2)) + root.buttonMargin
        width: Math.max(0, root.xAt(Math.max(idx1, idx2) + 1) - root.xAt(Math.min(idx1, idx2)) - root.buttonMargin * 2)
        radius: Rounding.full
        color: Colors.colPrimary

        Behavior on idx1 {
            Anim {
                duration: Animations.durations.small
            }
        }
        Behavior on idx2 {
            Anim {
                duration: Animations.durations.large
            }
        }
    }

    RowLayout {
        id: buttonsRow
        z: 3
        spacing: 0
        implicitHeight: 40

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            leftMargin: root.bgVPadding
            rightMargin: root.bgVPadding
        }

        Repeater {
            id: buttonsRepeater
            model: root.number

            Button {
                id: button
                readonly property int workspaceValue: root.workspaceGroup * root.number + index + 1
                readonly property string displayText: WsData.getDisplayText(workspaceValue)
                readonly property string currentMode: WsData.currentMode
                readonly property bool isActive: monitor.activeWorkspace?.id === workspaceValue

                readonly property var windows: {
                    const inWs = HyprlandService.windowList.filter(w => w.workspace?.id === workspaceValue && w.class);
                    if (root.showBigAppOnly) {
                        const counts = {};
                        for (const w of inWs)
                            counts[w.class] = (counts[w.class] ?? 0) + 1;
                        let bestClass = null, bestCount = 0;
                        for (const cls in counts)
                            if (counts[cls] > bestCount) { bestClass = cls; bestCount = counts[cls]; }
                        if (!bestClass)
                            return [];
                        return inWs.filter(w => w.class === bestClass).slice(0, 1);
                    }
                    const out = [];
                    const perClass = {};
                    for (const w of inWs) {
                        const n = perClass[w.class] ?? 0;
                        if (n >= 3)
                            continue;
                        perClass[w.class] = n + 1;
                        out.push(w);
                    }
                    return out;
                }

                readonly property int windowCount: windows.length
                readonly property var windowCountFor: (cls) => cls ? HyprlandService.windowList.filter(w => w.workspace?.id === workspaceValue && w.class === cls).length : 0
                readonly property bool showNumber: Mem.options.bar.workspaces.alwaysShowNumbers || Globals.superHeld || windowCount === 0
                readonly property real iconSize: showNumber ? root.shrinkedIconSize : root.baseIconSize
                readonly property real buttonWidth: Math.max(root.workspaceButtonWidth, windowCount * iconSize + Math.max(0, windowCount - 1) * (showNumber ? 0 : root.iconSpacing) + root.buttonHPadding) + (windowCount > 1 ? root.bgPadding : 0)

                Layout.fillHeight: true
                width: buttonWidth
                onPressed: HyprlandService.focusWs(workspaceValue)

                background: Item {
                    implicitWidth: button.buttonWidth
                    implicitHeight: root.workspaceButtonWidth

                    Symbol {
                        readonly property color textColor: button.isActive ? Colors.colOnPrimary : (root.workspaceOccupied[index] ? Colors.colOnSecondaryContainer : Colors.colOnLayer1Inactive)

                        fill: 1
                        opacity: button.showNumber ? 0.8 : 0
                        anchors.centerIn: parent
                        font: Fonts.request("numbers", WsData.getFontPixelSize(button.currentMode, button.displayText))
                        text: button.displayText
                        color: textColor
                        horizontalAlignment: Qt.AlignCenter

                        Behavior on opacity {
                            Anim {}
                        }
                    }

                    Item {
                        readonly property real offsetMultiplier: button.showNumber ? 2 * root.shrinkedIconMargin : 0

                        implicitWidth: iconsRow.implicitWidth
                        implicitHeight: iconsRow.implicitHeight

                        anchors {
                            centerIn: parent
                            verticalCenterOffset: button.showNumber ? -offsetMultiplier : 0
                            horizontalCenterOffset: button.showNumber ? -offsetMultiplier : 0
                        }
                        opacity: button.windowCount > 0 ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            Anim {}
                        }

                        RowLayout {
                            id: iconsRow
                            anchors.fill: parent
                            spacing: button.showNumber ? 0 : root.iconSpacing

                            Repeater {
                                model: button.windows

                                Item {
                                    readonly property var windowData: modelData
                                    readonly property int windowCount: button.windowCountFor(windowData.class)
                                    readonly property bool isLastOfClass: {
                                        for (let i = index + 1; i < button.windows.length; i++)
                                            if (button.windows[i].class === windowData.class)
                                                return false;
                                        return true;
                                    }
                                    readonly property real badgeSize: Math.max(10, button.iconSize * 0.62)
                                    readonly property string genericSymbol: root.genericSymbols ? SymbolsData.getGenericAppSymbolFor(windowData.class) : ""
                                    readonly property var desktopEntry: DesktopEntries?.byId(windowData.class)

                                    implicitWidth: button.iconSize
                                    implicitHeight: button.iconSize
                                    Layout.alignment: Qt.AlignVCenter

                                    StyledIconImage {
                                        anchors.fill: parent
                                        visible: genericSymbol === ""
                                        source: windowData?.class ? NoonUtils.iconPath(desktopEntry?.genericIcon || desktopEntry?.icon || "applications-system") : ""
                                        tint: 0.4
                                    }

                                    Symbol {
                                        anchors.fill: parent
                                        visible: genericSymbol !== ""
                                        text: genericSymbol
                                        iconSize: button.iconSize * 0.72
                                        color: button.isActive ? Colors.colOnPrimary : Colors.colOnSecondaryContainer
                                        horizontalAlignment: Qt.AlignHCenter
                                        verticalAlignment: Qt.AlignVCenter
                                    }

                                    Rectangle {
                                        visible: !root.showBigAppOnly && windowCount > 3 && isLastOfClass
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        width: badgeSize
                                        height: badgeSize
                                        radius: badgeSize / 2
                                        color: Colors.colPrimary

                                        Symbol {
                                            anchors.fill: parent
                                            text: "more_horiz"
                                            iconSize: badgeSize * 0.7
                                            color: Colors.colOnPrimary
                                            horizontalAlignment: Qt.AlignHCenter
                                            verticalAlignment: Qt.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: iconHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                CurrentAppPopUp {
                    hoverTarget: iconHoverArea
                    workspaceId: button.workspaceValue
                }
            }
        }
    }
}
