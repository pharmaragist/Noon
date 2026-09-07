import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import qs.data

FloatingWindow {
    id: root
    title: "Fonts"
    minimumSize: Qt.size(365, 425)
    maximumSize: Qt.size(365, 425)
    color: Colors.m3.m3surface
    readonly property int mainRounding: Mem.hypr.rounding
    function dismiss() {
        root.destroy();
    }

    onVisibleChanged: if (!visible)
        root.destroy()

    Shortcut {
        sequences: ["Ctrl+F", "/"]
        onActivated: {
            searchField.forceActiveFocus();
            searchField.selectAll();
        }
    }

    Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.topMargin: Padding.normal
                Layout.rightMargin: Padding.huge
                Layout.leftMargin: Padding.huge
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: Padding.normal

                Symbol {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "font_download"
                    iconSize: 18
                    color: Colors.m3.m3onSurfaceVariant
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    text: "Choose Font"
                    font: Fonts.request("title", "normal")
                    color: Colors.m3.m3onSurface
                }

                RippleButtonWithIcon {
                    implicitSize: 25
                    buttonRadius: Rounding.normal
                    materialIcon: "refresh"
                    downAction: () => {
                        fetcher.refresh();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: Padding.huge
                Layout.leftMargin: Padding.huge
                Layout.preferredHeight: 50

                Symbol {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "search"
                    iconSize: 18
                    color: Colors.m3.m3onSurfaceVariant
                }

                StyledTextField {
                    id: searchField
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    placeholderText: "Search"
                    font: Fonts.request("main", "large")
                    color: Colors.m3.m3onSurface
                    background: null
                    focus: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            list.forceActiveFocus();
                            if (list.currentIndex < 0 && list.count > 0) {
                                list.currentIndex = 0;
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (list.count > 0) {
                                const currentItem = list.model.values[list.currentIndex >= 0 ? list.currentIndex : 0];
                                if (currentItem) {
                                    Fonts.changeSystemFont(currentItem);
                                    root.dismiss();
                                }
                            }
                            event.accepted = true;
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colors.m3.m3surfaceContainer
                topRadius: root.mainRounding

                StyledListView {
                    id: list
                    clip: true
                    radius: root.mainRounding - anchors.margins
                    anchors.fill: parent
                    anchors.margins: Padding.normal
                    focus: true
                    keyNavigationWraps: true
                    highlightMoveDuration: 200

                    hinter {
                        color: Colors.m3.m3surfaceContainer
                        anchors.margins: -Padding.normal
                    }

                    highlight: Item {
                        width: list.width
                        height: 50
                        z: 2

                        StyledRect {
                            width: 4
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Padding.small
                            color: Colors.m3.m3primary
                            radius: 2
                        }

                        Behavior on y {
                            SpringAnimation {
                                spring: 3
                                damping: 0.2
                                epsilon: 0.25
                            }
                        }
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            if (list.currentIndex >= 0 && list.currentIndex < list.count) {
                                const selectedFont = list.model.values[list.currentIndex];
                                if (selectedFont) {
                                    Fonts.changeSystemFont(selectedFont);
                                    root.dismiss();
                                }
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up && list.currentIndex === 0) {
                            searchField.forceActiveFocus();
                            event.accepted = true;
                        }
                    }

                    model: ScriptModel {
                        values: {
                            const query = searchField.text;
                            if (!fetcher.data)
                                return [];

                            const all = fetcher.data;
                            const prepared = all.map(i => ({
                                        id: i,
                                        name: Fuzzy.prepare(i)
                                    }));

                            const results = Fuzzy.go(query, prepared, {
                                all: true,
                                key: "name"
                            });

                            return results.map(r => r?.obj?.id);
                        }
                    }

                    delegate: StyledRect {
                        id: delegateRoot
                        color: mouseArea.containsMouse ? Colors.m3.m3surfaceContainerHighest : Colors.m3.m3surfaceContainerHigh
                        topRadius: index === 0 ? root.mainRounding - Padding.normal : 2
                        bottomRadius: index === list.count - 1 ? root.mainRounding - Padding.normal : 2

                        anchors.left: parent?.left
                        anchors.right: parent?.right
                        implicitHeight: 50

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = index
                            onClicked: {
                                list.currentIndex = index;
                                list.forceActiveFocus();
                                Fonts.changeSystemFont(modelData);
                                root.dismiss();
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent?.left
                            anchors.right: parent?.right
                            anchors.leftMargin: Padding.massive
                            anchors.margins: Padding.huge
                            text: modelData
                            color: Colors.m3.m3onSurface
                            font.family: modelData
                            font.pixelSize: 20
                        }
                    }
                }
            }
        }
    }

    Fetcher {
        id: fetcher
        command: ["bash", "-c", Paths.scriptsDir + "/get_fonts.sh"]
    }
}
