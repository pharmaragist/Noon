pragma Singleton
pragma ComponentBehavior: Bound
import qs.common
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire




Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource

    signal sinkProtectionTriggered(string reason)

    PwObjectTracker {
        objects: [sink, source]
    }

    Connections {

        target: sink?.audio ?? null
        property bool lastReady: false
        property real lastVolume: 0
        function onVolumeChanged() {
            if (!lastReady) {
                lastVolume = sink.audio.volume;
                lastReady = true;
                return;
            }
            const opts = Mem.options.audio.protection;
            const newVolume = sink.audio.volume;
            const maxAllowedIncrease = (opts.enabled ? opts.maxAllowedIncrease : opts.maxAllowed) / 100;
            const maxAllowed = opts.maxAllowed / 100;

            if (newVolume - lastVolume > maxAllowedIncrease) {
                sink.audio.volume = lastVolume;
                root.sinkProtectionTriggered("Illegal increment");
            } else if (newVolume > maxAllowed) {
                sink.audio.volume = lastVolume;
                root.sinkProtectionTriggered("Exceeded max allowed");
            }
            lastVolume = sink.audio.volume;
        }
    }
}
