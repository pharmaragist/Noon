import QtQuick
import Quickshell.Io

Process {
    property var callback

    stdout: StdioCollector {
        onStreamFinished: {
            callback(text.trim());
            destroy();
        }
    }
}
