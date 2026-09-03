import qs.common
import qs.common.utils
import qs.services
import QtQuick
import Quickshell

JsonAdapter {
    property JO appearance: JO {
        property real paddingScale: 1

        property JO animations: JO {
            property real scale: 1
            property string curve: "standard"
        }
        property JO colors: JO {
            property string palettePath: "auto"
        }

        property JO transparency: JO {
            property bool blur: true
            property bool enabled: false
            property real scale: 0.35
        }

        property JO rounding: JO {
            property bool syncCompositor: false
            property real scale: 1
            property real power: 2
        }

        property JO icons: JO {
            property bool tint: false
        }

        property JO effects: JO {
            property bool shaders: false
            property string currentShader: "aero"
            property var availableShaders: []
            property bool showCirclesOnPanel: true
            property int circleCount: 3
        }
    }

    property JO audio: JO {
        property JO protection: JO {
            property bool enable: false
            property real maxAllowedIncrease: 100
            property real maxAllowed: 150
        }
    }

    property JO interactions: JO {
        property JO scrolling: JO {
            property bool fasterTouchpadScroll: true
            property int mouseScrollDeltaThreshold: 120
            property int mouseScrollFactor: 120
            property int touchpadScrollFactor: 600
        }
        property bool mouseOriented: false
    }

    property JO apps: JO {
        property string bluetooth: "kcmshell6 kcm_bluetooth"
        property string network: "plasmawindowed org.kde.plasma.networkmanagement"
        property string networkEthernet: "kcmshell6 kcm_networkmanagement"
    }

    property JO services: JO {
        property JO search: JO {
            property int nonAppResultDelay: 120
            property bool sloppy: false
        }

        property JO idle: JO {
            property int timeOut: 120
            property bool inhibit: false
        }

        property JO time: JO {
            property bool use12HourFormat: true
        }

        property JO timers: JO {
            property list<var> customPresets: [
                {
                    "duration": 1500,
                    "icon": "timer",
                    "name": "Example Timer"
                },
            ]
        }

        property JO weather: JO {
            property bool useFehrenheit: false
            property string location: "Cairo"
        }

        property JO nightLight: JO {
            property bool autoNightLightCycle: false
            property string autoStart: "20:00"
            property string autoEnd: "06:00"
            property int autoDayTemp: 6400
            property int autoNightTemp: 3500
        }

        property JO translator: JO {
            property int delay: 100
            property string engine: "auto"
            property string targetLanguage: "العربية"
            property string sourceLanguage: "auto"
        }

        property JO wallpapers: JO {
            property string method: "wallhaven"
        }

        property string backlightDevice: "dell::kbd_backlight"
        property bool easyEffects: false
        property list<string> autoExecAppsList: ["vesktop", "telegram-desktop"]
    }

    property JO battery: JO {
        property bool autoConservativeMode: true
        property bool automaticSuspend: true
        property int low: 20
        property int critical: 5
        property int suspend: 2
    }

    property JO beam: JO {
        property JO appearance: JO {
            property real animationScale: 1.0
            property string animationStyle: "expo"
        }
        property JO behavior: JO {
            property bool enableOldContent: false
            property bool scrollToReveal: true
            property bool enableApplets: true
            property string defaultState: "ai"
            property list<string> enabledApplets: ["music", "weather"]
        }
    }

    property JO sidebar: JO {
        property bool pinned: false

        property JO shelf: JO {
            property int previewDelay: 250
        }

        property JO content: JO {
            property bool apps: true
            property bool screenTime: true
            property bool apis: true
            property bool shelf: true
            property bool tasks: true
            property bool notifs: true
            property bool notes: true
            property bool beats: true
            property bool tweaks: true
            property bool wallpapers: true
            property bool games: true
            property bool session: true
            property bool widgets: true
            property bool overview: false
            property bool sounds: true
            property bool timers: true

            property bool history: false
            property bool bookmarks: false
            property bool emojies: false
        }

        property JO behavior: JO {
            property bool overlay: false
            property bool preExpand: false
            property bool aiTextFadeIn: false
            property bool enableResizeOverlay: true
        }

        property JO navRail: JO {
            property string style: "float"
            property string indicatorStyle: "button"
            property bool showNavTitles: false
        }

        property JO appearance: JO {
            property string style: "float"
            property string toolbarStyle: "tool"
            property real itemListScale: 1
            property bool showSliders: true
            property bool showVolumeInputSlider: false
            property bool alternateListStripes: true
        }
    }

    property JO osd: JO {
        property int timeout: 3000
        property bool enabled: true
    }

    property JO networking: JO {
        property string userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        property string sidebarAgent: "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.6312.86 Mobile Safari/537.36"
        property string searchEngine: "google"
    }

    property JO desktop: JO {
        property string screenCorners: "Top"
        property bool timerOverlayMode: true
        property list<string> customResolutions: []
        property bool enableFrame: false

        property JO branding: JO {
            property string logo: "distro"
            property string materialSymbol: "auto_awesome"
        }

        property JO toasts: JO {
            property bool enabled: true
        }

        property JO shell: JO {
            property bool deloadOnFullscreen: false
            property string mode: "main"
        }

        property JO widgets: JO {
            property bool enabled: false
            property string mode: "col"
        }

        property JO osd: JO {
            property string mode: "BottomPill"
        }

        property JO popups: JO {
            property string notifications: "TopRight"
        }

        property JO bg: JO {
            property bool depthMode: false

            property JO parallax: JO {
                property bool enabled: false
                property bool widgetParallax: false
                property bool verticalParallax: false
                property real parallaxStrength: 0.0
            }

            property JO live: JO {
                property int framerate: 24
            }
        }

        property JO clock: JO {
            property bool enabled: false
            property real scale: 1
            property real spacingMultiplier: 0.3
            property bool verticalMode: true
            property string font: "Badeen Display"
        }

        property JO icons: JO {
            property bool enabled: false
            property string currentIconTheme: "Breeze"
            property var substitutions: ({
                    "dev.zed.zed": "zed",
                    "code-url-handler": "visual-studio-code",
                    "Code": "visual-studio-code",
                    "gnome-tweaks": "org.gnome.tweaks",
                    "pavucontrol-qt": "pavucontrol",
                    "wps": "wps-office2019-kprometheus",
                    "wpsoffice": "wps-office2019-kprometheus",
                    "footclient": "foot",
                    "zen": "zen-browser",
                    "brave-browser": "brave-desktop"
                })
            property var regexSubstitutions: [
                {
                    "regex": /^steam_app_(\d+)$/,
                    "replace": "steam_icon_$1"
                },
                {
                    "regex": /Minecraft.*/,
                    "replace": "minecraft"
                },
                {
                    "regex": /.*polkit.*/,
                    "replace": "system-lock-screen"
                },
                {
                    "regex": /gcr.prompter/,
                    "replace": "system-lock-screen"
                }
            ]
        }

        property JO behavior: JO {
            property JO sounds: JO {
                property bool enabled: true
                property real level: 0.75
            }
        }
    }

    property JO bar: JO {

        property JO horizontal: JO {
            property string position: "top"
            property string layout: "Dynamic"
            property list<var> presets: []

            property JO map: JO {
                property int spacing: 5
                property list<string> leftArea: ["workspaces"]
                property list<string> centerArea: ["media", "separator", "clock"]
                property list<string> rightArea: ["inlineTray", "materialStatusIcons"]
            }

            property JO appearance: JO {
                property string style: "concave"
                property string separatorsMode: "thin"
                property bool enableSeparators: true
                property bool useBg: true
                property bool barGroup: false
                property bool outline: true
                property int size: 50
            }
        }

        property JO vertical: JO {
            property string position: "left"
            property string layout: "VDynamic"
            property list<var> presets: []

            property JO map: JO {
                property int spacing: 5
                property list<string> topArea: ["materialStatusIcons", "inlineTray"]
                property list<string> centerArea: []
                property list<string> bottomArea: ["workspaces", "separator", "clock", "separator", "keyboard"]
            }

            property JO appearance: JO {
                property string style: "concave"
                property string separatorsMode: "thin"
                property bool enableSeparators: true
                property bool useBg: true
                property bool barGroup: false
                property bool outline: true
                property int size: 50
            }
        }

        property JO behavior: JO {
            property bool autoHide: false
            property bool showOnAll: true
        }

        property JO resources: JO {
            property bool alwaysShow: false
            property list<string> enabledMetrics: ["memory", "cpu_temp", "cpu_usage", "swap"]
        }

        property JO statusIcons: JO {
            property list<string> enabledStatusIcons: ["network", "bluetooth", "overheat", "polkit", "silent", "battery", "record", "mute"]
            property bool useLegacyBatteryIcons: false
            property string batteryMode: "symbol"
            property bool showTextWhenAvailable: false
        }

        property JO utils: JO {
            property list<var> customUtils: [
                {
                    "icon": "colorize",
                    "action": ["hyprpicker", "-a", "-q"]
                }
            ]
        }

        property JO workspaces: JO {
            property int number: 6
            property bool showAppIcons: true
            property bool showBigAppOnly: false
            property bool genericSymbols: false
            property string displayMode: "normal"
            property string customFallback: "●"
            property list<string> customMapping: []
            property string unicodeChar: "♡"
            property string unicodeMode: "unicode"
        }
    }

    property JO dock: JO {
        property bool enabled: false
        property int animationDuration: 200

        property JO appearance: JO {
            property real iconSize: 100 * iconSizeMultiplier
            property real iconSizeMultiplier: 0.5
            property string style: "float"
        }
    }

    property JO hacks: JO {
        property int arbitraryRaceConditionDelay: 150
    }
}
