import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import Noon.Utils

SidebarItemContainer {
    id: root

    readonly property ResourcesWatcher watcher: ResourcesService.watcher
    readonly property var res: watcher.stats

    property string searchQuery: ""
    property bool expanded: false

    property var secs: []

    function computeSecs() {
        var secs = [];
        var r = root.res;
        if (r) {
            var cpuItems = [];
            cpuItems.push({
                              label: "Usage",
                              value: r.cpu_percent / 100,
                              text: r.cpu_percent.toFixed(1) + "%"
                          });
            if (r.cpu_temp > 0)
                cpuItems.push({
                                  label: "Temperature",
                                  value: Math.min(r.cpu_temp / 100, 1.0),
                                  text: r.cpu_temp.toFixed(1) + " °C"
                              });
            if (r.cpu_total_freq_ghz > 0)
                cpuItems.push({
                                  label: "Clock",
                                  value: Math.min(r.cpu_freq_ghz / r.cpu_total_freq_ghz, 1.0),
                                  text: r.cpu_freq_ghz.toFixed(2) + " / " + r.cpu_total_freq_ghz.toFixed(2)
                                        + " GHz"
                              });
            secs.push({
                          title: "CPU",
                          items: cpuItems
                      });

            var memItems = [];
            var used = r.mem_total - r.mem_available;
            memItems.push({
                              label: "RAM",
                              value: r.mem_total > 0 ? used / r.mem_total : 0,
                              text: (used / 1073741824).toFixed(1) + " / " + (r.mem_total
                                                                              / 1073741824).toFixed(1) + " GB"
                          });
            if (r.swap_total > 0) {
                var swapUsed = r.swap_total - r.swap_free;
                memItems.push({
                                  label: "Swap",
                                  value: swapUsed / r.swap_total,
                                  text: (swapUsed / 1073741824).toFixed(1) + " / " + (r.swap_total
                                                                                      / 1073741824).toFixed(
                                            1) + " GB"
                              });
            }
            secs.push({
                          title: "Memory",
                          items: memItems
                      });

            if (r.disks && r.disks.length > 0) {
                var diskItems = [];
                for (var d = 0; d < r.disks.length; d++) {
                    var disk = r.disks[d];
                    diskItems.push({
                                       subtitle: disk.type.toUpperCase(),
                                       label: disk.mount,
                                       value: disk.total > 0 ? disk.used / disk.total : 0,
                                       text: (disk.used / 1073741824).toFixed(1) + " / " + (disk.total
                                                                                            / 1073741824).toFixed(
                                                 1) + " GB"
                                   });
                }
                secs.push({
                              title: "Storage",
                              items: diskItems
                          });
            }

            if (r.gpus) {
                for (var i = 0; i < r.gpus.length; i++) {
                    var gpu = r.gpus[i];
                    var gpuItems = [];
                    gpuItems.push({
                                      label: "Utilization",
                                      value: gpu.utilization / 100,
                                      text: gpu.utilization.toFixed(1) + "%"
                                  });
                    if (gpu.temperature > 0)
                        gpuItems.push({
                                          label: "Temperature",
                                          value: Math.min(gpu.temperature / 100, 1.0),
                                          text: gpu.temperature.toFixed(1) + " °C"
                                      });
                    if (gpu.memory_total > 0)
                        gpuItems.push({
                                          label: "VRAM",
                                          value: gpu.memory_used / gpu.memory_total,
                                          text: gpu.memory_used.toFixed(0) + " / " + gpu.memory_total.toFixed(
                                                    0) + " MB"
                                      });
                    if (gpu.power_draw > 0)
                        gpuItems.push({
                                          label: "Power",
                                          value: gpu.power_limit > 0 ? Math.min(gpu.power_draw
                                                                                / gpu.power_limit, 1.0) : 0,
                                          text: gpu.power_limit > 0 ? gpu.power_draw.toFixed(1) + " / "
                                                                      + gpu.power_limit.toFixed(1) + " W" :
                                                                      gpu.power_draw.toFixed(1) + " W"
                                      });
                    secs.push({
                                  title: gpu.name,
                                  items: gpuItems
                              });
                }
            }
        }
        return secs;
    }

    Timer {
        interval: 200
        running: true
        repeat: false
        onTriggered: root.secs = root.computeSecs()
    }

    Connections {
        target: root
        function onResChanged() {
            root.secs = root.computeSecs();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Padding.verylarge

        StyledListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Padding.large
            Layout.rightMargin: Padding.large
            Layout.bottomMargin: Padding.normal
            spacing: Padding.large
            clip: true
            hint: true

            _model: root.secs

            delegate: ResourceCard {
                required property var modelData
                title: modelData.title
                anchors.right: parent?.right
                anchors.left: parent?.left

                Repeater {
                    model: modelData.items
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: modelData?.subtitle ?? ""
                            visible: modelData.subtitle !== undefined
                            color: Colors.m3.m3onSurfaceVariant
                            font: Fonts.request("main", Fonts.sizes.verysmall, {
                                                    weight: Font.Medium
                                                })
                            elide: Text.ElideMiddle
                            opacity: 0.7
                        }

                        ResourceBar {
                            title: modelData.label
                            value: modelData.value
                            valueText: modelData.text
                        }

                        Item {
                            Layout.preferredHeight: modelData.subtitle !== undefined ? 4 : 0
                        }
                    }
                }
            }
        }
    }

    component ResourceCard: StyledRect {
        id: cardRoot
        default property alias content: cardLayout.data
        property string title: ""
        radius: Rounding.large
        color: Colors.colLayer2
        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + Padding.verylarge * 2

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: Padding.verylarge
            spacing: Padding.small

            StyledText {
                text: cardRoot.title
                font: Fonts.request("main", Fonts.sizes.small, {
                                        weight: Font.Black,
                                        letterSpacing: 1.1
                                    })
                color: Colors.m3.m3onSurfaceVariant
                opacity: 0.8
                visible: cardRoot.title.length > 0
            }

            Item {
                Layout.preferredHeight: cardRoot.title.length > 0 ? Padding.verysmall : 0
            }
        }
    }

    component ResourceBar: RLayout {
        id: barRoot
        property alias title: label.text
        property real value: 0
        property string valueText: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        spacing: Padding.huge

        StyledText {
            id: label
            Layout.preferredWidth: 80
            font.pixelSize: Fonts.sizes.normal
            color: Colors.colOnLayer2
        }

        StyledText {
            text: barRoot.valueText
            color: Colors.m3.m3onSurfaceVariant
            font: Fonts.request("main", Fonts.sizes.small, {
                                    weight: Font.Medium
                                })
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 110
        }

        StyledRect {
            Layout.preferredWidth: 80
            Layout.fillWidth: true
            radius: Rounding.full
            clip: true
            height: 6
            color: Colors.colLayer3

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(barRoot.value, 1.0)) * parent.width
                color: {
                    var v = barRoot.value;
                    if (v > 0.8)
                        return Colors.colError;
                    if (v > 0.5)
                        return Colors.colTertiary;
                    return Colors.colPrimary;
                }

                Behavior on width {
                    SmoothedAnimation {
                        velocity: 60
                    }
                }
            }
        }
    }
}
