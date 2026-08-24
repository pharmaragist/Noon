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
    readonly property bool fgReady: Paths.methods.exists(currentFgPath)
    readonly property string currentWallpaper: Mem.looks.currentBg ?? Qt.resolvedUrl(Paths.wallpapers.defaultBg)
    readonly property string currentFgPath: clean(Paths.wallpapers.depthDir + Qt.md5(clean(currentWallpaper)) + ".png")
    readonly property string currentFolderPath: Mem.looks.currentFolder
    readonly property bool isBright: Mem.looks.isBright

    readonly property Process mainProc: Process {}
    readonly property Process thumbnailGenerator: Process {}
    readonly property FolderListModel wallpaperModel: FolderListModel {
        folder: currentFolderPath
        nameFilters: [...NameFilters.picture, ...NameFilters.video]
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Time
        onCountChanged: root.generateThumbnails(root.currentFolderPath)
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

    function clean(fileUrl) {
        return Paths.methods.trim(fileUrl);
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
        _cmd("json", `${clean(file)}`)
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
}
