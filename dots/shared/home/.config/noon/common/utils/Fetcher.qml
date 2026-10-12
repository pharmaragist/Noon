import QtQuick
import Quickshell
import Quickshell.Io

Process {
    id: root
    property var data: null
    property bool autoRun: true
    running: autoRun
    signal streamFinished
    function refresh() {
        if (root.running) {
            // Already running: let it finish instead of killing it mid-stream
            // (killing yields empty/partial stdout and stale data).
            return;
        }
        root.data = null;
        root.running = true;
    }

    stdout: StdioCollector {
        onStreamFinished: {
            const out = text.trim();
            if (out.length === 0)
                console.warn("Fetcher: empty stdout, command:", JSON.stringify(root.command));
            else {
                try {
                    root.data = JSON.parse(out);
                } catch (e) {
                    console.warn("Fetcher: JSON parse failed, command:", JSON.stringify(root.command), e);
                }
            }
            root.streamFinished();
        }
    }
}
