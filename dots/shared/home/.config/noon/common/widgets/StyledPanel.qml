import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.common
import qs.common.utils

PanelWindow {
    id: root

    property string shell: "noon"
    property string name: "standard"
    property int _margins: 0
    property bool fill: false
    property bool keyboardFocus: false
    property string _layer: "Top"

    property bool autoHide: false
    property bool revealed: true
    property int hideDelay: 350
    property bool _shown: true
    property Region blur: null
    visible: autoHide ? _shown : true
    focusable: keyboardFocus

    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer[_layer]
    WlrLayershell.namespace: shell + ":" + name
    WlrLayershell.keyboardFocus: (root.keyboardFocus === true) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    BackgroundEffect.blurRegion: root.blur
    margins {
        top: _margins
        bottom: _margins
        left: _margins
        right: _margins
    }

    anchors {
        top: fill
        bottom: fill
        left: fill
        right: fill
    }

    onRevealedChanged: {
        if (!autoHide)
            return;
        if (revealed) {
            hideTimer.stop();
            _shown = true;
        } else {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: {
            if (!root.revealed)
                root._shown = false;
        }
    }

    property FocusHandler focusHandler: FocusHandler {
        windows: [root]
    }

    DismissArea {
        id: dismissAreaItem
        onDismiss: focusHandler.cleared()
    }
    property alias dismissArea: dismissAreaItem
}
