import QtQuick
import qs.common
import qs.common.widgets
import qs.modules.main.bar.components

Item {
    id: root
    required property var barRoot
    readonly property var opts: Mem.options.bar.horizontal.map

    anchors {
        fill: parent
        rightMargin: Padding.huge
        leftMargin: Padding.huge
    }

    RLayout {
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }
        spacing: opts.spacing
        BarModulesFactory {
            model: opts.leftArea
            panel: barRoot
        }
    }

    RLayout {
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        spacing: opts.spacing
        BarModulesFactory {
            model: opts.centerArea
            panel: barRoot
        }
    }
    RLayout {
        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }
        spacing: opts.spacing
        BarModulesFactory {
            model: opts.rightArea
            panel: barRoot
        }
    }

}
