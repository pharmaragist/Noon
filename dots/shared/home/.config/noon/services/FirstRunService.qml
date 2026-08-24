pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.common

Singleton {
    id: root

    function init() {
        if (!Mem.ready && !Mem.states.desktop.firstRun)
            return;

        setupVariables();
        createXDPH();
        WallpaperService.applyWallpaper(Paths.wallpapers.defaultBg);
    }

    function createXDPH() {
        const config = Paths.methods.trim(Paths.standard.config);

        Paths.methods.createFileWith(config + "/hypr/xdph.conf", `
screencopy {
    custom_picker_binary = ${config}/noon/scripts/screen_share_watcher
}
        `);
    }

    function setupVariables() {
        Mem.states.desktop.firstRun = false;
        Mem.options.desktop.shell.mode = "main";
    }
}
