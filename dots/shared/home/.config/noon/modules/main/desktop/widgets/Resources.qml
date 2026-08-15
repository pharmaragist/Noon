import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root

    readonly property int implicitCircSize: root.isSmall ? 40 : (root.isXLarge ? 83 : 64)
    readonly property int columns: root.isLarge || root.isXLarge ? 4 : 2
    readonly property int rows: root.isLarge || root.isXLarge ? 2 : 1
    readonly property var resourcesModel: [
        {
            iconName: "memory",
            percentage: (ResourcesService.stats.mem_total - ResourcesService.stats.mem_available) / ResourcesService.stats.mem_total
        },
        {
            iconName: "swap_horiz",
            percentage: (ResourcesService.stats.swap_total - ResourcesService.stats.swap_free) / ResourcesService.stats.swap_total
        },
        {
            iconName: "settings_slow_motion",
            percentage: ResourcesService.stats.cpu_percent / 100
        },
        {
            iconName: "thermometer",
            percentage: ResourcesService.stats.cpu_temp / 100
        }
    ]

    normal: GridLayout {
        columns: root.columns
        rows: root.rows
        rowSpacing: root.isSmall ? 2 : Padding.normal
        columnSpacing: root.isSmall ? 2 : Padding.normal
        anchors.leftMargin: root.isSmall ? 0 : Padding.massive
        anchors.right: root.isSmall ? 0 : Padding.massive
        anchors.fill: parent
        Repeater {
            model: ScriptModel {
                values: resourcesModel
            }
            delegate: ColumnLayout {
                spacing: Padding.small
                Item {
                    Layout.topMargin: (root.isLarge || root.isXLarge) ? Padding.huge : 0
                    implicitHeight: root.implicitCircSize
                    implicitWidth: root.implicitCircSize
                    ClippedFilledCircularProgress {
                        anchors.centerIn: parent
                        value: modelData.percentage
                        implicitSize: root.implicitCircSize
                    }
                    Symbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: modelData.iconName
                        font.pixelSize: root.implicitCircSize * 0.6
                        color: Colors.colOnPrimary
                    }
                }
                StyledText {
                    visible: root.isLarge || root.isXLarge
                    text: Math.round(modelData.percentage * 100) + (modelData.iconName === "thermometer" ? "°C" : "%")
                    color: Colors.colOnSurface
                    font: Fonts.request("numbers", Fonts.sizes.huge)
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
    small: normal
    large: normal
    xlarge: normal
}
