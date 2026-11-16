pragma Singleton
import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.functions

Singleton {
    id: root

    enum Regions {
        Full,
        Part,
        Window
    }

    readonly property string mainDir: Paths.services.screenshots
    readonly property string tempPrefix: "/tmp/noon_ss_"
    readonly property bool isBusy: mainProc.running
    readonly property bool hasRegion: regionW > 0 && regionH > 0
    readonly property Process sattyProc: Process {}

    property bool isSelecting: false
    property bool openSatty: false
    property real regionX: 0
    property real regionY: 0
    property real regionW: 0
    property real regionH: 0

    signal screenshotCompleted(string path)
    signal screenshotCancelled()

    function delete_temp(): void {
        NoonUtils.execDetached(["sh", "-c", `rm -f ${tempPrefix}*.png`]);
    }

    function startRegionSelect(): void {
        isSelecting = true;
    }

    function setRegion(x, y, w, h): void {
        regionX = x;
        regionY = y;
        regionW = w;
        regionH = h;
        isSelecting = false;
    }

    function clearRegion(): void {
        regionX = 0;
        regionY = 0;
        regionW = 0;
        regionH = 0;
    }

    function execute(out: string, args: list<string>): void {
        mainProc.running = false;
        mainProc.outPath = out;
        mainProc.command = args;
        mainProc.running = true;
    }

    Process {
        id: mainProc
        property string outPath: ""
        environment: ({
            "XDG_SCREENSHOTS_DIR": Paths.methods.trim(mainDir)
        })
        onExited: code => {
            const finishedPath = outPath;
            outPath = "";
            if (code === 0 && finishedPath.length > 0) {
                root.screenshotCompleted(finishedPath);
                NoonUtils.execDetached(`wl-copy --type image/png < '${TextUtils.shellSingleQuoteEscape(finishedPath)}'`);
                if (root.openSatty) {
                    root.openSatty = false;
                    sattyProc.running = false;
                    sattyProc.command = ["satty", "--filename", finishedPath];
                    sattyProc.running = true;
                }
            } else {
                root.openSatty = false;
                root.screenshotCancelled();
            }
        }
    }

    function takeWindowScreenshot(path: string): void {
        if (!path)
            return;
        execute(path, ["grimblast", "save", "area", path]);
    }

    function takeFullScreenshot(path: string): void {
        if (!path)
            return;
        execute(path, ["grim", path]);
    }

    function takeRegionScreenshot(path: string): void {
        if (!path)
            return;
        const r = n => Math.round(n);
        execute(path, ["grim", "-g", `${r(root.regionX)},${r(root.regionY)} ${r(root.regionW)}x${r(root.regionH)}`, path]);
    }

    function hideUI() {
        Globals.main.showScreenshot = false;
        Globals.main.beam.show = false;
        Globals.main.beam.reason = "default";
    }

    function request(obj): void {
        if (!obj)
            return;

        hideUI();
        const stamp = new Date().toISOString().replace(/[:.]/g, "-");
        const outPath = obj.temp
            ? `${root.tempPrefix}${stamp}.png`
            : `${root.mainDir}/screenshot-${stamp}.png`;

        root.openSatty = !obj.temp;

        const actions = {
            [ScreenShotService.Regions.Full]: () => root.takeFullScreenshot(outPath),
            [ScreenShotService.Regions.Window]: () => root.takeWindowScreenshot(outPath),
            [ScreenShotService.Regions.Part]: () => root.takeRegionScreenshot(outPath)
        };

        NoonUtils.inlineTimer(() => {
            actions[obj.region]();
        }, 500);
    }
}
