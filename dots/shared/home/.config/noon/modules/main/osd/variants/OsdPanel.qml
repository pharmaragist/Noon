import QtQuick
import qs.common
import qs.common.widgets
import qs.services
import Quickshell.Services.Pipewire

StyledPanel {
    id: panelRoot
    name: "blurred_fade_layer"

    property real value
    property string icon
    property var targetScreen
    property var volumeModel
    property bool volumeMode: false
    property PwNode selectedDevice

    readonly property list<PwNode> appPwNodes: Pipewire.nodes.values.filter(node => {
        return node.isStream && node.audio !== null;
    })

    signal valueModified(real newValue)
    signal interactionStarted
    signal interactionEnded

    visible: true
    exclusiveZone: 0
    _layer: "Overlay"
}
