pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils

Singleton {
    id: root
    readonly property var options: confView.data

    ConfigFileView {
        id: confView
        path: Paths.standard.config + "/arya/config.json"

        JsonAdapter {
            id: schema
            property string node_name: ""
            property string socket_path: ""
            property bool discovery: true
            property int listen_port: 0
            property int buffer_ms: 5
            property int frame_ms: 5
            property int sample_rate: 4800
            property int channels: 2
            property var interfaces: []
            property var manual_peers: []
            property bool pipewire: true
            property string sink_name: ""
            property string mic_sink_name: ""
            property JO capabilities: JO {
                property bool speaker: true
                property bool microphone: true
            }
            property JO policy: JO {
                // TODO: ARYA RENAME DEFAULT
                // property string default: "allow"
            }
        }
    }
}
