import qs.common.utils

JsonAdapter {
    // Todo create own fileview for those
    property JO applications: JO {
        property JO settings: JO {
            property string cat: ""
            property bool sidebar_expanded: true
            property bool sidebar_pinned: true
            property int appearance_mode: 1
        }
        property JO reader: JO {
            property string currentFile: ""
            property bool sidebar_expanded: true
            property bool sidebar_pinned: true
            property int appearance_mode: 1
        }
    }

    property JO desktop: JO {
        property bool firstRun: true

        property JO dialogs: JO {
            property string lastIncubatedCategory: ""
        }

        property JO shell: JO {
            property bool deload: false
        }

        property JO icons: JO {
            property int iconSize: 48
            property int sortMode: 1
            property bool snapToGrid: true
            property var positions: []
        }

        property JO clock: JO {
            property real x: 0
            property real y: 0
            property bool arabicMode: false
            property bool editMode: false
            property bool center: false
            property real scale: 1
        }
    }

    property JO services: JO {
        property JO kdeconnect: JO {
            property int selectedDeviceIndex: 0
            property var connectedDevices: []
        }

        property JO bookmarks: JO {
            property list<var> firefoxBookmarks: []
        }

        property JO notes: JO {
            property string currentFile: "noon_notes.md"
        }

        property JO notifications: JO {
            property bool silent: false
        }

        property JO record: JO {
            property bool fullscreen: true
            property bool audio: true
            property int duration: 200
        }

        property JO emojis: JO {
            property list<var> frequentEmojies: []
        }

        property JO nightLight: JO {
            property bool enabled: false
            property int temperature: 3600
        }

        property JO power: JO {
            property string controller: ""
            property string mode: ""
            property list<var> modes: []
        }

        property JO timers: JO {
            property list<var> timers: []
            property int nextTimerId: 1
        }

        property JO beats: JO {
            property int pageIndex: 0
            property var previewData: ({})
            property bool discoverMode: false
            property bool shuffleTracks: false
            property bool shuffleHits: false
            property int searchLimit: 128
            property list<var> hits: []
        }
    }

    property JO fonts: JO {
        property JO variableAxes: JO {
            property JO display: JO {
                property int wght: 100
                property int wdth: 100
                property int ital: 100
                property int slnt: 100
                property int opsz: 100
            }
        }
    }

    property JO dock: JO {
        property bool pinned: false
    }

    property JO sidebar: JO {
        property JO shelf: JO {
            property list<string> filePaths: []
        }

        property JO widgets: JO {
            property list<string> order: []
            property list<string> enabled: []
            property list<string> desktop: ["cal", "resources", "dino"]
            property list<string> pilled: ["dino"]
            property list<string> pinned: []
            property list<string> expanded: []
        }

        property JO apis: JO {
            property int selectedTab: 0
            property real fontScale: 1
        }
    }

    property JO favorites: JO {
        property var apps: [
            {
                "appId": "firefox",
                "gid": null
            },
            {
                "appId": "kitty",
                "gid": null
            },
            {
                "appId": "obsidian",
                "gid": null
            },
            {
                "appId": "zen",
                "gid": null
            },
            {
                "appId": "org.kde.dolphin",
                "gid": "files"
            },
            {
                "appId": "io.github.Qalculate.qalculate-qt",
                "gid": "utilities"
            },
            {
                "appId": "systemsettings",
                "gid": "utilities"
            },
            {
                "appId": "pavucontrol-qt",
                "gid": "utilities"
            },
        ]
        property list<string> recentApps: ["vesktop", "kitty", "spotify", "heroic", "foot", "firefox"]
        property list<string> fastLaunchApps: ["heroic", "codium", "steam"]
        property list<string> desktopApps: ["org.kde.dolphin", "foot"]
    }
}
