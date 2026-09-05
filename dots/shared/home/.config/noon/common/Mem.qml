pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Noon.Utils
import Noon.Hypr
import qs.common.utils
import qs.data

Singleton {
    id: root

    readonly property bool ready: optionsView.loaded && statesView.loaded
    readonly property var states: statesView.data
    readonly property var options: optionsView.data
    readonly property var store: storeView.data
    readonly property var looks: looksView.data
    readonly property var ai: aiView.data
    readonly property var todo: todoView.data
    readonly property var games: gamesView.data
    readonly property var colors: colorsView.data
    readonly property var beats: beatsView.data
    readonly property var pkgs: pkgsView.data

    readonly property var hypr: hyprView.variables
    readonly property var env: envView.data

    readonly property EnvManager envView: EnvManager {
        path: Paths.standard.home + "/.env"
    }

    readonly property HyprParser hyprView: HyprParser {
        path: Paths.methods.trim(Paths.standard.config + "/hypr/lua/variables.lua")
    }

    readonly property ConfigFileView optionsView: ConfigFileView {
        state: false
        fileName: "options"
        OptionsSchema {}
    }

    readonly property ConfigFileView statesView: ConfigFileView {
        fileName: "states"
        StatesSchema {}
    }

    readonly property ConfigFileView storeView: ConfigFileView {
        watchChanges: false
        fileName: "store"
        StoreSchema {}
    }

    readonly property ConfigFileView gamesView: ConfigFileView {
        state: false
        parentDir: "user/"
        fileName: "games"
        GamesSchema {}
    }

    readonly property ConfigFileView aiView: ConfigFileView {
        state: false
        parentDir: "user/"
        fileName: "ai"
        HarnessSchema {}
    }

    readonly property ConfigFileView todoView: ConfigFileView {
        state: false
        parentDir: "user/"
        fileName: "todo"
        TodoSchema {}
    }

    readonly property ConfigFileView beatsView: ConfigFileView {
        state: false
        parentDir: "user/"
        fileName: "beats"
        BeatsSchema {}
    }

    readonly property ConfigFileView colorsView: ConfigFileView {
        state: false
        parentDir: "user/"
        fileName: "colors"
        ColorsSchema {}
    }

    readonly property ConfigFileView looksView: ConfigFileView {
        state: false
        parentDir: "user/"
        fileName: "looks"
        LooksSchema {}
    }

    readonly property ConfigFileView pkgsView: ConfigFileView {
        state: false
        parentDir: "user/"
        fileName: "packages"
        PackagesSchema {}
    }
}
