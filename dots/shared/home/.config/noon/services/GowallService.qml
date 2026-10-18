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
        if (Paths.methods.exists(outPath)) {
            return;
        } else {
            depthProc.command = ["bash", "-c", `gowall bg --output '${outPath}' '${inputPath}'`];
            depthProc.running = true;
        }
    }

    Process {
        id: depthProc
    }

    Process {
        id: proc
        onExited: code => {
            if (code === 0)
                WallpaperService.applyWallpaper(Qt.resolvedUrl(root._pendingOutput));
        }
    }
}
