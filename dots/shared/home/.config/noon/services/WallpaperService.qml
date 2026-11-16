pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.functions

Singleton {
    id: root

    property var thumbnailsData: ({})
    property bool fgReady: false
    property string lastPositionedFg: ""
    readonly property bool depthMode: Mem.options.desktop.bg.depthMode
    readonly property bool autoProcessFg: Mem.options.desktop.bg.autoProcessFg
    readonly property string currentWallpaper: Mem?.looks?.currentBg ?? Qt.resolvedUrl(Paths.wallpapers.defaultBg)
    readonly property string currentFgPath: getFgPathOf(currentWallpaper)
    readonly property string currentFolderPath: Mem.looks.currentFolder

    property bool wallpaperFolderSlash: false
    property int wallpaperRevision: 0
    readonly property string wallpaperFolder: {
        const base = String(root.currentFolderPath).replace(/\/+$/, "");
        return base + (root.wallpaperFolderSlash ? "/" : "");
    }
    readonly property var availableShaders: {
        const shaders = [];
        for (let i = 0; i < shaderModel.count; i++) {
            const name = String(shaderModel.get(i, "fileName")).replace(/\.frag\.qsb$/, "");
            if (name.length > 0)
                shaders.push(name);
        }
        return shaders;
    }
    readonly property Process thumbnailGenerator: Process {}
    readonly property FolderListModel shaderModel: FolderListModel {
        folder: Qt.resolvedUrl(Paths.wallpapers.shaders)
        nameFilters: ["*.frag.qsb"]
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Name
    }
    readonly property FolderListModel wallpaperModel: FolderListModel {
        folder: root.wallpaperFolder
        nameFilters: [...NameFilters.picture, ...NameFilters.video]
        showDirs: false
        showFiles: true
        sortField: FolderListModel[TextUtils.capitalizeFirstLetter(Mem.options.services.wallpapers.order)]
        onCountChanged: root.generateThumbnails(root.currentFolderPath)
        onSortFieldChanged: root.wallpaperFolderSlash = !root.wallpaperFolderSlash
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.wallpaperRevision++;
        }
    }
    readonly property FileView thumbsView: FileView {
        watchChanges: true
        blockWrites: true
        path: root.currentFolderPath + "/.thumbnails.json"
        onFileChanged: {
            const out = this.text();
            try {
                root.thumbnailsData = JSON.parse(out);
            } catch (e) {
                console.error("Thumbnails: Failed to parse " + this.path);
            }
        }
    }

    onCurrentWallpaperChanged: Qt.callLater(syncFg)

    Timer {
        interval: 500
        repeat: true
        running: root.depthMode && root.autoProcessFg && !root.fgReady
        onTriggered: {
            root.fgReady = Paths.methods.exists(root.currentFgPath);
            if (root.fgReady)
                root.autoPosClock();
        }
    }

    function syncFg() {
        if (!Mem.ready)
            return;
        root.fgReady = root.depthMode && Paths.methods.exists(root.currentFgPath);
        if (root.fgReady)
            autoPosClock();
        else if (root.depthMode && root.autoProcessFg)
            GowallService.removeBackground(root.currentWallpaper);
    }

    function autoPosClock() {
        if (!root.fgReady || !root.depthMode)
            return;
        if (root.currentFgPath === root.lastPositionedFg)
            return;
        root.lastPositionedFg = root.currentFgPath;
        const clock = Mem.states.desktop.clock;
        const aspect = Math.min(5, Math.max(0.2, Globals.clockAspect || (clock.horizontal ? 1.9 : 0.48)));
        posProc.running = false;
        posProc.command = ["python3", Paths.scriptsDir + "/position_clock.py", clean(currentFgPath), String(aspect)];
        posProc.running = true;
    }

    function getFgPathOf(fileUrl) {
        return clean(Paths.wallpapers.depthDir + Qt.md5(clean(fileUrl)) + ".png");
    }

    function clean(fileUrl) {
        return Paths.methods.trim(fileUrl);
    }

    function shaderPathFor(name) {
        return name ? Paths.wallpapers.shaders + "/" + name + ".frag.qsb" : "";
    }

    function generateThumbnails(directory) {
        if (thumbnailGenerator.running)
            return;
        const cmd = ["python3", Paths.wallpapers.thumbScript, "-d", clean(directory)];
        thumbnailGenerator.command = cmd;
        thumbnailGenerator.running = true;
    }

    function getThumbnailPath(fileUrl) {
        if (!fileUrl)
            return "";
        const cleanPath = clean(fileUrl);
        const cleanDir = clean(currentFolderPath);
        if (!cleanPath.startsWith(cleanDir + "/"))
            return "";
        const rel = cleanPath.slice(cleanDir.length + 1);
        return (root.thumbnailsData?.files ?? {})[rel]?.thumbnailUri ?? "";
    }

    function updateScheme(selectedMode) {
        _cmd("set", `${clean(root.currentWallpaper)}`, "--scheme", `${selectedMode}`);
    }

    function toggleShellMode() {
        _cmd("mode", "toggle");
    }

    function _cmd(...args) {
        if (mainProc.running)
            mainProc.running = false;
        mainProc.command = ["python3", Paths.wallpapers.colGenScript, ...args];
        mainProc.running = true;
    }

    function loadJson(file) {
        _cmd("json", `${clean(file)}`);
    }

    function pickAccentColor() {
        _cmd("pick");
    }

    function changeAccentColor(color) {
        _cmd("color", `${color}`);
    }

    function changeAccentFromImage(file) {
        _cmd("set", `${clean(file)}`);
    }

    function applyWallpaper(fileUrl) {
        Mem.looks.currentBg = `${fileUrl}`;
        if (PaletteService.current === "auto")
            changeAccentFromImage(fileUrl);
        Paths.methods.createLink(Mem.looks.currentBg, Paths.standard.home + "/.wall.png");
    }

    function applyRandomWallpaper() {
        if (wallpaperModel.count > 0)
            applyWallpaper(wallpaperModel.get(Math.floor(Math.random() * wallpaperModel.count), "fileUrl"));
    }

    Fetcher {
        id: mainProc
        autoRun: false
        mute: true
        onDataChanged: if (this.data) {
            const binds = ["mode", "scheme", "isBright", "isLive", "extractedColor"];
            binds.forEach(i => {
                if (data[i] !== undefined)
                    Mem.looks[i] = mainProc.data[i];
            });
        }
    }

    Fetcher {
        id: posProc
        onDataChanged: if (this.data) {
            const binds = ["fitX", "fitY", "fitW", "fitH"];
            binds.forEach(i => {
                Mem.states.desktop.clock[i] = posProc.data[i];
            });
        }
    }
}
