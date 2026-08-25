import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: bg
    z: 9999
    clip: true

    property bool _expanded: false
    property bool isSearching: false
    property alias inputArea: inputArea

    onIsSearchingChanged: if (isSearching)
        inputArea.forceActiveFocus()
    inputArea.onFocusChanged: if (!inputArea.focus)
        isSearching = false

    anchors.margins: Padding.huge
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter

    radius: Rounding.silly
    color: colors.colLayer2
    colors: MediaPlayerService?.colors

    states: [
        State {
            name: "expanded"
            when: _expanded

            PropertyChanges {
                target: bg
                width: parent?.width - (anchors.margins * 2)
                height: 210
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

    HitsOptions {
        visible: bg._expanded
        anchors.bottom: group.top
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.left: parent.left

        anchors.leftMargin: Padding.huge
        anchors.rightMargin: Padding.huge
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
            text: BeatsService.hitsQuery
            onAccepted: BeatsService.search(inputArea.text)
        }

        Repeater {
            model: ScriptModel {
                values: {
                    const l = [
                        {
                            toggled: bg.isSearching,
                            icon: "search",
                            action: () => {
                                bg.isSearching = !bg.isSearching;
                            }
                        },
                        {
                            icon: Mem.states.services.beats.discoverMode ? "for_you" : "explore",
                            action: () => {
                                bg.isSearching = false;
                                Mem.states.services.beats.discoverMode = !Mem.states.services.beats.discoverMode;
                                BeatsService.feed();
                            }
                        },
                        {
                            icon: "refresh",
                            action: () => {
                                bg.isSearching = false;
                                BeatsService.feed();
                            }
                        },
                        {
                            icon: "menu",
                            action: () => bg._expanded = !bg._expanded
                        },
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
