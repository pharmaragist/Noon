import QtQuick
import Quickshell.Io

Process {
    property var callback
    property string output: ""

    stdout: StdioCollector {
        onStreamFinished: output = text.trim()
    }

    onExited: {
        if (callback)
            callback(output);
        destroy();
    }
}
