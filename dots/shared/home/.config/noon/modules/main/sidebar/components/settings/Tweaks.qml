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
            var data = TweaksData.tweaks;

            if (root.currentCategory.length > 0) {
                data = data.filter(cat => cat.section === root.currentCategory);
                if (data.length === 0) return data;
            }

            if (searchQuery) {
                const q = searchQuery.toLowerCase();
                const filter = s => s && s.toLowerCase().includes(q);
                data = data.reduce((acc, entry) => {
                    const matchingItems = entry.items.filter(item => {
                        const mComboBox = item?.values?.some(i => filter(i)) || false;
                        const roles = ["name", "type", "store"];
                        return mComboBox || roles.some(role => filter(item[role]));
                    });
                    if (filter(entry.section)) {
                        acc.push(entry);
                    } else if (matchingItems.length > 0) {
                        acc.push(Object.assign({}, entry, { items: matchingItems }));
                    }
                    return acc;
                }, []);
            }

            return data;
        }
    }
    property string currentCategory: ""
    property bool showCategories: false
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
            reuseItems: false
            spacing: Padding.veryhuge
            model: itemsModel
            delegate: StyledRect {
                required property var modelData
                required property int index
                anchors.right: parent?.right
                anchors.left: parent?.left
                implicitHeight: sectionContent.implicitHeight + Padding.massive
                radius: Rounding.veryhuge
                color: "transparent"

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
                                id: backArrow
                                icon: "arrow_back"
                                iconSize: 18
                                color: Colors.colOnPrimaryContainer
                                visible: root.currentCategory.length > 0
                            }

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

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                if (root.currentCategory.length > 0) {
                                    var pos = mapToItem(backArrow, mouse.x, mouse.y);
                                    if (pos.x >= -4 && pos.x < backArrow.width + 4 && pos.y >= -4 && pos.y < backArrow.height + 4) {
                                        root.currentCategory = "";
                                        root.showCategories = false;
                                        return;
                                    }
                                    root.currentCategory = "";
                                    root.showCategories = true;
                                    return;
                                }

                                if (root.showCategories) {
                                    if (!!modelData.section) {
                                        root.currentCategory = modelData.section;
                                        root.showCategories = false;
                                    }
                                    return;
                                }

                                root.showCategories = true;
                            }
                        }
                    }

                    Repeater {
                        id: itemsRepeater
                        model: ScriptModel {
                            values: !root.showCategories ? modelData.items : []
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
                            releaseAction: () => modelData?.releaseAction() ?? null
                            actionIcon: modelData?.actionIcon ?? ""

                            minValue: modelData?.minValue ?? 0.0
                            maxValue: modelData?.maxValue ?? 100.0
                            actionName: modelData?.actionName ?? ""
                            stepValue: modelData?.stepValue ?? 0.1

                            values: modelData?.values ?? []
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
