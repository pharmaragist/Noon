pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

Singleton {
    id: root

    readonly property var tweaks: [
        {
            "section": "Appearance",
            "icon": "palette",
            "shell": "Global",
            "items": [
                {
                    "icon": "animation",
                    "name": "Animation Curve",
                    "type": "combobox",
                    "values": Object.keys(Animations.curves),
                    "key": "appearance.animations.curve"
                },
                {
                    "icon": "rounded_corner",
                    "name": "Radius",
                    "hint": "Global rounding scale for all shell widgets",
                    "key": "appearance.rounding.scale",
                    "type": "slider",
                    "minValue": 0.25,
                    "maxValue": 2
                },
                {
                    "icon": "rounded_corner",
                    "name": "Screen Borders",
                    "hint": "Adds Frame Arround Desktop",
                    "key": "desktop.enableFrame"
                },
                {
                    "icon": "rounded_corner",
                    "name": "Screen Corners",
                    "hint": "Dark rounded overlays on screen corners",
                    "key": "desktop.screenCorners",
                    "type": "combobox",
                    "values": ["Disabled", "Top", "Overlay"]
                },
                {
                    "icon": "stars_2",
                    "name": "Icon Theme",
                    "hint": "Qt/GTK Icons to use.",
                    "key": "desktop.icons.currentIconTheme",
                    "type": "combobox",
                    "reloadOnChange": true,
                    "canRefresh": true,
                    "refreshAction": () => IconThemesService.reload(),
                    "values": IconThemesService.availableIconThemeIds
                },
                {
                    "icon": "arrow_selector_tool",
                    "name": "Cursor Theme",
                    "store": "hypr",
                    "key": "cursor_theme",
                    "type": "combobox",
                    "canRefresh": true,
                    "refreshAction": () => CursorsService.reload(),
                    "values": CursorsService.cursors
                },
                {
                    "icon": "ads_click",
                    "name": "Cursor Size",
                    "store": "hypr",
                    "key": "cursor_size",
                    "type": "spin"
                },
                {
                    "icon": "font_download",
                    "name": "UI Font",
                    "hint": "QT/GTK Global Font Used",
                    "key": "appearance.fonts.main",
                    "type": "font"
                },
                {
                    "icon": "palette",
                    "name": "Shell Mode",
                    "type": "combobox",
                    "hint": "Shell Presets Overhaul by Noon",
                    "values": ["main", "zen", "xp", "nobuntu"],
                    "key": "desktop.shell.mode"
                },
                {
                    "icon": "crop",
                    "name": "Depth Wallpaper",
                    "hint": "Depth layering effect on wallpaper foreground",
                    "enableTooltip": false,
                    "key": "desktop.bg.depthMode"
                },
                {
                    "icon": "palette",
                    "name": "Tint Icons Images",
                    "hint": "Tint icon images with accent color",
                    "key": "appearance.icons.tint"
                },
                {
                    "icon": "auto_awesome",
                    "name": "Branding Logo",
                    "hint": "Logo of the system",
                    "key": "desktop.branding.logo",
                    "type": "combobox",
                    "values": ["distro", "symbol"]
                },
                {
                    "icon": "palette",
                    "name": "Widgets Bg Mode",
                    "hint": "Desktop Widgets Bg Style (Non-Shader)",
                    "key": "desktop.widgets.mode",
                    "type": "combobox",
                    "values": ["col", "grad"]
                }
            ]
        },
        {
            "section": "Desktop",
            "icon": "wallpaper",
            "shell": "Global",
            "items": [
                {
                    "icon": "animation",
                    "name": "Beam Animation Style",
                    "type": "combobox",
                    "values": BeamData.availableAnimationStyles,
                    "hint": "Transition style for beam animations",
                    "key": "beam.appearance.animationStyle"
                },
                {
                    "icon": "masked_transitions",
                    "name": "Beam Animation Scale",
                    "type": "text",
                    "hint": "Scale multiplier for beam animations",
                    "key": "beam.appearance.animationScale"
                },
                {
                    "icon": "notifications",
                    "name": "Toasts",
                    "hint": "Show toast notifications on actions",
                    "key": "desktop.toasts.enabled"
                },
                {
                    "icon": "timer",
                    "name": "Desktop Clock",
                    "hint": "Show clock on desktop layer",
                    "key": "desktop.clock.enabled"
                },
                {
                    "icon": "brand_family",
                    "name": "Arabic Mode",
                    "hint": "Arabic numerals on layer clock",
                    "store": "states",
                    "key": "desktop.clock.arabicMode"
                },
                {
                    "icon": "timer",
                    "name": "Center Clock",
                    "hint": "Center clock in bar area",
                    "store": "states",
                    "enableTooltip": false,
                    "key": "desktop.clock.center"
                },
                {
                    "icon": "schedule",
                    "name": "Layer Clock Font",
                    "hint": "Font family for the layer clock",
                    "key": "desktop.clock.font",
                    "type": "combobox",
                    "values": Fonts.family.preferredLayerClockFonts
                },
                {
                    "icon": "notifications_active",
                    "name": "Notifications Position",
                    "hint": "Where popup notifications appear",
                    "key": "desktop.popups.notifications",
                    "type": "combobox",
                    "values": ["TopCenter", "TopRight", "TopLeft", "BottomCenter", "BottomRight", "bottomLeft"]
                },
                {
                    "store": "states",
                    "icon": "font_download",
                    "name": "Clock Weight",
                    "hint": "Variable font weight axis for clock",
                    "key": "fonts.variableAxes.display.wght",
                    "type": "slider",
                    "minValue": 100,
                    "maxValue": 1000
                },
                {
                    "store": "states",
                    "icon": "font_download",
                    "name": "Clock Width",
                    "hint": "Variable font width axis for clock",
                    "key": "fonts.variableAxes.display.wdth",
                    "type": "slider",
                    "minValue": 0,
                    "maxValue": 800
                },
                {
                    "icon": "height",
                    "name": "Vertical Mode",
                    "hint": "Stack clock numbers vertically",
                    "key": "desktop.clock.verticalMode"
                },
                {
                    "store": "states",
                    "icon": "timer",
                    "name": "Clock Size",
                    "hint": "Scale of the desktop clock",
                    "key": "desktop.clock.scale",
                    "type": "slider",
                    "minValue": 0.25,
                    "maxValue": 4
                },
                {
                    "icon": "extension",
                    "name": "Widgets",
                    "hint": "Show desktop widgets",
                    "key": "desktop.widgets.enabled"
                },
                {
                    "icon": "apps",
                    "name": "Desktop Icons",
                    "hint": "Show icons on desktop",
                    "key": "desktop.icons.enabled"
                },
                {
                    "icon": "width",
                    "name": "Parallax Effect",
                    "hint": "Wallpaper shifts with workspace",
                    "key": "desktop.bg.parallax.enabled"
                },
                {
                    "icon": "height",
                    "name": "Vertical Parallax",
                    "hint": "Parallax on Y axis instead of X",
                    "key": "desktop.bg.parallax.verticalParallax"
                },
                {
                    "icon": "image",
                    "name": "Deload On Fullscreen",
                    "hint": "Hide shell elements when app is fullscreen",
                    "key": "desktop.shell.deloadOnFullscreen"
                },
                {
                    "icon": "width",
                    "name": "Sidebar Parallax",
                    "hint": "Wallpaper shifts with sidebar open",
                    "key": "desktop.bg.parallax.widgetParallax"
                },
                {
                    "icon": "zoom_in_map",
                    "name": "Parallax Strength",
                    "type": "slider",
                    "maxValue": 1,
                    "hint": "Intensity of wallpaper parallax shift",
                    "key": "desktop.bg.parallax.parallaxStrength"
                }
            ]
        },
        {
            "section": "Compositor",
            "icon": "dashboard",
            "shell": "Global",
            "items": [
                {
                    "icon": "rounded_corner",
                    "name": "Window Rounding",
                    "store": "hypr",
                    "key": "rounding",
                    "type": "spin"
                },
                {
                    "icon": "rounded_corner",
                    "name": "Sync Rounding",
                    "hint": "Match compositor rounding to shell scale",
                    "key": "appearance.rounding.syncCompositor"
                },
                {
                    "icon": "shutter_speed",
                    "name": "Rounding Power",
                    "key": "rounding_power",
                    "type": "sliderStops",
                    "stepValue": 1,
                    "minValue": 1,
                    "maxValue": 4,
                    "store": "hypr"
                },
                {
                    "icon": "blur_on",
                    "name": "Blur",
                    "store": "hypr",
                    "key": "blur"
                },
                {
                    "icon": "blur_on",
                    "name": "Blur Passes",
                    "store": "hypr",
                    "key": "blur_passes",
                    "type": "spin"
                },
                {
                    "icon": "blur_on",
                    "name": "Blur Size",
                    "store": "hypr",
                    "key": "blur_size",
                    "type": "spin"
                },
                {
                    "icon": "blur_on",
                    "name": "X Ray",
                    "store": "hypr",
                    "key": "xray"
                },
                {
                    "icon": "grain",
                    "name": "Noise",
                    "type": "spin",
                    "store": "hypr",
                    "key": "noise"
                },
                {
                    "icon": "dark_mode",
                    "name": "Shadows",
                    "store": "hypr",
                    "key": "shadows"
                },
                {
                    "icon": "collapse_content",
                    "name": "Shadows Range",
                    "store": "hypr",
                    "key": "shadows_range",
                    "type": "spin"
                },
                {
                    "icon": "collapse_content",
                    "name": "Shadows Power",
                    "store": "hypr",
                    "key": "shadows_power",
                    "type": "spin"
                },
                {
                    "icon": "expand_content",
                    "name": "Gaps Out",
                    "store": "hypr",
                    "key": "gaps_out",
                    "type": "spin"
                },
                {
                    "icon": "collapse_content",
                    "name": "Gaps In",
                    "store": "hypr",
                    "key": "gaps_in",
                    "type": "spin"
                },
                {
                    "icon": "border_all",
                    "name": "Border Width",
                    "store": "hypr",
                    "key": "borders",
                    "type": "sliderStops",
                    "stepValue": 1,
                    "minValue": 0,
                    "maxValue": 5
                },
                {
                    "icon": "dashboard",
                    "name": "Tiling Layout",
                    "type": "combobox",
                    "store": "hypr",
                    "values": ["master", "dwindle", "scrolling", "monocle"],
                    "key": "layout"
                },
                {
                    "icon": "blur_on",
                    "name": "Animation Style",
                    "type": "combobox",
                    "store": "hypr",
                    "key": "animation_style",
                    "values": HyprlandService?.availableAnimations ?? []
                },
                {
                    "icon": "blur_on",
                    "name": "Animation Scale",
                    "type": "text",
                    "store": "hypr",
                    "key": "animation_scale"
                },
                {
                    "icon": "monitor",
                    "name": "External Monitor Profile",
                    "type": "combobox",
                    "store": "hypr",
                    "key": "external_monitor_mode",
                    "values": MonitorsInfo?.availableResolutions ?? []
                }
            ]
        },
        {
            "section": "Bar",
            "icon": "toolbar",
            "shell": "Main",
            "items": [
                {
                    "icon": "height",
                    "name": "Vertical Mode Style",
                    "type": "combobox",
                    "store": "states",
                    "values": BarData.verticalBarModes,
                    "key": "bar.vertical.layout"
                },
                {
                    "icon": "width",
                    "name": "Horizontal Mode Style",
                    "type": "combobox",
                    "store": "states",
                    "values": BarData.horizontalBarModes,
                    "key": "bar.horizontal.layout"
                },
                {
                    "icon": "border_all",
                    "name": "BarGroup",
                    "hint": "Group bar items into a single capsule",
                    "key": root.expandBarKey("appearance.barGroup")
                },
                {
                    "icon": "border_vertical",
                    "name": "Separator Style",
                    "key": root.expandBarKey("appearance.separatorsMode"),
                    "type": "combobox",
                    "values": BarData.separatorStyles
                },
                {
                    "icon": "border_all",
                    "name": "Outline",
                    "hint": "Border outline on float-style bar",
                    "key": root.expandBarKey("appearance.outline")
                },
                {
                    "icon": "tune",
                    "name": "Style",
                    "key": root.expandBarKey("appearance.style"),
                    "type": "combobox",
                    "values": BarData.appearanceModes
                },
                {
                    "icon": "width_full",
                    "name": "Size",
                    "key": root.expandBarKey("appearance.size"),
                    "type": "spin",
                    "minValue": 40,
                    "maxValue": 65
                },
                {
                    "icon": "visibility_off",
                    "name": "Auto Hide",
                    "hint": "Auto-hide bar until mouse hovers edge",
                    "key": "bar.behavior.autoHide"
                },
                {
                    "icon": "palette",
                    "name": "Use Background",
                    "hint": "Background fill behind bar items",
                    "key": root.expandBarKey("appearance.useBg")
                },
                {
                    "icon": "tv",
                    "name": "Show On All Monitors",
                    "hint": "Replicate bar on every monitor",
                    "key": "bar.behavior.showOnAll"
                },
                {
                    "icon": "graphic_eq",
                    "name": "Enable Audio Visualizer",
                    "key": "bar.behavior.enableVisualizer"
                },
                {
                    "icon": "padding",
                    "name": "Spacing",
                    "type": "spin",
                    "key": BarData.isVertical ? "bar.vMap.spacing" : "bar.hMap.spacing"
                },
                {
                    "icon": "font_download",
                    "name": "Show Text When Available",
                    "key": "bar.statusIcons.showTextWhenAvailable"
                },
                {
                    "icon": "battery_full",
                    "name": "Battery Style",
                    "key": "bar.statusIcons.batteryMode",
                    "type": "combobox",
                    "values": ["text", "symbol", "both"]
                },
                {
                    "icon": "123",
                    "name": "Workspaces Number",
                    "type": "spin",
                    "key": "bar.workspaces.number"
                },
                {
                    "icon": "graphic_eq",
                    "name": "Ws Mode",
                    "type": "combobox",
                    "values": WsData.availableModes,
                    "key": "bar.workspaces.displayMode"
                }
            ]
        },
        {
            "section": "Dock",
            "icon": "dock",
            "shell": "Main",
            "items": [
                {
                    "icon": "dock",
                    "name": "Dock",
                    "hint": "Show application dock",
                    "key": "dock.enabled"
                },
                {
                    "icon": "straighten",
                    "name": "Icon Size",
                    "key": "dock.appearance.iconSizeMultiplier",
                    "type": "slider",
                    "minValue": 0.4,
                    "maxValue": 1
                },
                {
                    "icon": "tune",
                    "name": "Style",
                    "key": "dock.appearance.style",
                    "type": "combobox",
                    "values": ["float", "convex", "sharp"]
                }
            ]
        },
        {
            "section": "Notifications",
            "icon": "notifications",
            "shell": "Main",
            "items": [
                {
                    "icon": "notifications",
                    "name": "OSD",
                    "hint": "On-screen display for volume/brightness",
                    "key": "osd.enabled"
                },
                {
                    "icon": "notifications",
                    "name": "OSD Mode",
                    "key": "desktop.osd.mode",
                    "type": "combobox",
                    "values": ["Pixel", "BottomPill", "CenterIsland", "SideBay"]
                }
            ]
        },
        {
            "section": "Sidebar",
            "icon": "view_sidebar",
            "shell": "Main",
            "items": [
                {
                    "icon": "tune",
                    "name": "Style",
                    "key": "sidebar.appearance.style",
                    "values": SidebarData.appearanceModes,
                    "type": "combobox"
                },
                {
                    "icon": "tune",
                    "name": "ToolBar Style",
                    "key": "sidebar.appearance.toolbarStyle",
                    "values": ["tab", "tool"],
                    "type": "combobox"
                },
                {
                    "icon": "width",
                    "name": "Overlay",
                    "hint": "Sidebar floats over windows",
                    "key": "sidebar.behavior.overlay"
                },
                {
                    "icon": "width",
                    "name": "Pre-Expand",
                    "hint": "Expand sidebar content on hover",
                    "key": "sidebar.behavior.preExpand"
                },
                {
                    "icon": "tune",
                    "name": "Navigation Rail Style",
                    "key": "sidebar.navRail.style",
                    "values": ["sidebar", "clear", ...SidebarData.appearanceModes],
                    "type": "combobox"
                },
                {
                    "icon": "width",
                    "name": "Swap Navigation Side",
                    "hint": "Sets nav to the outer side of sidebar",
                    "key": "sidebar.navRail.reverse"
                },
                {
                    "icon": "text_fields",
                    "name": "Show Nav Titles",
                    "hint": "Show text labels on nav rail buttons",
                    "key": "sidebar.navRail.showNavTitles"
                },
                {
                    "icon": "text_fields",
                    "name": "Navigation Rail Indicator Style",
                    "key": "sidebar.navRail.indicatorStyle",
                    "values": ["shape", "pill", "badge", "button"],
                    "type": "combobox"
                },
                {
                    "icon": "linear_scale",
                    "name": "Show Sliders",
                    "hint": "Show volume/brightness sliders in sidebar",
                    "key": "sidebar.appearance.showSliders"
                },
                {
                    "icon": "api",
                    "name": "APIs",
                    "key": "sidebar.content.apis"
                },
                {
                    "icon": "format_list_numbered",
                    "name": "Recall Limit",
                    "hint": "History messages per page (1-50)",
                    "key": "apis.recallLimit",
                    "type": "spin"
                },
                {
                    "icon": "supervisor_account",
                    "name": "Screen Time",
                    "key": "sidebar.content.screenTime"
                },
                {
                    "icon": "view_agenda",
                    "name": "Shelf",
                    "key": "sidebar.content.shelf"
                },
                {
                    "icon": "check_box",
                    "name": "Tasks",
                    "key": "sidebar.content.tasks"
                },
                {
                    "icon": "history",
                    "name": "History",
                    "key": "sidebar.content.history"
                },
                {
                    "icon": "bookmark",
                    "name": "Bookmarks",
                    "key": "sidebar.content.bookmarks"
                },
                {
                    "icon": "emoji_emotions",
                    "name": "Emojis",
                    "key": "sidebar.content.emojies"
                },
                {
                    "icon": "music_note",
                    "name": "Beats",
                    "key": "sidebar.content.beats"
                },
                {
                    "icon": "tune",
                    "name": "Tweaks",
                    "key": "sidebar.content.tweaks"
                },
                {
                    "icon": "image",
                    "name": "Wallpapers",
                    "key": "sidebar.content.wallpapers"
                },
                {
                    "icon": "dashboard_2",
                    "name": "Overview",
                    "key": "sidebar.content.overview"
                },
                {
                    "icon": "stylus",
                    "name": "Notes",
                    "key": "sidebar.content.notes"
                },
                {
                    "icon": "joystick",
                    "name": "Games",
                    "key": "sidebar.content.games"
                },
                {
                    "icon": "extension",
                    "name": "Widgets",
                    "key": "sidebar.content.widgets"
                }
            ]
        },
        {
            "section": "Media & Gaming",
            "icon": "music_note",
            "shell": "Main",
            "items": [
                {
                    "icon": "home",
                    "name": "Home Page Style",
                    "type": "combobox",
                    "store": "beats",
                    "values": ["PixelPlayer", "MaterialNoon"],
                    "key": "options.homePageStyle"
                },
                {
                    "icon": "palette",
                    "name": "Adaptive Theme",
                    "store": "beats",
                    "key": "options.adaptiveTheme"
                },
                {
                    "icon": "graphic_eq",
                    "name": "Visualizer Mode",
                    "type": "combobox",
                    "store": "beats",
                    "values": ["Filled", "Bars", "Waveform", "CapsuleWaves", "LineGlow"],
                    "key": "options.visualizerMode"
                },
                {
                    "icon": "palette",
                    "store": "games",
                    "name": "Games Adaptive Theme",
                    "key": "options.adaptiveTheme"
                }
            ]
        },
        {
            "section": "Terminal",
            "icon": "code",
            "items": [
                {
                    "icon": "pets",
                    "name": "Pokemon in terminal",
                    "store": "env",
                    "hint": "Needs pokemon-colorscripts",
                    "key": "USE_POKEMON"
                },
                {
                    "icon": "blur_on",
                    "name": "Terminal Opacity",
                    "store": "env",
                    "type": "text",
                    "key": "TERMINAL_OPACITY",
                    "hint": "refresh opacity by fish command"
                }
            ]
        },
        {
            "section": "System",
            "icon": "settings",
            "shell": "Global",
            "items": [
                {
                    "icon": "hearing",
                    "name": "System Sounds",
                    "hint": "Play audio feedback on actions",
                    "key": "desktop.behavior.sounds.enabled"
                },
                {
                    "icon": "mouse",
                    "name": "Faster Scrolling",
                    "hint": "Increase touchpad scroll speed",
                    "key": "interactions.scrolling.fasterTouchpadScroll"
                },
                {
                    "icon": "mouse",
                    "name": "Mouse Oriented",
                    "hint": "Optimize UI for mouse usage",
                    "key": "interactions.mouseOriented"
                },
                {
                    "icon": "globe",
                    "name": "Search Engine",
                    "type": "combobox",
                    "values": ["google", "duckduckgo", "yandex", "brave", "startpage"],
                    "key": "networking.searchEngine"
                },
                {
                    "icon": "location_on",
                    "name": "Location",
                    "hint": "Default location for weather services",
                    "key": "services.weather.location",
                    "type": "text"
                },
                {
                    "icon": "cloud_download",
                    "name": "System Dependencies",
                    "hint": "Manage Required Dependencies",
                    "type": "action",
                    "actionIcon": "download",
                    "releaseAction": () => {
                        Ipc.call(["sidebar", "reveal", "Packages"]);
                    }
                },
                {
                    "icon": "restart_alt",
                    "name": "Reset Default Settings",
                    "hint": "Resets All Shell Tweaks to its initial state",
                    "type": "action",
                    "actionIcon": "restart_alt",
                    "releaseAction": () => {
                        NoonUtils.trash(Mem.optionsView.path)
                        NoonUtils.inlineTimer(() => {
                            NoonUtils.execDetached(Paths.scriptsDir + "/reload_shell.sh")
                        }, 500);
                    }
                }
            ]
        },
        {
            "section": "Default Applications",
            "icon": "apps",
            "shell": "Global",
            "items": [
                {
                    "icon": "folder_open",
                    "store": "hypr",
                    "name": "File Manager",
                    "key": "file_manager",
                    "type": "text"
                },
                {
                    "icon": "language",
                    "store": "hypr",
                    "name": "Browser",
                    "key": "browser",
                    "type": "text"
                },
                {
                    "icon": "web",
                    "store": "hypr",
                    "name": "Browser Alt",
                    "key": "browser_alt",
                    "type": "text"
                },
                {
                    "icon": "terminal",
                    "store": "hypr",
                    "name": "Terminal",
                    "key": "terminal",
                    "type": "text"
                },
                {
                    "icon": "code",
                    "store": "hypr",
                    "name": "Terminal Alt",
                    "key": "terminal_alt",
                    "type": "text"
                },
                {
                    "icon": "edit_note",
                    "store": "hypr",
                    "name": "Editor",
                    "key": "editor",
                    "type": "text"
                }
            ]
        }
    ]

    function expandBarKey(key) {
        return (BarData.isVertical ? "bar.vertical" : "bar.horizontal") + "." + key;
    }
}
