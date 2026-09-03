import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.common.functions
import qs.services
import qs.data

Item {
    id: root

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

    readonly property int prefixColW: 100
    readonly property int nameColW: 200
    readonly property int colSpacing: Padding.large

    StyledRect {
        id: bg
        z: 0
        color: Colors.colLayer0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.normal

        PageHeader {
            title: "Beam Cheatsheet"
            subTitle: "All Beam Binds and uses. (Still in Beta)"
        }

        StyledRect {
            color: Colors.colLayer1
            radius: Rounding.silly + 6
            Layout.fillHeight: true
            Layout.fillWidth: true

            Item {
                id: content
                anchors.fill: parent
                anchors.margins: Padding.large

                RowLayout {
                    id: header
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Padding.normal
                    spacing: root.colSpacing

                    StyledText {
                        Layout.preferredWidth: root.prefixColW
                        text: "Prefix"
                        font: Fonts.request("title", 18)
                        color: Colors.colSubtext
                    }

                    StyledText {
                        Layout.preferredWidth: root.nameColW
                        text: "Name"
                        font: Fonts.request("title", 18)
                        color: Colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Description"
                        font: Fonts.request("title", 18)
                        color: Colors.colSubtext
                    }
                }

                StyledListView {
                    id: list
                    anchors.top: header.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.topMargin: Padding.huge
                    model: root.array
                    clip: true
                    hint: true
                    hinter.color: Colors.colLayer1
                    spacing: Padding.large

                    delegate: RowLayout {
                        id: entry

                        required property var modelData
                        readonly property var subs: entry.modelData?.subStates ? ObjectUtils.arrayFrom(entry.modelData.subStates, "name").filter(i => !!i.description && i.prefix) : []

                        anchors.left: parent?.left
                        anchors.right: parent?.right
                        anchors.margins: Padding.normal
                        spacing: root.colSpacing

                        StyledText {
                            Layout.preferredWidth: root.prefixColW
                            Layout.alignment: Qt.AlignTop
                            text: entry.modelData?.name !== BeamData.defaultState ? (entry.modelData?.prefix ?? "") : "Default"
                            font: Fonts.request("title", 18)
                            color: Colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: root.nameColW
                            Layout.maximumWidth: root.nameColW
                            Layout.alignment: Qt.AlignTop
                            spacing: Padding.small

                            StyledText {
                                Layout.fillWidth: true
                                text: methods.capitalizeFirstLetter(entry.modelData?.name) ?? " "
                                font: Fonts.request("title", 18)
                                color: Colors.colOnLayer1
                            }

                            Repeater {
                                model: entry.subs

                                delegate: StyledText {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    text: modelData?.prefix ?? "none"
                                    font: Fonts.request("mono", 24)
                                    color: Colors.colSecondary
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Padding.tiny

                            StyledText {
                                Layout.fillWidth: true
                                text: methods.capitalizeFirstLetter(entry.modelData?.description) ?? ""
                                font: Fonts.request("reading", 16)
                                color: Colors.colSubtext
                                truncate: true
                            }

                            Repeater {
                                model: entry.subs

                                delegate: StyledText {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    text: modelData?.description ?? ""
                                    font: Fonts.request("main", 14)
                                    color: Colors.colSubtext
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }

                Separator {
                    x: root.prefixColW + root.colSpacing / 2
                }

                Separator {
                    x: root.prefixColW + root.nameColW + root.colSpacing * 1.5
                }
            }
        }
    }
    component Separator: Rectangle {
        width: 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: Colors.colOutline
        opacity: 0.35
    }
}
