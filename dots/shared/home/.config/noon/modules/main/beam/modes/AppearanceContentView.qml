import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import qs.data

ContentViewItem {
    Item {
        width: content.implicitWidth + Padding.massive
        height: 70
        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: Padding.huge

            Toolbar {
                radius: height / 2
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillHeight: true
                Layout.fillWidth: true

                ToolbarTabBar {
                    tabButtonList: ThemeService?.modes ?? []
                    currentIndex: tabButtonList.findIndex(m => m.value.toLowerCase() === Mem.looks.scheme) ?? -1
                    onCurrentIndexChanged: if (!!tabButtonList && currentIndex > -1) {
                        const mode = tabButtonList[this.currentIndex];
                        WallpaperService.updateScheme(mode.value);
                    }
                }
            }
            ButtonGroup {
                Layout.fillHeight: true
                Repeater {
                    model: [
                        {
                            "icon": GowallService.isBusy ? "hourglass" : "auto_fix_high",
                            "enabled": !GowallService.isBusy,
                            "action": () => {
                                GowallService.upscaleCurrentWallpaper();
                            }
                        },
                        {
                            "enabled": !GowallService.isBusy,
                            "icon": GowallService.isBusy ? "hourglass" : "content_cut",
                            "action": () => {
                                GowallService.removeBackground(WallpaperService.currentWallpaper);
                            }
                        },
                        {
                            "icon": "colorize",
                            "action": () => {
                                WallpaperService.pickAccentColor();
                            }
                        },
                    ]
                    GroupButtonWithIcon {
                        Layout.fillHeight: false
                        iconSize: 20
                        implicitSize: 45
                        buttonRadius: height / 2
                        buttonRadiusPressed: height / 2
                        materialIcon: modelData?.icon ?? ""
                        enabled: modelData?.enabled ?? true
                        releaseAction: () => modelData.action()
                    }
                }
            }
            ShapeComboBox {
                id: paletteCombo
                Layout.leftMargin: Padding.normal
                triggerIcon: "palette"
                shape: "Cookie12Sided"
                _model: ThemeService.palettes
                currentIndex: Math.max(0, ThemeService.palettes.findIndex(p => p.value === Mem.options.appearance.colors.palettePath))
                onActivated: index => {
                    Mem.options.appearance.colors.palettePath = ThemeService.palettes[index]?.value;
                }
            }

            ShapeComboBox {
                id: engineCombo
                shapeItem.color: Colors.colTertiary
                shapeItem.colSymbol: Colors.colOnTertiary

                Layout.rightMargin: Padding.normal
                triggerIcon: "auto_awesome"
                shape: "Pill"
                _model: ThemeService.themes
                currentIndex: 0
                onActivated: index => {
                    GowallService.convertTheme(ThemeService.themes[index]);
                }
            }
        }
    }
}
