pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.common

Singleton {
    id: root

    function createXDPH() {
        const config = Directories.methods.trim(Directories.standard.config)

        FileUtils.createFileWith(config + "/hypr/xdph.conf", `
        screencopy {
            custom_picker_binary = ${config}/noon/scripts/screen_share_watcher
        }
        `);
    }

    function setupVariables() {
        Mem.states.desktop.firstRun = false;
        Mem.options.desktop.shell.mode = "main";
    }

    function setup() {
        if (Mem.ready && !Mem.states.desktop.firstRun)
            return;
        createXDPH();
        WallpaperService.resetWallpaper();
        setupVariables();
    }
}
