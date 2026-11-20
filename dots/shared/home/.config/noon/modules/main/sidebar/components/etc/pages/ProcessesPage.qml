import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import Noon.Utils

SidebarItemContainer {
    id: root

    readonly property TaskManager manager: TaskManager {}
    readonly property var procs: manager.processes

    property string searchQuery: ""
    property bool expanded: false

    function formatBytes(bytes) {
        if (bytes < 1024)
            return bytes + " B";
        if (bytes < 1048576)
            return (bytes / 1024).toFixed(0) + " KB";
        if (bytes < 1073741824)
            return (bytes / 1048576).toFixed(0) + " MB";
        return (bytes / 1073741824).toFixed(1) + " GB";
    }

    function stateColor(s) {
        if (s === "R")
            return Colors.colSuccess;
        if (s === "S" || s === "D")
            return Colors.colPrimary;
        if (s === "Z")
            return Colors.colError;
        if (s === "T")
            return Colors.colWarning;
        return Colors.colSubtext;
    }

    function stateIcon(s) {
        if (s === "R")
            return "play_circle";
        if (s === "S")
            return "pause_circle";
        if (s === "D")
            return "warning";
        if (s === "Z")
            return "dangerous";
        if (s === "T")
            return "stop_circle";
        return "circle";
    }

    onContentFocusRequested: {
        if (listView.count > 0) {
            listView.currentIndex = 0;
            listView.forceActiveFocus();
        }
    }

    StyledListView {
        id: listView
        anchors.fill: parent
        spacing: Padding.verysmall
        clip: true
        hint: true

        model: {
            if (!root.procs)
                return [];
            var q = root.searchQuery.trim().toLowerCase();
            var filtered = [];
            for (var i = 0; i < root.procs.length; i++) {
                var p = root.procs[i];
                if (q.length === 0 || p.name.toLowerCase().indexOf(q) >= 0 || String(p.pid).indexOf(q) >= 0
                        || p.user.toLowerCase().indexOf(q) >= 0) {
                    filtered.push(p);
                }
            }
            filtered.sort(function (a, b) {
                return b.cpuUsage - a.cpuUsage;
            });
            return filtered;
        }

        delegate: StyledRect {
            id: itemBg
            required property var modelData
            required property int index
            readonly property bool selected: listView.currentIndex === index
            anchors.left: parent?.left
            anchors.right: parent?.right
            implicitHeight: 65
            color: selected ? Colors.colLayer3 : Colors.colLayer2
            topRadius: (selected || index === 0) ? Rounding.verylarge : Rounding.tiny
            bottomRadius: (selected || index === listView.count - 1) ? Rounding.verylarge : Rounding.tiny

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Padding.huge
                anchors.rightMargin: Padding.huge
                spacing: Padding.huge

                Symbol {
                    iconSize: 24
                    text: root.stateIcon(modelData.state)
                    fill: 1
                    color: root.stateColor(modelData.state)
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Padding.verysmall

                    StyledText {
                        text: modelData.name
                        font: Fonts.request("main", Fonts.sizes.normal, {
                                                weight: Font.Medium
                                            })
                        color: Colors.colOnLayer2
                        truncate: true
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: Padding.normal

                        StyledText {
                            Layout.fillWidth: true
                            text: "PID: " + modelData.pid
                            font.pixelSize: Fonts.sizes.small
                            color: Colors.colSubtext
                        }

                        StyledText {
                            text: modelData.cpuUsage.toFixed(1) + "%"
                            font: Fonts.request("main", Fonts.sizes.small, {
                                                    weight: Font.DemiBold
                                                })
                            color: modelData.cpuUsage > 50 ? Colors.colError : Colors.colOnLayer2
                        }

                        StyledText {
                            text: root.formatBytes(modelData.memoryUsage)
                            font: Fonts.request("main", Fonts.sizes.small, {
                                                    weight: Font.DemiBold
                                                })
                            color: Colors.colOnLayer2
                        }
                    }
                }

                GroupButtonWithIcon {
                    materialIcon: "close"
                    implicitSize: 32
                    colBackground: Colors.colError
                    colSymbol: Colors.colOnError
                    colBackgroundHover: Colors.colErrorHover
                    releaseAction: () => root.manager.kill(modelData.pid)
                }
            }
        }

        PagePlaceholder {
            anchors.centerIn: parent
            shown: listView.count === 0
            title: "No Processes"
            icon: "check_circle"
            iconSize: 74
            description: root.searchQuery.length > 0 ? "No processes match your search" : ""
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Up) {
                if (currentIndex <= 0) {
                    currentIndex = -1;
                    root.searchFocusRequested();
                } else {
                    currentIndex--;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                if (currentIndex < count - 1) {
                    currentIndex++;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key
                       === Qt.Key_Delete) {
                if (currentIndex >= 0 && currentIndex < listView.count) {
                    root.manager.kill(listView.model[currentIndex].pid);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.dismiss();
                event.accepted = true;
            }
        }
    }

    Component.onCompleted: manager.refresh()
}
