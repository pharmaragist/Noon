pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Qt.labs.platform
import qs.common.functions

Singleton {
    id: root

    readonly property QtObject methods: FileUtils
    readonly property string venv: methods.trim(standard.state + "/.venv")
    readonly property string store: methods.trim(standard.config + "/noon/store")
    readonly property string assets: methods.trim(standard.config + "/noon/assets")
    readonly property string shellConfigs: methods.trim(standard.home + "/.noon")
    readonly property string shellDir: methods.trim(standard.config + "/noon")
    readonly property string scriptsDir: shellDir + "/scripts"


    readonly property QtObject standard: QtObject {
        readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
        readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
        readonly property string state: home + "/.local/state/noon"
        readonly property string share: home + "/.local/share"
        readonly property string cache: home + "/.cache/noon"
        readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
        readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
        readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0]
        readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
        readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]
    }


    readonly property QtObject services: QtObject {
        readonly property string latex: methods.trim(standard.cache + "/media/latex")
        readonly property string opencodeDb: methods.trim(standard.share + "/opencode/opencode.db")
        readonly property string skills: methods.trim(standard.config + "/opencode/skills")
        readonly property string m3path: methods.trim(standard.state + "/user/generated/colors.json")
        readonly property string gamesCoverArts: methods.trim(standard.state + "/user/generated/gamesCoverArts")
        readonly property string screenshots: methods.trim(standard.pictures + "/Screenshots")
        readonly property string screenTimeDB: methods.trim(standard.state + "/screenTime")
        readonly property string clipboardCache: methods.trim(standard.cache + "/media/clipboard")
        readonly property string records: methods.trim(standard.videos + "/records")
        readonly property string favicons: methods.trim(standard.cache + "/media/favicons")
    }


    readonly property QtObject wallpapers: QtObject {
        readonly property string defaultBg: methods.trim(root.assets + "/images/default_wallpaper.png")
        readonly property string colGenScript: methods.trim(root.scriptsDir + "/colgen_service.py")
        readonly property string thumbScript: methods.trim(root.scriptsDir + "/thumbnails_service.py")
        readonly property string main: methods.trim(standard.pictures + "/Wallpapers/")
        readonly property string depthDir: methods.trim(standard.cache + "/user/generated/depth/")
        readonly property string gowallDir: methods.trim(standard.cache + "/user/generated/gowall/")
    }

    readonly property QtObject plugins: QtObject {
        readonly property string main: methods.trim(standard.home + "/.noon_plugins")
        readonly property string dock: main + "/dock"
        readonly property string sidebar: main + "/sidebar"
        readonly property string palettes: main + "/palettes"
    }
}
