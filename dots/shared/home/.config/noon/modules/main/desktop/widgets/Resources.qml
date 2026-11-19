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
    readonly property var icons: ["memory", "swap_horiz", "settings_slow_motion", "thermometer"]
    function percentage(i) {
        var s = ResourcesService.stats;
        if (i === 0)
            return s.mem_total > 0 ? (s.mem_total - s.mem_available) / s.mem_total : 0;
        if (i === 1)
            return s.swap_total > 0 ? (s.swap_total - s.swap_free) / s.swap_total : 0;
        if (i === 2)
            return (s.cpu_percent ?? 0) / 100;
        return (s.cpu_temp ?? 0) / 100;
    }

    normal: GridLayout {
        columns: root.columns
        rows: root.rows
        rowSpacing: root.isSmall ? 2 : Padding.normal
        columnSpacing: root.isSmall ? 2 : Padding.normal
        anchors.leftMargin: root.isSmall ? 0 : Padding.massive
        anchors.right: root.isSmall ? 0 : Padding.massive
        anchors.fill: parent
        Repeater {
            model: 4
            delegate: ColumnLayout {
                id: metric
                required property int index
                readonly property real pct: root.percentage(index)
                spacing: Padding.small
                Item {
                    Layout.topMargin: (root.isLarge || root.isXLarge) ? Padding.huge : 0
                    implicitHeight: root.implicitCircSize
                    implicitWidth: root.implicitCircSize
                    ClippedFilledCircularProgress {
                        anchors.centerIn: parent
                        value: metric.pct
                        implicitSize: root.implicitCircSize
                    }
                    Symbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: root.icons[index]
                        font.pixelSize: root.implicitCircSize * 0.6
                        color: Colors.colOnPrimary
                    }
                }
                StyledText {
                    visible: root.isLarge || root.isXLarge
                    text: Math.round(metric.pct * 100) + (root.icons[index] === "thermometer" ? "°C" : "%")
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
