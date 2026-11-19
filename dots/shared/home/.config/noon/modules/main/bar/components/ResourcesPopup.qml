import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

StyledPopup {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        StyledText {
            text: "Resources"
            color: Colors.m3.m3onSurface
            font: Fonts.request("main", "large", { weight: Font.Bold })
            Layout.bottomMargin: 8
        }

        SectionLabel {
            text: "CPU"
        }

        ResourceBar {
            title: "Usage"
            value: ResourcesService.stats.cpu_percent / 100
            valueText: ResourcesService.stats.cpu_percent.toFixed(1) + "%"
        }

        ResourceBar {
            title: "Temperature"
            value: Math.min(ResourcesService.stats.cpu_temp / 100, 1.0)
            valueText: ResourcesService.stats.cpu_temp.toFixed(1) + " °C"
            visible: ResourcesService.stats.cpu_temp > 0
        }

        ResourceBar {
            title: "Clock"
            value: ResourcesService.stats.cpu_total_freq_ghz > 0 ? Math.min(ResourcesService.stats.cpu_freq_ghz / ResourcesService.stats.cpu_total_freq_ghz, 1.0) : 0
            valueText: ResourcesService.stats.cpu_freq_ghz.toFixed(2) + " GHz" + " / " + ResourcesService.stats.cpu_total_freq_ghz.toFixed(2) + " GHz"
        }

        SectionLabel {
            text: "MEMORY"
        }

        ResourceBar {
            readonly property real used: ResourcesService.stats.mem_total - ResourcesService.stats.mem_available
            title: "RAM"
            value: ResourcesService.stats.mem_total > 0 ? used / ResourcesService.stats.mem_total : 0
            valueText: (used / 1073741824).toFixed(1) + " GB" + " / " + (ResourcesService.stats.mem_total / 1073741824).toFixed(1) + " GB"
        }

        ResourceBar {
            readonly property real swapUsed: ResourcesService.stats.swap_total - ResourcesService.stats.swap_free
            title: "Swap"
            value: ResourcesService.stats.swap_total > 0 ? swapUsed / ResourcesService.stats.swap_total : 0
            valueText: (swapUsed / 1073741824).toFixed(1) + " GB" + " / " + (ResourcesService.stats.swap_total / 1073741824).toFixed(1) + " GB"
            visible: ResourcesService.stats.swap_total > 0
        }

        SectionLabel {
            text: "STORAGE"
            visible: ResourcesService.watcher.diskCount > 0
        }

        Repeater {
            model: ResourcesService.watcher.diskCount
            delegate: ColumnLayout {
                id: diskItem
                required property int index
                readonly property var disk: (ResourcesService.stats.disks ?? [])[index] ?? ({})
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: diskItem.disk.type ? diskItem.disk.type.toUpperCase() : ""
                    color: Colors.m3.m3onSurfaceVariant
                    font: Fonts.request("main", "verysmall", { weight: Font.Medium })
                    elide: Text.ElideMiddle
                    opacity: 0.7
                }

                ResourceBar {
                    title: diskItem.disk.mount ?? ""
                    value: diskItem.disk.total > 0 ? diskItem.disk.used / diskItem.disk.total : 0
                    valueText: ((diskItem.disk.used ?? 0) / 1073741824).toFixed(1) + " GB / " + ((diskItem.disk.total ?? 0) / 1073741824).toFixed(1) + " GB"
                }

                Item {
                    Layout.preferredHeight: 4
                }
            }
        }

        Repeater {
            model: ResourcesService.watcher.gpuCount
            delegate: ColumnLayout {
                id: gpuItem
                required property int index
                readonly property var gpu: (ResourcesService.stats.gpus ?? [])[index] ?? ({})
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Colors.m3.m3outlineVariant
                    opacity: 0.2
                    Layout.topMargin: 10
                    Layout.bottomMargin: 2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: gpuItem.gpu.name ?? ""
                    color: Colors.m3.m3onSurfaceVariant
                    font: Fonts.request("main", "small", { weight: Font.Bold })
                    elide: Text.ElideRight
                }

                ResourceBar {
                    title: "Utilization"
                    value: (gpuItem.gpu.utilization ?? 0) / 100
                    valueText: (gpuItem.gpu.utilization ?? 0).toFixed(1) + "%"
                }

                ResourceBar {
                    title: "Temperature"
                    value: Math.min((gpuItem.gpu.temperature ?? 0) / 100, 1.0)
                    valueText: (gpuItem.gpu.temperature ?? 0).toFixed(1) + " °C"
                    visible: (gpuItem.gpu.temperature ?? 0) > 0
                }

                ResourceBar {
                    title: "VRAM"
                    value: gpuItem.gpu.memory_total > 0 ? gpuItem.gpu.memory_used / gpuItem.gpu.memory_total : 0
                    valueText: (gpuItem.gpu.memory_used ?? 0).toFixed(0) + " MB" + " / " + (gpuItem.gpu.memory_total ?? 0).toFixed(0) + " MB"
                    visible: (gpuItem.gpu.memory_total ?? 0) > 0
                }

                ResourceBar {
                    title: "Power"
                    value: gpuItem.gpu.power_limit > 0 ? Math.min(gpuItem.gpu.power_draw / gpuItem.gpu.power_limit, 1.0) : 0
                    valueText: gpuItem.gpu.power_limit > 0 ? gpuItem.gpu.power_draw.toFixed(1) + " W" + " / " + gpuItem.gpu.power_limit.toFixed(1) + " W" : (gpuItem.gpu.power_draw ?? 0).toFixed(1) + " W"
                    visible: (gpuItem.gpu.power_draw ?? 0) > 0
                }
            }
        }
    }

    component ResourceBar: RLayout {
        id: barRoot
        property alias title: label.text
        property real value: 0
        property string valueText: ""
        height: 40
        Layout.fillWidth: true
        spacing: Padding.huge

        StyledText {
            id: label
            font.pixelSize: Fonts.sizes.normal
            color: Colors.colOnLayer2
            Layout.fillWidth: true
        }

        StyledText {
            text: barRoot.valueText
            color: Colors.m3.m3onSurfaceVariant
            font: Fonts.request("main", "small", { weight: Font.Medium })
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 110
        }

        StyledRect {
            Layout.preferredWidth: 100
            radius: Rounding.full
            clip: true
            height: 6
            color: Colors.colLayer3

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(barRoot.value, 1.0)) * parent.width
                color: Colors.colPrimary

                Behavior on width {
                    SmoothedAnimation {
                        velocity: 60
                    }
                }
            }
        }
    }

    component SectionLabel: StyledText {
        color: Colors.m3.m3onSurfaceVariant
        font: Fonts.request("main", "small", { weight: Font.Black, letterSpacing: 1.1 })
        opacity: 0.8
        Layout.topMargin: 6
        Layout.bottomMargin: 2
    }
}
