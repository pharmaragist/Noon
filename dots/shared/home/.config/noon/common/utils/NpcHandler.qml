import QtQuick
import Quickshell.Io
import qs.common

// Self-registering IpcHandler: identical over the socket, but also callable
// in-process via Ipc.call with zero process spawn.
// ponytail: targets are static literals; a runtime target change re-registers
// on next reload instead of live (no noon target does this today).
IpcHandler {
    Component.onCompleted: {
        Ipc.register(target, this);
        console.log("[Noon] ipc route registered: " + target);
    }
    Component.onDestruction: Ipc.unregister(target, this)
}
