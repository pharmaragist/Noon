import QtQuick
import QtQuick.Layouts
import qs.store
import qs.services
import qs.common
import qs.common.widgets

SidebarItemContainer {
    id: root

    ScriptModel {
        id: itemsModel
        values: {
            if (!searchQuery)
                return TweaksData.tweaks;

            return TweaksData.tweaks.reduce((acc, entry) => {
                const filter = q => {
                    return q && q.toLowerCase().includes(searchQuery.toLowerCase());
                };

                const matchingItems = entry.items.filter(item => {
                    const mComboBox = item?.comboBoxValues && item?.comboBoxValues.some(i => filter(i)) || false;
                    const roles = ["name", "type", "store"];
                    return mComboBox || roles.some(role => filter(item[role]));
                });

                if (filter(entry.section)) {
                    acc.push(entry);
                } else if (matchingItems.length > 0) {
                    acc.push(Object.assign({}, entry, {
                        items: matchingItems
                    }));
                }

                return acc;
            }, []);
        }
    }

    ColumnLayout {
        anchors.fill: parent

        AccountInfoSection {
            color: "transparent"
            Layout.margins: Padding.large

            account: ({
                    name: SysInfoService.username,
                    image: SysInfoService.userPfp,
                    handler: SysInfoService.distroId
                })
        }

        StyledListView {
            id: list

            Layout.fillHeight: true
            Layout.fillWidth: true
            radius: Rounding.verylarge
            clip: true
            hint: true
            popin: false
            animateAppearance: false
            model: itemsModel
            reuseItems: false
            spacing: Padding.veryhuge
            delegate: StyledRect {
                required property var modelData
                required property int index
                anchors.right: parent?.right
                anchors.left: parent?.left
                implicitHeight: sectionContent.implicitHeight + Padding.massive
                radius: Rounding.veryhuge
                color: "transparent" //Colors.colLayer1

                ColumnLayout {
                    id: sectionContent
                    spacing: 3
                    anchors.fill: parent
                    anchors.margins: Padding.large
                    StyledRect {
                        id: sectionHeaderBackground
                        implicitWidth: children[1]?.implicitWidth + (Padding.huge * 2)
                        implicitHeight: 40
                        radius: Rounding.huge
                        color: Colors.colPrimaryContainer
                        Layout.leftMargin: Padding.normal
                        Layout.bottomMargin: Padding.normal

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Padding.small

                            Symbol {
                                icon: modelData?.icon ?? ""
                                iconSize: 20
                                color: Colors.colOnPrimaryContainer
                                Layout.alignment: Qt.AlignVCenter
                            }

                            StyledText {
                                text: modelData?.section ?? ""
                                color: Colors.colOnPrimaryContainer
                                font: Fonts.request("title", "normal")
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    Repeater {
                        id: itemsRepeater
                        model: ScriptModel {
                            values: modelData.items
                        }
                        delegate: SettingsItem {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            topRadius: index === 0 ? Rounding.verylarge : Rounding.verytiny + 1
                            bottomRadius: index === itemsRepeater.count - 1 ? Rounding.verylarge : Rounding.verytiny + 1
                            color: Colors.colSurfaceContainerHigh

                            icon: modelData?.icon ?? "settings"
                            name: modelData?.name ?? ""
                            description: modelData?.hint ?? ""

                            key: modelData?.key ?? ""
                            type: modelData?.type ?? "switch"
                            store: modelData?.store ?? false

                            canRefresh: modelData?.canRefresh ?? false
                            reloadOnChange: modelData?.reloadOnChange ?? false
                            refreshAction: () => modelData?.refreshAction() ?? null

                            minValue: modelData?.minValue ?? 0.0
                            maxValue: modelData?.maxValue ?? 100.0
                            actionName: modelData?.actionName ?? ""
                            stepValue: modelData?.stepValue ?? 0.1

                            comboBoxValues: modelData?.comboBoxValues ?? []
                            fillHeight: modelData?.fillHeight ?? false
                            visible: modelData?.visible ?? true
                            colors: root.colors
                        }
                    }
                }
            }
        }
    }

    PagePlaceholder {
        anchors.centerIn: parent
        shown: list.count === 0
        icon: "block"
        shape: MaterialShape.Clover4Leaf
        title: "Nothing found"
    }
}
