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
        readonly property string screenshots: methods.trim(standard.pictures + "/Screenshots")
        readonly property string screenTimeDB: methods.trim(standard.state + "/screenTime")
        readonly property string clipboardCache: methods.trim(standard.cache + "/media/clipboard")
        readonly property string records: methods.trim(standard.videos + "/records")
        readonly property string favicons: methods.trim(standard.cache + "/media/favicons")
        readonly property string onlineWallThumbs: methods.trim(standard.cache + "/media/online-wallpapers/thumbs")
        readonly property string harnessDir: methods.trim(standard.state + "/harness")
    }


    readonly property QtObject wallpapers: QtObject {
        readonly property string defaultBg: methods.trim(root.assets + "/images/default_wallpaper.png")
        readonly property string matugenConfig: methods.trim(root.standard.config) + "/matugen/config.toml"
        readonly property string shaders: methods.trim(standard.pictures + "/Wallpapers/Shaders")
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

    readonly property QtObject scripts: QtObject {
        readonly property string base: root.scriptsDir

        // Language roots
        readonly property string bin: base + "/bin"
        readonly property string python: base + "/python"
        readonly property string bash: base + "/bash"

        // Binaries
        readonly property string beats: bin + "/beats"
        readonly property string weather: bin + "/weather"
        readonly property string npc: bin + "/npc"
        readonly property string screenShareWatcher: bin + "/screen_share_watcher"
        readonly property string harness: bin + "/harness"
        readonly property string positionClock: bin + "/position_clock"
        readonly property string thumbnails: bin + "/thumbnails"
        readonly property string colors: bin + "/colors"
        readonly property string icons: bin + "/icons"
        readonly property string thawb: bin + "/thawb"
        readonly property string packages: bin + "/packages"
        readonly property string store: bin + "/store"

        // Python
        readonly property string dlp: python + "/dlp.py"

        // Bash
        readonly property string deleteOpencodeSessions: bash + "/delete_opencode_sessions.sh"
        readonly property string getCursors: bash + "/get_cursors.sh"
        readonly property string getFonts: bash + "/get_fonts.sh"
        readonly property string getSounds: bash + "/get_sounds.sh"
        readonly property string pluginsHelper: bash + "/plugins_helper.sh"
        readonly property string power: bash + "/power.sh"
        readonly property string previewMermaid: bash + "/preview_mermaid.sh"
        readonly property string record: bash + "/record.sh"
        readonly property string reloadShell: bash + "/reload_shell.sh"
        readonly property string sanitizeYoutubeUrl: bash + "/sanitize_youtube_url.sh"
        readonly property string screenshotHelper: bash + "/screenshot_helper.sh"
        readonly property string setFace: bash + "/set_face.sh"
        readonly property string syncFonts: bash + "/sync_sys_fonts.sh"
        readonly property string updateDistro: bash + "/update_distro.sh"
    }
}
