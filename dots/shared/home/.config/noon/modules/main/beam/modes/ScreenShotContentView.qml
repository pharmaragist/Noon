import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services
import qs.store

Item {
    id: root
    focus: true
    signal hide

    readonly property alias focusItem: tabBar
    readonly property bool isPendingArea: currentMode?.region === ScreenShotService.Regions.Part && !ScreenShotService.hasRegion
    readonly property var currentMode: modes[tabBar.currentIndex]
    readonly property bool reveal: Globals.main.showScreenshot
    readonly property list<var> modes: [
        {
            "name": "full",
            "icon": "screenshot_frame_2",
            "hint": "Take a full screenshot",
            "region": ScreenShotService.Regions.Full
        },
        {
            "name": "window",
            "icon": "ad",
            "hint": "Take a screenshot of an active window",
            "region": ScreenShotService.Regions.Window
        },
        {
            "name": "area",
            "icon": "screenshot_region",
            "hint": "Take a screenshot of a selected area",
            "region": ScreenShotService.Regions.Part
        }
    ]

    function execute() {
        if (root.currentMode.region === ScreenShotService.Regions.Part) {
            ScreenShotService.clearRegion();
            ScreenShotService.startRegionSelect();
        } else {
            ScreenShotService.request({
                region: root.currentMode.region,
                temp: false
            });
        }
        NoonUtils.inlineTimer(() => {
            root.hide();
        });
    }
    Keys.onReturnPressed: execute()

    StyledRect {
        id: bg
        anchors.centerIn: parent
        implicitHeight: contentRow?.implicitHeight + Padding.huge
        implicitWidth: contentRow?.implicitWidth + Padding.large * 2
        color: Colors.colLayer0
        radius: Rounding.full

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Padding.normal

            ToolbarTabBar {
                id: tabBar
                tabButtonList: root.modes
                currentIndex: 0
                tabButtonhorizontalPadding: Padding.large
                onCurrentIndexChanged: {
                    if (root.currentMode.region !== ScreenShotService.Regions.Part)
                        ScreenShotService.clearRegion();
                    if (currentIndex > 0)
                        Qt.callLater(() => execute());
                }
            }

            VerticalSeparator {
                Layout.margins: Padding.normal
            }

            GroupButtonWithIcon {
                materialIcon: "photo_camera"
                releaseAction: () => execute()
            }
        }
    }
}
