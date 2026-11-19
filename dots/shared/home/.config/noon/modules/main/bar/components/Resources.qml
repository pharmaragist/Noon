import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services
import qs.data

BarGroup {
    id: root

    readonly property bool isCharging: UPower.displayDevice.state == UPowerDeviceState.Charging
    property bool revealAll: false
    readonly property int itemSize: 22
    readonly property var metrics: [
        {
            id: "memory",
            icon: "settings_slow_motion"
        },
        {
            id: "swap",
            icon: "swap_horiz"
        },
        {
            id: "cpu_usage",
            icon: "memory"
        },
        {
            id: "cpu_temp",
            icon: "thermometer"
        }
    ]
    function metricPercentage(i) {
        var s = ResourcesService.stats;
        if (i === 0)
            return s.mem_total > 0 ? (s.mem_total - s.mem_available) / s.mem_total : 0;
        if (i === 1)
            return s.swap_total > 0 ? (s.swap_total - s.swap_free) / s.swap_total : 0;
        if (i === 2)
            return (s.cpu_percent ?? 0) / 100;
        return (s.cpu_temp ?? 0) / 100;
    }
    function metricVisible(i) {
        var opts = Mem.options.bar.resources;
        return opts.enabledMetrics.indexOf(metrics[i].id) !== -1 && (opts.showAlways || metricPercentage(i) > 0);
    }
    Layout.preferredHeight: content.implicitHeight + Padding.massive + (revealAll ? 20 : 0)
    Layout.preferredWidth: content.implicitWidth + Padding.massive + (revealAll ? 20 : 0)

    MouseArea {
        id: mouse

        anchors.fill: parent
        onPressed: revealAll = !revealAll
        hoverEnabled: true
    }

    ResourcesPopup {
        hoverTarget: mouse
    }

    GridLayout {
        id: content

        property bool verticalMode: root.verticalMode

        anchors.centerIn: parent
        rowSpacing: Padding.normal
        columnSpacing: Padding.normal
        rows: !verticalMode ? 1 : -1
        columns: verticalMode ? 1 : -1
        Repeater {
            model: root.metrics
            delegate: Resource {
                required property var modelData
                required property int index
                visible: root.metricVisible(index)
                iconName: modelData.icon
                percentage: root.metricPercentage(index)
                shown: true
                collapsed: !root.revealAll
                itemSize: root.itemSize
            }
        }
    }

    component Resource: Item {
        id: root

        required property string iconName
        required property double percentage
        property bool verticalMode: parent.verticalMode
        property bool shown: true
        property bool collapsed: false
        property int itemSize: 2

        clip: true
        visible: width > 0 && height > 0
        implicitWidth: resourceLayout.x < 0 ? 0 : childrenRect.width
        implicitHeight: childrenRect.height
        Layout.fillWidth: true

        GridLayout {
            id: resourceLayout

            rowSpacing: Padding.normal
            columnSpacing: Padding.huge
            x: shown ? 0 : -resourceLayout.width
            columns: verticalMode ? 1 : 2
            Item {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenters
                implicitWidth: root.itemSize
                implicitHeight: root.itemSize

                ClippedFilledCircularProgress {
                    anchors.centerIn: parent
                    value: percentage
                    implicitSize: root.itemSize
                }

                Symbol {
                    z: 99
                    horizontalAlignment: Text.AlignVCenter | Text.AlignHCenter
                    anchors.centerIn: parent
                    fill: 1
                    icon: iconName
                    iconSize: 16
                    color: Colors.colPrimaryContainer
                }
            }

            Revealer {
                reveal: !collapsed
                Layout.alignment: Qt.AlignCenter
                vertical: root.verticalMode

                StyledText {
                    visible: parent.reveal
                    anchors.centerIn: parent
                    color: Colors.colOnLayer0
                    text: Math.round(root.percentage * 100)
                    font: Fonts.request("spacedMono", "verysmall")
                }
            }
        }

        Behavior on implicitWidth {
            Anim {}
        }
    }
}
