import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common

ColumnLayout {
    id: root

    required property var tabButtonList 
    required property var externalTrackedTab
    property bool enableIndicatorAnimation: false
    property color colIndicator: colors.colPrimary ?? "#65558F"
    property bool centerTabBar: parent.width > 500
    property alias currentIndex: tabBar.currentIndex
    property var colors: Colors
    spacing: Padding.tiny
    Layout.fillWidth: !centerTabBar
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: Math.max(tabBar.implicitWidth, 600)

    TabBar {
        id: tabBar

        Layout.fillWidth: true
        currentIndex: root.externalTrackedTab

        Repeater {
            model: root.tabButtonList

            delegate: PrimaryTabButton {
                selected: (index == root.externalTrackedTab)
                buttonText: modelData.name
                buttonIcon: modelData.icon
                minimumWidth: 160
            }
        }

        background: Item {
            WheelHandler {
                onWheel: event => {
                    if (event.angleDelta.y < 0)
                        tabBar.currentIndex = Math.min(tabBar.currentIndex + 1, root.tabButtonList.length - 1);
                    else if (event.angleDelta.y > 0)
                        tabBar.currentIndex = Math.max(tabBar.currentIndex - 1, 0);
                }
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            }
        }
    }

    
    Item {
        id: tabIndicator

        Layout.fillWidth: true
        height: 3

        Connections {
            function onExternalTrackedTabChanged() {
                root.enableIndicatorAnimation = true;
            }

            target: root
        }

        Rectangle {
            id: indicator
            property int tabCount: root.tabButtonList.length
            property real fullTabSize: tabCount > 0 ? root.width / tabCount : 0
            property var currentButton: {
                const col = tabBar.contentItem.children[0];
                if (!col || tabBar.currentIndex < 0 || tabBar.currentIndex >= col.children.length)
                    return null;
                return col.children[tabBar.currentIndex];
            }
            property real targetWidth: currentButton?.tabContentWidth ?? 0
            implicitWidth: targetWidth
            x: tabCount > 0 ? tabBar.currentIndex * fullTabSize + (fullTabSize - targetWidth) / 2 : 0
            color: root.colIndicator
            radius: Rounding.full ?? 9999
            anchors {
                top: parent.top
                bottom: parent.bottom
            }
            Behavior on x {
                Anim {}
            }
            Behavior on implicitWidth {
                Anim {}
            }
        }
    }

    Rectangle {
        visible: false
        Layout.fillWidth: true
        implicitHeight: 1
        color: Colors.m3.m3onSurfaceVariant
        opacity: 0.2
        Layout.margins: 6
        Layout.bottomMargin: 0
        Layout.topMargin: 0
    }
}
