pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.common
import qs.common.functions

Singleton {
    id: root

    function init(force = false) {
        if (!force && !Mem.states.desktop.firstRun)
            return;

        doFlags();
        doXDPH();
        doPaths();
        doEnv();
        WallpaperService.applyWallpaper(Paths.wallpapers.defaultBg);
        console.warn("All Done !")
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
        console.warn("Environment Variables Are Set")
    }

    function doPaths() {
        const p = Paths;

        const batchCreate = group => {
            const gp = ObjectUtils.toPlainObject(p[group]);
            for (const path of Object.values(gp)) {
                p.methods.mkdir(path);
            }
        };
        batchCreate("standard");
        batchCreate("services");
        batchCreate("wallpapers");
        batchCreate("plugins");

        p.methods.mkdir([p.venv, p.shellConfigs]);
        console.warn("Paths Are Set")
    }

    function doFlags() {
        Mem.states.desktop.firstRun = false;
        Mem.options.desktop.shell.mode = "main";
        console.warn("Flags Are Set")
    }

    function doXDPH() {
        const config = Paths.methods.trim(Paths.standard.config);

        Paths.methods.createFileWith(config + "/hypr/xdph.conf", `
            screencopy { custom_picker_binary = ${config}/noon/scripts/screen_share_watcher }
        `);
        console.warn("Screen Sharing Hack is Set")
    }
}
