pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.functions
import qs.common.utils
import qs.data

Singleton {
    id: root

    property bool isBusy: proc.running || depthProc.running
    property var fgJob: null
    property var fgRunning: null
    property string inputPath: Paths.methods.trim(Mem.looks.currentBg)
    property string current_processed_wall: Paths.wallpapers.gowallDir + Qt.md5(inputPath) + ".png"
    property string upscale_output: Paths.methods.trimFileExt(inputPath) + "_upscaled.png"
    property string _pendingOutput: ""

    function upscaleCurrentWallpaper() {
        root._pendingOutput = upscale_output;
        proc.command = ["gowall", "upscale", inputPath, "--output", upscale_output];
        proc.running = true;
    }

    function convertTheme(themeName) {
        root._pendingOutput = current_processed_wall;
        proc.command = ["gowall", "convert", "-t", themeName, inputPath, "--output", current_processed_wall];
        proc.running = true;
    }

    function removeBackground(input) {
        const inputPath = Paths.methods.trim(input);
        const outPath = WallpaperService.getFgPathOf(input);
        if (Paths.methods.exists(outPath) || root.fgRunning?.[1] === outPath)
            return;
        root.fgJob = [inputPath, outPath];
        root.pumpFg();
    }

    function pumpFg() {
        if (depthProc.running || !root.fgJob)
            return;
        root.fgRunning = root.fgJob;
        root.fgJob = null;
        depthProc.command = ["gowall", "bg", "--output", root.fgRunning[1], root.fgRunning[0]];
        depthProc.running = true;
    }

    Process {
        id: depthProc
        onExited: {
            root.fgRunning = null;
            root.pumpFg();
        }
    }

    Process {
        id: proc
        onExited: code => {
            if (code === 0)
                WallpaperService.applyWallpaper(Qt.resolvedUrl(root._pendingOutput));
        }
    }
}
