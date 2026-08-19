pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.functions
import qs.store

Singleton {
    id: root




    property string model: "isnet-general-use"



    property bool alphaMatting: false




    property int foregroundThreshold: 240
    property int backgroundThreshold: 10
    property int erodeSize: 10


    property string _inputPath: ""
    property string _outputPath: ""
    property string _current_depth_path: ""

    property string state: "idle"

    readonly property bool isBusy: state === "running"


    Process {
        id: proc
        stdout: SplitParser {
            onRead: data => root.stdoutReady(data)
        }
        stderr: SplitParser {
            onRead: data => root.stderrReady(data)
        }
        onStarted: {
            root.state = "running";
            root.started(root._inputPath, root._outputPath);
        }
        onExited: (exitCode, exitStatus) => {
            const crashed = (exitStatus !== 0);
            const success = !crashed && (exitCode === 0);

            root.state = crashed ? "aborted" : success ? "success" : "error";
            root.finished(success, root._outputPath, exitCode);

            root._inputPath = "";
            root._outputPath = "";
        }
    }


    signal started(string inputPath, string outputPath)
    signal stdoutReady(string chunk)
    signal stderrReady(string chunk)
    signal finished(bool success, string outputPath, int exitCode)


    function _buildCommand(args) {
        const venvPath = Paths.venv;
        const scriptPath = Paths.methods.trim(Paths.scriptsDir + "/create_depth_image_rembg.py");

        return ["uv", "--directory", venvPath, "run", scriptPath].concat(args);
    }


    function _buildProcessArgs(inputPath, outputPath, opts) {
        const trimmedInput = Paths.methods.trim(inputPath);
        const trimmedOutput = Paths.methods.trim(outputPath);

        const args = [trimmedInput, trimmedOutput, "-m", opts?.model ?? model];

        if (opts?.alphaMatting ?? alphaMatting) {
            args.push("-a");
        }

        args.push("-ft", String(opts?.foregroundThreshold ?? foregroundThreshold));
        args.push("-bt", String(opts?.backgroundThreshold ?? backgroundThreshold));
        args.push("-e", String(opts?.erodeSize ?? erodeSize));

        return args;
    }


    function _runCommand(args, outputPath, inputPath = "") {
        _inputPath = inputPath;
        _outputPath = outputPath;
        proc.command = _buildCommand(args);
        proc.running = true;
    }


    function removeBackground(inputPath, outputPath, opts = {}) {
        if (!inputPath || !outputPath) {
            root.state = "error";
            root.finished(false, outputPath, -1);
            return;
        }

        abort();

        const processArgs = _buildProcessArgs(inputPath, outputPath, opts);
        _runCommand(processArgs, outputPath, inputPath);
    }

    function abort() {
        if (proc.running) {
            proc.running = false;
            root.state = "aborted";
        }
    }
    function process_current_bg() {
        const inputPath = Paths.methods.trim(Mem.looks.currentBg);
        const outputPath = Paths.methods.trim(Paths.wallpapers.depthDir + Qt.md5(inputPath) + ".png");
        root._current_depth_path = outputPath;
        removeBackground(inputPath, outputPath);
    }
    function reset() {
        abort();
        root.state = "idle";
        root._inputPath = "";
        root._outputPath = "";
    }
    function setup() {
        if (Mem.states.services.rembg.initialized) {
            console.log("RemBG service is already initialized");
            return;
        }
        console.log("Checking RemBG service");
        setupProc.running = true;
        setupProc.onExited.connect(exitCode => {
            if (exitCode === 0) {
                Mem.states.rembg.initialized = true;
                console.log("RemBG service setup completed");
            }
        });
    }
    Process {
        id: setupProc
        command: ["kitty", "-e", "fish", "-c", `uv run ${Paths.scriptsDir}/create_depth_image_rembg.py`]
        workingDirectory: Paths.methods.trim(Paths.standard.state)
    }



    readonly property var presetFast: ({
            "model": "isnet-general-use",
            "alphaMatting": false
        })


    readonly property var presetQuality: ({
            "model": "isnet-general-use",
            "alphaMatting": true,
            "foregroundThreshold": 240,
            "backgroundThreshold": 10,
            "erodeSize": 10
        })


    readonly property var presetFineDetail: ({
            "model": "isnet-general-use",
            "alphaMatting": true,
            "foregroundThreshold": 240,
            "backgroundThreshold": 10,
            "erodeSize": 3
        })
}
