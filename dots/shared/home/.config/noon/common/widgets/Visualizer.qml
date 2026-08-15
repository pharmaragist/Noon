import Noon.Utils
import QtQuick
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services
import Quickshell

StyledRect {
    id: root

    anchors.fill: parent

    property bool active: false
    property string _mode:Mem.beats.options.visualizerMode
    property var mode: WaveVisualizer[_mode]
    property color visualizerColor: Colors.methods.transparentize(Colors.colPrimary, 0.35)
    property real maxVisualizerValue: 5000
    clip: radius > 0
    color: "transparent"

    CavaWatcher {
        id: cavaWatcher
        smoothing: 0
        active: root.active
    }

    WaveVisualizer {
        id: waves
        anchors.fill: parent
        visualizerType: root.mode
        points: cavaWatcher.data
        maxVisualizerValue: root.maxVisualizerValue
        color: root.visualizerColor
        live: root.active
    }
}
