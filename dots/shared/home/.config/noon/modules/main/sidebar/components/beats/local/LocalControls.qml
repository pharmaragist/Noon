import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.services

StyledRect {
    id: bg
    z: 9999
    clip: true
    property string mode: ""
    property bool _expanded: mode !== ""
    property alias inputArea: inputArea
    property bool isSearching: false
    property bool listMode: false
    anchors.margins: Padding.huge
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    radius: Rounding.silly
    color: colors.colLayer2
    colors: MediaPlayerService?.colors
    onIsSearchingChanged: if (isSearching)
        inputArea.forceActiveFocus()
    inputArea.onFocusChanged: if (!inputArea.focus)
        isSearching = false

    states: [
        State {
            name: "expanded"
            when: _expanded

            PropertyChanges {
                target: bg
                width: parent?.width - (anchors.margins * 2)
                height: 125
            }
        },
        State {
            name: "collapsed"
            when: !_expanded

            PropertyChanges {
                target: bg
                width: bg?.isSearching ? 360 : group?.implicitWidth
                height: 60
            }
        }
    ]

    StyledLoader {
        readonly property var dict: {
            "folders": foldersComp
        }
        shown: bg._expanded
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: group.top
        sourceComponent: dict[mode]
        readonly property Component foldersComp: ListView {
            id: foldersList
            anchors.margins: Padding.large

            anchors.fill: parent
            orientation: Qt.Horizontal
            model: Mem.beats.folders.concat(["ADD"])
            spacing: Padding.small
            delegate: GroupButtonWithIcon {
                required property var modelData
                readonly property bool isAdd: modelData === "ADD"
                anchors.verticalCenterOffset: Padding.small
                anchors.verticalCenter: parent?.verticalCenter
                implicitSize: 55
                buttonRadius: Rounding.normal
                colBackground: bg.colors.colLayer3
                materialIcon: isAdd ? "add" : "folder"
                releaseAction: () => {
                    if (isAdd) {
                        BeatsService.addNewFolder();
                    } else {
                        BeatsService.switchToFolder(modelData);
                    }
                }
                altAction: () => {
                    if (!isAdd) {
                        let currentFolders = Mem.beats.folders;
                        let updatedFolders = currentFolders.filter(path => path !== modelData);
                        Mem.beats.folders = updatedFolders;
                    }
                }

                StyledToolTip {
                    extraVisibleCondition: parent.hovered
                    content: Paths.methods.getEscapedFileName(modelData)
                }
            }
        }
    }
    ButtonGroup {
        id: group

        implicitHeight: 60
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        anchors.leftMargin: Padding.small
        anchors.rightMargin: Padding.small

        StyledTextField {
            id: inputArea
            visible: bg.isSearching
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            focus: true
            height: 60
            color: bg.colors.colOnLayer3
            Layout.fillWidth: bg.isSearching
            background: null
        }

        Repeater {
            model: ScriptModel {
                values: {
                    const l = [
                        {
                            toggled: isSearching,
                            icon: "search",
                            action: () => {
                                isSearching = !isSearching;
                            }
                        },
                        {
                            icon: "shuffle",
                            toggled: Mem.states.services.beats.shuffleTracks,
                            action: () => {
                                Mem.states.services.beats.shuffleTracks = !Mem.states.services.beats.shuffleTracks;
                            }
                        },
                        {
                            icon: "refresh",
                            action: () => BeatsService.fetchLibrary()
                        },
                        {
                            icon: listMode ? "list" : "window",
                            action: () => listMode = !listMode
                        },
                        {
                            icon: "folder",
                            action: () => {
                                if (mode === "folders")
                                    mode = "";
                                else
                                    mode = "folders";
                            }
                        }
                    ];
                    return l.filter(b => b?.visible ?? true);
                }
            }
            delegate: GroupButtonWithIcon {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.fillHeight: false
                Layout.fillWidth: false
                toggled: modelData?.toggled ?? false
                colors: bg.colors
                baseSize: 38
                buttonRadiusPressed: Rounding.silly
                buttonRadius: 24
                materialIcon: modelData.icon
                releaseAction: () => modelData.action()
            }
        }
    }
}
