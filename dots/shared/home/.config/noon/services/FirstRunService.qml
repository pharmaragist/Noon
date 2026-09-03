pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.common

Singleton {
    id: root

    function init() {
        if (!Mem.ready && !Mem.states.desktop.firstRun)
            return;

        doFlags();
        doXDPH();
        doPaths();
        doEnv();
        WallpaperService.applyWallpaper(Paths.wallpapers.defaultBg);
    }

    function doEnv() {
        const needed = ({
                "SHELL": "/bin/fish",
                "XCURSOR_THEME": "Adwaita",
                "TERMINAL_OPACITY": 1,
                "USE_POKEMON": true,
                "GTK_CSD": 0
            });
        for (const [key, value] of Object.entries(needed)) {
            Mem?.envView?.ensure(key, value);
        }
    }
    function doPaths() {
        const p = Paths;
        p.methods.mkdir([p.standard.state, p.standard.cache, p.venv, p.assets, p.records, p.gallery, p.sounds, p.scriptsDir, p.shellConfigs, p.favicons, p.userOptions, p.services.latex, p.services.gamesCoverArts, p.services.screenshots, p.services.screenTimeDB, p.services.clipboardCache, p.wallpapers.main, p.wallpapers.depthDir, p.wallpapers.gowallDir, p.plugins.main, p.plugins.palettes, p.plugins.sidebar, p.plugins.dock]);
    }

    function doFlags() {
        Mem.states.desktop.firstRun = false;
        Mem.options.desktop.shell.mode = "main";
    }

    function doXDPH() {
        const config = Paths.methods.trim(Paths.standard.config);

        Paths.methods.createFileWith(config + "/hypr/xdph.conf", `
            screencopy { custom_picker_binary = ${config}/noon/scripts/screen_share_watcher }
        `);
    }
}
