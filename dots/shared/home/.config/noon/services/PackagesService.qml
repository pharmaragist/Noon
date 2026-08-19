pragma Singleton
import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.functions





Singleton {
    id: root
    readonly property bool firstRun: Mem.states.desktop.firstRun
    readonly property var list: Mem.pkgs.list
    readonly property string backend: Paths.scriptsDir + "/packages_service.py"
    property var status: ({})

    signal progress(string group, int percent, string message)
    signal error(string group, string message)

    function n(t) {
        return t.toLowerCase().trim();
    }

    function getStatus(onDone) {
        run(["python3", backend, "--status"], statusProc, () => {
            try {
                root.status = JSON.parse(statusProc.output);
            } catch (_) {}
            if (onDone)
                onDone(root.status);
        });
    }

    function install(group, inTerminal = false) {
        if (!group)
            return;
        if (!list.find(i => n(i.name) === n(group))) {
            console.error("Packages Error: This isn't a valid group");
            return;
        }
        if (inTerminal) {
            NoonUtils.runInTerminal("python3 '" + backend + "' --install " + group);
            return;
        }
        run(["python3", backend, "--install", group], installProc, null);
    }

    function checkIfInstalled(group, onDone) {
        if (!group) {
            if (onDone)
                onDone(false);
            return;
        }
        run(["python3", backend, "--check", group], checkProc, exitCode => {
            if (onDone)
                onDone(exitCode === 0);
        });
    }

    function run(cmd, proc = installProc, onDone) {
        proc.running = false;
        proc.command = cmd;
        proc.running = true;
        const finish = exitCode => {
            proc.exited.disconnect(finish);
            if (onDone)
                onDone(exitCode);
        };
        proc.exited.connect(finish);
    }

    Process {
        id: installProc
        stdout: SplitParser {
            onRead: data => {
                try {
                    const ev = JSON.parse(data);
                    if (ev.event === "progress")
                        root.progress(ev.group, ev.percent, ev.message);
                    else if (ev.event === "error")
                        root.error(ev.group, ev.message);
                } catch (_) {}
            }
        }
        onStarted: console.log("Packages: " + command.join(" "))
    }

    Process {
        id: checkProc
    }

    Process {
        id: statusProc
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: statusProc.output = text.trim()
        }
        onStarted: console.log("Packages: " + command.join(" "))
    }

    Component.onCompleted: getStatus()
}
