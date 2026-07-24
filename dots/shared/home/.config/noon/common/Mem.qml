pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Noon.Utils
import Noon.Hypr
import qs.common.utils
import qs.store

Singleton {
    id: root

    readonly property bool ready: optionsView.loaded && statesView.loaded
    readonly property alias states: statesView.data
    readonly property alias options: optionsView.data
    readonly property alias store: storeView.data
    readonly property alias looks: looksView.data
    readonly property alias ai: aiView.data
    readonly property alias todo: todoView.data
    readonly property alias games: gamesView.data
    readonly property alias colors: colorsView.data
    readonly property alias beats: beatsView.data

    readonly property alias hypr: hyprView.variables
    readonly property alias env: envView.data

    EnvManager {
        id: envView
        path: Directories.standard.home + "/.env"
    }

    HyprParser {
        id: hyprView
        path: Directories.hyprConfigs + "/lua/variables.lua"
    }

    ConfigFileView {
        id: optionsView

        state: false
        fileName: "options"
        OptionsSchema {}
    }

    ConfigFileView {
        id: statesView

        fileName: "states"
        StatesSchema {}
    }

    ConfigFileView {
        id: storeView

        watchChanges: false
        fileName: "store"
        StoreSchema {}
    }

    ConfigFileView {
        id: gamesView
        state: false
        parentDir: "user/"
        fileName: "games"
        GamesSchema {}
    }

    ConfigFileView {
        id: aiView
        state: false
        parentDir: "user/"
        fileName: "ai"
        AiSchema {}
    }

    ConfigFileView {
        id: todoView
        state: false
        parentDir: "user/"
        fileName: "todo"
        TodoSchema {}
    }

    ConfigFileView {
        id: beatsView
        state: false
        parentDir: "user/"
        fileName: "beats"
        BeatsSchema {}
    }

    ConfigFileView {
        id: colorsView
        state: false
        parentDir: "user/"
        fileName: "colors"
        ColorsSchema {}
    }

    ConfigFileView {
        id: looksView
        state: false
        parentDir: "user/"
        fileName: "looks"
        LooksSchema {}
    }
}
