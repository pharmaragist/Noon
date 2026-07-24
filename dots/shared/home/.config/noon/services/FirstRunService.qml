pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.common
import qs.common.functions
import qs.common.utils

Singleton {
    id: root

    function createXDPH() {
        const t = path => Directories.methods.trim(path);
        const content = `
        screencopy {
            custom_picker_binary = ${t(Directories.standard.config)}/noon/scripts/screen_share_watcher
        }
        `
        FileUtils.createFileWith(t(Directories.standard.config + "/hypr/xdph.conf"), content);
    }

    function setupVariables() {
        Mem.states.desktop.firstRun = false;
        Mem.options.desktop.shell.mode = "main";
    }

    function setup() {
        if (!Mem.states.desktop.firstRun)
            return;
        setupVariables()
        createXDPH();
        WallpaperService.resetWallpaper();
    }
}
