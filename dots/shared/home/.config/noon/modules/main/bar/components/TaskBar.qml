import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

import qs.services
import qs.common
import qs.common.widgets

BarGroup {
    id: root

    implicitWidth: Math.max(listView.contentWidth + Padding.silly, 400)
    implicitHeight: Math.max(listView.contentHeight + Padding.silly, 400)

    ListView {
        id: listView
        spacing: 4
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        interactive: false
        anchors.fill: parent

        model: ScriptModel {
            values: {
                const pinned = Mem.states.favorites.apps.map(app => app.appId) ?? [];
                const values = [];
                const pinnedSet = new Set();

                for (const appId of pinned) {
                    const id = appId.toLowerCase();
                    pinnedSet.add(id);
                    values.push({
                        appId: id,
                        pinned: true,
                        toplevels: ToplevelManager.toplevels.values.filter(t => t.appId.toLowerCase() === id)
                    });
                }

                const unpinnedApps = ToplevelManager.toplevels.values.filter(t => !pinnedSet.has(t.appId.toLowerCase()));

                if (pinned.length > 0 && unpinnedApps.length > 0) {
                    values.push({
                        appId: root.vertical ? "SEPARATOR" : "VERTICALSEPARATOR",
                        pinned: false,
                        toplevels: []
                    });
                }

                const seen = new Set();
                for (const toplevel of unpinnedApps) {
                    const id = toplevel.appId.toLowerCase();
                    if (!seen.has(id)) {
                        seen.add(id);
                        values.push({
                            appId: id,
                            pinned: false,
                            toplevels: unpinnedApps.filter(t => t.appId.toLowerCase() === id)
                        });
                    }
                }

                return values;
            }
        }
        delegate: DelegateChooser {
            role: "appId"
            DelegateChoice {
                roleValue: "SEPARATOR"
                Separator {
                    anchors {
                        margins: 8
                        verticalCenter: parent.verticalCenter
                        right: parent.right
                        left: parent.left
                    }
                }
            }
            DelegateChoice {
                roleValue: "VERTICALSEPARATOR"
                VerticalSeparator {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        margins: 8
                        horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            DelegateChoice {
                RippleButton {
                    id: rippleRoot

                    required property var modelData
                    property var appToplevel: modelData
                    colBackground: appIsActive ? colBackgroundHover : "transparent"
                    anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Rounding.normal
                    padding: 0
                    topPadding: 0
                    bottomPadding: 0
                    leftPadding: 0
                    rightPadding: 0

                    property int lastFocused: -1
                    readonly property real iconSize: 30
                    readonly property bool appIsActive: appToplevel.toplevels.find(t => t.activated == true) !== undefined

                    readonly property var desktopEntry: DesktopEntries?.byId(appToplevel.appId)

                    MouseArea {
                        id: mouseArea
                        enabled: appToplevel.toplevels.length > 0
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: lastFocused = appToplevel.toplevels.length - 1
                    }
                    StyledToolTip {
                        content: rippleRoot?.desktopEntry?.name ?? ""
                        extraVisibleCondition: parent.hovered && content !== ""
                    }
                    onClicked: {
                        if (appToplevel.toplevels.find(item => item.id === appToplevel.toplevels[lastFocused].id)) {
                            appToplevel.toplevels[lastFocused].activate();
                            return;
                        } else {
                            rippleRoot.desktopEntry?.execute();
                            lastFocused = (lastFocused + 1) % appToplevel.toplevels.length;
                        }
                    }

                    middleClickAction: () => {
                        rippleRoot.desktopEntry?.execute();
                    }

                    contentItem: Item {
                        IconImage {
                            id: icon
                            anchors.centerIn: parent
                            source: NoonUtils.iconPath(AppSearch.guessIcon(appToplevel.appId))
                            implicitSize: rippleRoot.iconSize
                        }

                        RowLayout {
                            spacing: 2
                            anchors {
                                bottom: parent.bottom
                                bottomMargin: 2
                                horizontalCenter: parent.horizontalCenter
                            }
                            Repeater {
                                model: Math.min(appToplevel.toplevels.length, 3)
                                delegate: StyledRect {
                                    required property int index
                                    radius: Rounding.full
                                    implicitWidth: (appToplevel.toplevels.length <= 3) ? (icon.width - Padding.small) / appToplevel.toplevels.length : height
                                    implicitHeight: 2
                                    color: appIsActive ? Colors.colPrimary : Colors.t(Colors.colOnLayer0, 0.4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
