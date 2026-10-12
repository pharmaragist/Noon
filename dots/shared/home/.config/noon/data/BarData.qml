pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.functions

Singleton {
    id: root

    readonly property var settings: Mem.options.bar
    readonly property var states: Mem.states.bar
    readonly property bool isVertical: states.currentLayout === "vertical"
    readonly property var bars: barsModel.getArray("fileBaseName")
    readonly property var currentInfo: settings[states.currentLayout]
    readonly property var currentState: states[states.currentLayout]

    readonly property var verticalBarModes: bars.filter(i => i.toLowerCase().startsWith('v'))
    readonly property var horizontalBarModes: bars.filter(i => !i.toLowerCase().startsWith('v'))

    readonly property string position: currentState.position
    readonly property list<string> appearanceModes: ["float", "sharp", "concave", "convex"]
    readonly property list<string> positions: ["left", "right", "bottom", "top"]
    readonly property list<string> layoutProps: ["fillHeight", "fillWidth", "preferredWidth", "preferredHeight", "topMargin", "bottomMargin", "leftMargin", "rightMargin", "margins", "implicitWidth", "implicitHeight", "width", "height", "minimumWidth", "minimumHeight", "maximumWidth", "maximumHeight"]
    readonly property int currentBarExclusiveSize: currentInfo.appearance.size
    readonly property list<string> separatorStyles: ["off", "dot", "slant", "thin", "thick", "dots", "thins", "thicks"]

    readonly property var contentTable: {
        "stats": "Stats",
        "spacer": "Spacer",
        "power": "PowerIcon",
        "workspaces": "VWorkspaces",
        "unicodeWs": "UnicodeWs",
        "progressWs": "ProgressWs",
        "systemStatusIcons": "SystemStatusIcons",
        "materialStatusIcons": "StatusIcons",
        "inlineTray": "SysTray",
        "utilButtons": "UtilButtons",
        "taskbar": "TaskBar",
        "title": "VTitle",
        "resources": "Resources",
        "circBattery": "MinimalBattery",
        "weather": "WeatherIndicator",
        "media": "VMedia",
        "detailedMedia": "DetailedMedia",
        "visualizer": "VisualizerPill",
        "clock": "VClockWidget",
        "keyboard": "KeyboardLayout",
        "logo": "Logo",
        "battery": "VBatteryIndicator",
        "separator": "VSeparator",
        "space": "Spacer",
        "volume": "VolumeIndicator",
        "tray": "Tray",
        "brightness": "BrightnessIndicator"
    }

    readonly property var horizontalSubstitutions: {
        "workspaces": "Workspaces",
        "title": "ActiveWindow",
        "media": "Media",
        "battery": "BatteryIndicator",
        "clock": "ClockWidget",
        "separator": "HSeparator"
    }

    function loadPreset(id, orientation = states.currentLayout) {
        const info = settings[orientation];
        const preset = info?.presets?.find(p => p.name === id);
        if (!preset)
            return;
        ObjectUtils.applyToQtObject(info?.map, preset);
    }

    function savePreset(id) {
        const info = currentInfo;
        const preset = ObjectUtils.toPlainObject(info.map);
        const _preset = Object.assign({}, preset, {
            "name": id
        });
        const exists = info.presets.findIndex(p => p.name.toLowerCase() === id.trim())
        if (!exists)
            info.presets.push(_preset)
    }

    /*
        Switches Between Vertical - Horizontal Layouts
    */
    function toggleLayout() {
        if (states.currentLayout === "horizontal")
            states.currentLayout = "vertical";
        else
            states.currentLayout = "horizontal";
    }
    /*
        Switch Positions in Same Layout
    */

    function swapPosition() {
        const pairs = {
            "horizontal": ["top", "bottom"],
            "vertical": ["left", "right"]
        };
        const pairArr = pairs[states.currentLayout];
        const other = pairArr.find(pos => pos !== root.position);
        if (other)
            root.currentState.position = other;
    }

    FolderListModel {
        id: barsModel
        nameFilters: ["*.qml"]
        folder: Qt.resolvedUrl(Paths.shellDir + "/modules/main/bar/layouts")
        showDirs: false
        showFiles: true
    }
}
