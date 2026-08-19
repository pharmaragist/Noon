pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import qs.common
import qs.common.functions
import qs.common.utils

Singleton {
    id: root
    readonly property var opts: optsView.data
    readonly property bool isListening: mainProc.running
    property bool listening: false
    property string speech: ""

    function stop() {
        listening = false
        mainProc.running = false
    }

    function listen() {
        listening = false;

        _cmd(false, "--stt");
    }

    function say(text: string) {
        if (!text)
            return;
        _cmd(false, text);
    }

    function _cmd(detached, ...args) {
        if (!args.length)
            return;
        mainProc.command = ["python", Paths.scriptsDir + "/speech_service.py", "--config", Paths.methods.trim(optsView.path), ...args];
        if (detached) {
            mainProc.startDetached();
        } else {

            mainProc.running = false;
            mainProc.running = true;
        }
    }

    Component.onCompleted: {
        _cmd(true, "--tts-load");
    }

    Process {
        id: mainProc
        onStarted:console.error(command.join(" "))
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(',');
                if (parts[0] === "state") {
                    root.listening = (parts[1] ?? "").trim() === "listening";
                    return;
                }
                if (parts[0] !== "stt")
                    return;
                let text = parts.slice(1).join(',');
                if (text.startsWith('"') && text.endsWith('"'))
                    text = text.slice(1, -1);
                root.speech += text + "\n";
            }
        }
    }

    ConfigFileView {
        id: optsView
        state: false
        fileName: "tts_config"
        parentDir: "user/"

        JsonAdapter {
            property string model: ""
            property string device: ""
            property real volume: 1
            property string whisper_model: "base"
            property string language: "en"
        }
    }
}
