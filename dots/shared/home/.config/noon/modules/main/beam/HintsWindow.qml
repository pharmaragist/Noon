import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.common.functions
import qs.services
import qs.store

AppWindow {
    id: root
    visible: true
    maximumSize: Qt.size(450, 800)
    minimumSize: Qt.size(450, 800)
    title: "Beam Cheats"

    readonly property var current: BeamData.config
    readonly property var array: {
        const reg = BeamData.registry;
        var map = [];

        for (const [key, cfg] of Object.entries(reg)) {
            if (!!cfg.description)
                map.push(Object.assign({}, {
                    name: key
                }, cfg));
        }

        return map;
    }

    StyledRect {
        id: bg
        z: 0
        color: Colors.colLayer0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.huge

        PageHeader {
            title: "Beam Cheatsheet"
            subTitle: "All Beam Binds and uses. (Still in Beta)"

            RippleButtonWithIcon {
                implicitSize: 45
                materialIcon: "close"
                releaseAction: () => root.visible = false
                buttonRadius: height / 2
            }
        }

        StyledRect {
            color: Colors.colLayer1
            radius: Rounding.huge
            Layout.fillHeight: true
            Layout.fillWidth: true

            StyledListView {
                id: list
                anchors.fill: parent
                anchors.margins: Padding.huge
                model: root.array
                radius: Rounding.huge
                clip: true
                hint: true
                hinter.color: Colors.colLayer1
                spacing: Padding.normal

                delegate: StyledRect {
                    id: entry
                    required property var modelData
                    required property int index
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    implicitHeight: entryContent.implicitHeight + Padding.massive
                    color: Colors.colLayer2
                    radius: Rounding.large

                    ColumnLayout {
                        id: entryContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Padding.huge
                        spacing: Padding.large

                        RowLayout {
                            spacing: Padding.huge
                            Layout.fillWidth: true

                            Item {
                                id: prefixIconContainer
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 54
                                implicitHeight: 54
                                visible: modelData?.name !== BeamData.defaultState

                                MaterialShapeWrappedSymbol {
                                    anchors.fill: parent
                                    text: (hoverHandler.containsMouse ? modelData?.icon : modelData?.prefix) ?? ""
                                    font: Fonts.request((hoverHandler.containsMouse ? "materialIcons" : "mono"), 20)
                                    _shape: modelData?.shape ?? "Pill"
                                    fill: 1
                                    color: hoverHandler.containsMouse ? Colors.colPrimary : Colors.colPrimaryContainer
                                    colSymbol: hoverHandler.containsMouse ? Colors.colOnPrimary : Colors.colOnPrimaryContainer

                                    Behavior on opacity {
                                        Anim {}
                                    }
                                }

                                MouseArea {
                                    id: hoverHandler
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Padding.small

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    text: methods.capitalizeFirstLetter(modelData?.name) ?? ""
                                    font: Fonts.request("title", 24)
                                    color: Colors.colOnLayer2
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    text: methods.capitalizeFirstLetter(modelData?.description) ?? ""
                                    font: Fonts.request("reading", 18)
                                    color: Colors.colSubtext
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        RowLayout {
                            visible: !!modelData?.subStates
                            Layout.fillWidth: true
                            Layout.leftMargin: Padding.huge + 54 + Padding.huge
                            spacing: Padding.normal

                            Rectangle {
                                Layout.fillHeight: true
                                width: 2
                                radius: 1
                                color: Colors.colOutline
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Repeater {
                                    id: subStatesRepeater
                                    model: ObjectUtils.arrayFrom(modelData?.subStates, "name").filter(i => !!i.description && i.prefix)
                                    delegate: StyledRect {
                                        id: subState
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: subStateContent.implicitHeight + Padding.large
                                        color: Colors.colLayer3
                                        radius: Rounding.normal

                                        RowLayout {
                                            id: subStateContent
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: Padding.large
                                            spacing: Padding.large

                                            StyledRect {
                                                implicitWidth: Math.max(28, subTxtPrefix.contentWidth + Padding.normal)
                                                implicitHeight: 26
                                                radius: Rounding.small
                                                color: Colors.colSecondaryContainer

                                                StyledText {
                                                    id: subTxtPrefix
                                                    text: subState.modelData?.prefix ?? ""
                                                    color: Colors.colOnSecondaryContainer
                                                    anchors.centerIn: parent
                                                    font: Fonts.request("mono", 14, {
                                                        weight: Font.DemiBold
                                                    })
                                                }
                                            }

                                            StyledText {
                                                text: subState.modelData?.description ?? ""
                                                color: Colors.colOnLayer3
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignLeft
                                                font: Fonts.request("main", 16)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
