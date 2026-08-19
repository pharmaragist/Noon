import Quickshell.Io
import QtQuick
import qs.common

Item {
    id: root
    property bool active: true
    property string input: ""
    property string output: ""
    property string targetFile: ""
    readonly property alias running: downloadProc.running

    onInputChanged: {
        if (!active)
            return;

        const online = input.startsWith("https://") || input.startsWith("http://");
        targetFile = Paths.beats.coverArt + "/" + Qt.md5(input) + ".jpg";
        downloadProc.running = false;

        if (online) {
            checkProc.running = true;
        } else {
            output = input;
        }
    }

    Process {
        id: checkProc
        command: ["test", "-f", targetFile]
        onExited: exitCode => {
            if (exitCode === 0) {
                output = Qt.resolvedUrl(targetFile);
            } else {
                downloadProc.running = true;
            }
        }
    }

    Process {
        id: downloadProc


        command: ["curl", "--range", "0-99999", "--max-filesize", 100000, "-o", targetFile,  input]
        onExited: exitCode => {
            if (exitCode === 0) {
                output = Qt.resolvedUrl(targetFile);
            } else {
                output = input;
            }
        }
    }
}
