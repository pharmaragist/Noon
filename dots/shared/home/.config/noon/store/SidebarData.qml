pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.utils
import qs.common.functions
import qs.services

Singleton {
    id: root

    property int sidebarWidth
    property var detachedContent: []
    property var enabledCategories: ({})
    property var registry: ({})
    readonly property QtObject sizes: Sizes.sidebar
    readonly property list<string> appearanceModes: ["float", "sharp", "convex", "concave"]
    readonly property var contentOptions: Mem.options.sidebar.content

    readonly property var shellReg: {
        "Apps": {
            icon: "rocket",
            activeIcon: "rocket_launch",
            shell: "main",
            componentPath: "apps/Apps",
            expandable: true,
            searchable: true,
            expandSize: sizes.half,
            shape: "Ghostish",
            enabled: contentOptions.apps
        },
        "ScreenTime": {
            icon: "supervisor_account",
            activeIcon: "person",
            componentPath: "etc/ScreenTime",
            enabled: contentOptions.screenTime
        },
        "API": {
            icon: "cognition",
            activeIcon: "cognition_2",
            componentPath: "apis/AiChat",
            expandable: true,
            incubatable: true,
            detachable: true,
            shape: "PixelCircle",
            enabled: contentOptions.apis
        },
        "Notifs": {
            icon: "notifications",
            activeIcon: "notifications_active",
            shell: "main",
            padding: 0,
            componentPath: "notifs/Notifs",
            expandSize: sizes.quarter,
            enabled: contentOptions.notifs
        },
        "Walls": {
            icon: "gallery_thumbnail",
            activeIcon: "image",
            componentPath: "wallpapers/WallpaperSelector",
            expandable: true,
            expandSize: sizes.threeQuarter,
            searchable: true,
            shape: "Ghostish",
            enabled: contentOptions.wallpapers
        },
        "Tasks": {
            icon: "task_alt",
            activeIcon: "add_task",
            componentPath: "tasks/Todo",
            searchable: true,
            shape: "Clover8Leaf",
            enabled: true
        },
        "Notes": {
            icon: "stylus",
            activeIcon: "stylus_note",
            componentPath: "notes/Notes",
            expandable: true,
            incubatable: true,
            detachable: true,
            shape: "Slanted",
            enabled: contentOptions.notes
        },
        "Beats": {
            icon: "music_note",
            activeIcon: "music_cast",
            shell: "main",
            componentPath: "beats/Beats",
            navRailMode: "sharp",
            expandable: true,
            incubatable: true,
            detachable: true,
            shape: "Bun",
            padding: 0,
            enabled: contentOptions.beats,
            colors: MediaPlayerService?.colors
        },
        "Games": {
            enabled: contentOptions.games,
            expandable: true,
            componentPath: "games/Games",
            icon: "joystick",
            searchable: true,
            shape: "Ghostish"
        },
        "History": {
            icon: "content_paste",
            activeIcon: "inventory",
            shell: "main",
            componentPath: "etc/History",
            searchable: true,
            shape: "Ghostish",
            enabled: contentOptions.history
        },
        "Emojis": {
            icon: "sentiment_calm",
            componentPath: "etc/Emojis",
            expandable: true,
            searchable: true,
            shape: "Ghostish",
            enabled: contentOptions.emojies
        },
        "Bookmarks": {
            icon: "bookmark",
            activeIcon: "bookmark_heart",
            componentPath: "etc/Bookmarks",
            searchable: true,
            shape: "Ghostish",
            enabled: contentOptions.bookmarks
        },
        "Shelf": {
            icon: "shelves",
            activeIcon: "book_ribbon",
            incubatable: true,
            componentPath: "shelf/Shelf",
            enabled: contentOptions.shelf
        },
        "Widgets": {
            icon: "ripples",
            expandable: true,
            lazy: false,
            expandSize: sizes.widgetsExpanded,
            componentPath: "widgets/Widgets",
            enabled: contentOptions.widgets
        },
        "Sounds": {
            icon: "graphic_eq",
            componentPath: "sounds/Sounds",
            detachable: true,
            shape: "Gem",
            enabled: contentOptions.sounds
        },
        "Timers": {
            icon: "timer",
            componentPath: "timers/Timers",
            detachable: true,
            incubatable: true,
            shape: "Cookie4Sided",
            enabled: contentOptions.timers
        },
        "Tweaks": {
            icon: "settings",
            activeIcon: "settings_heart",
            shell: "main",
            componentPath: "settings/Tweaks",
            searchable: true,
            shape: "Ghostish",
            enabled: contentOptions.tweaks
        },
        "View": {
            icon: "workspaces",
            incubatable: true,
            componentPath: "view/Overview",
            baseSize: sizes.overviewExpanded,
            stealth: !contentOptions.overview
        },
        "Session": {
            lazy: false,
            icon: "power_settings_new",
            componentPath: "etc/Session",
            baseSize: sizes.session,
            enabled: contentOptions.session
        },
        "Plugins": {
            icon: "extension",
            componentPath: "plugins/Plugins",
            shape: "PixelTriangle"
        },
        "DMenu": {
            icon: "dashboard",
            componentPath: "etc/DMenu",
            searchable: true,
            stealth: true
        },
        "Hints": {
            componentPath: "etc/HintsLoader",
            shape: "Clover8Leaf",
            stealth: true
        },
        "Bars": {
            componentPath: "etc/BarSwitcher",
            shape: "Ghostish",
            searchable: true,
            shell: "main",
            stealth: true
        },
        "TaskManager": {
            icon: "memory",
            searchable: true,
            componentPath: "etc/TaskManager",
            stealth: true
        },
        "Cast": {
            componentPath: "cast/Cast",
            stealth: true
        },
        "Auth": {
            componentPath: "etc/Polkit",
            stealth: true
        },
        "Packages": {
            componentPath: "etc/Packages",
            stealth: true
        }
    }

    function _get(id) {
        return registry[id];
    }
    function rebuildAll() {
        registry = rebuildRegistry();
        enabledCategories = getEnabledCategories();
    }
    onShellRegChanged: rebuildAll()
    Component.onCompleted: rebuildAll()

    function getEnabledCategories() {
        return Object.keys(registry).filter(key => {
            const item = registry[key];
            const isEnabled = item.enabled ?? true;
            const isNotStealth = !item.stealth;
            const matchesShell = item.shell === undefined || item.shell === Mem.options.desktop.shell.mode;

            return isEnabled && isNotStealth && matchesShell;
        });
    }

    function rebuildRegistry() {
        return Object.assign({}, shellReg, PluginsManager.sidebarPlugins);
    }

    function getPadding(id) {
        return _get(id)?.padding ?? Padding.huge;
    }
    function getColors(id) {
        return _get(id)?.colors ?? Colors;
    }
    function getCategory(id) {
        return _get(id);
    }
    function getShape(id) {
        return MaterialShape.Shape[_get(id)?.shape || ""];
    }
    function getIcon(id, active = false) {
        if (active && _get(id)?.activeIcon)
            return _get(id)?.activeIcon;
        else
            return _get(id)?.icon;
    }
    function getComponentPath(id) {
        const c = _get(id);
        if (!c)
            return "";
        return c.isPlugin ? c.entry : "components/" + c.componentPath + ".qml";
    }
    function getPreloadData(id) {
        return _get(id)?.preloadData ?? "";
    }

    function isLazy(id) {
        return _get(id)?.lazy ?? true;
    }
    function isSearchable(id) {
        return !!_get(id)?.searchable;
    }
    function isIncubatable(id) {
        return !!_get(id)?.incubatable;
    }
    function isDetachable(id) {
        return !!_get(id)?.detachable;
    }
    function isAsync(id) {
        return !!_get(id)?.async;
    }
    function isExpandable(id) {
        return !!_get(id)?.expandable;
    }
    function usePreExpand(id) {
        return !!_get(id)?.preExpand;
    }
    function isStealth(id) {
        return !!_get(id)?.stealth;
    }
    function isDetached(id) {
        return SidebarData.detachedContent.includes(id);
    }
    function currentSize(barMode, expanded, id, aux = false) {
        const content = registry[id];
        if (barMode || !content)
            return sizes.bar;
        if (aux)
            return (content?.baseSize ?? sizes.quarter) - sizes.bar;
        if (expanded && content.expandable)
            return content.expandSize ?? sizes.half;
        else
            return content?.baseSize ?? sizes.quarter;
    }

    function _navigate(id, step) {
        const v = enabledCategories;
        const i = v.indexOf(id);
        return i > 0 ? v[(i + step + v.length) % v.length] : v[0];
    }

    function getNextEnabledCategory(id) {
        return _navigate(id, 1);
    }
    function getPreviousEnabledCategory(id) {
        return _navigate(id, -1);
    }
}
