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

    EnvManager {
        id: envView
        path: Paths.standard.home + "/.env"

        Component.onCompleted: {
            const needed = {
                "NOON_TASKS_ID": "",
                "NOON_TASKS_SECRET": "",
                "NOON_CALENDAR_SECRET": "",
                "NOON_CALENDAR_ID": "",
                "XCURSOR_THEME": "Adwaita",
                "TERMINAL_OPACITY": 1,
                "USE_POKEMON": true,
                "GTK_CSD": 0
            };
            for (const [key, value] of Object.entries(needed)) {
                envView.ensure(key, value);
            }
        }
    }

    HyprParser {
        id: hyprView
        path: Paths.hyprConfigs + "/lua/variables.lua"
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
        AiSchema {}
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
