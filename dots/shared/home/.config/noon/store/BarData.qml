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

    readonly property bool isVertical: ["left", "right"].includes(position)
    readonly property var bars: barsModel.getArray("fileBaseName")
    readonly property var currentModeInfo: isVertical ? settings.vertical : settings.horizontal

    readonly property var verticalBarModes: bars.filter(i => i.toLowerCase().startsWith('v'))
    readonly property var horizontalBarModes: bars.filter(i => !i.toLowerCase().startsWith('v'))

    readonly property string position: settings.behavior.position
    readonly property list<string> appearanceModes: ["float", "sharp", "concave", "convex"]
    readonly property list<string> positions: ["left", "right", "bottom", "top"]
    readonly property list<string> layoutProps: ["fillHeight", "fillWidth", "preferredWidth", "preferredHeight", "topMargin", "bottomMargin", "leftMargin", "rightMargin", "margins", "implicitWidth", "implicitHeight", "width", "height", "minimumWidth", "minimumHeight", "maximumWidth", "maximumHeight"]
    readonly property int currentBarExclusiveSize: currentModeInfo.appearance.size
    readonly property list<string> separatorStyles: ["dot", "slant", "thin", "thick" ,"dots","thins","thicks"]


    readonly property var contentTable: {
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
        "timers": "Timers",
        "resources": "Resources",
        "circBattery": "MinimalBattery",
        "weather": "WeatherIndicator",
        "media": "VMedia",
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


    function setPosition(pos) {
        if (positions.indexOf(pos) > -1)
            settings.behavior.position = pos;
    }


    function toggleLayout() {
        const pairs = {
            "left": "top",
            "right": "bottom",
            "bottom": "right",
            "top": "left"
        };
        setPosition(pairs[position]);
    }

    function swapPosition() {
        const pairs = {
            "left": "right",
            "right": "left",
            "top": "bottom",
            "bottom": "top"
        };
        setPosition(pairs[position]);
    }

    function loadPreset(id, orientation) {
        const preset = currentModeInfo.presets[orientation].find(p => p.name === id);
        if (!preset) return;
        ObjectUtils.applyToQtObject(root.settings[orientation[0] + "Map"], preset);
    }

    function saveCurrentPreset(id) {
        const orientation = root.isVertical ? "vertical" : "horizontal";
        const objMap = orientation[0] + "Map";
        const currentSettings = root.settings[objMap];
        const currentObjectData = ObjectUtils.toPlainObject(currentSettings);
        const target = currentModeInfo.presets[orientation];
        if (!target.find(p => p.name === id))
            target.push(Object.assign({
                name: id
            }, currentObjectData));
    }


    function savePreset(id, preset, orientation) {
        const validOrientations = ["horizontal", "vertical"];
        if (!preset) {
            console.error("Given Preset Isn't Valid: ", JSON.stringify(preset));
            return;
        } else if (validOrientations.indexOf(orientation) === -1) {
            console.error("Given Orientation Isn't Valid: ", JSON.stringify(orientation));
            return;
        }
        const objMap = orientation[0] + "Map";
        const store = currentModeInfo.presets[objMap];

        const data = Object.assign({
            name: id
        }, preset);
        store.push(data);
    }

    function cyclePosition() {
        const positions = ["top", "left", "bottom", "right"];
        const currentPosition = settings.behavior.position;
        const position = (positions.indexOf(currentPosition) + 1) % 4;
        setPosition(positions[position]);
    }

    FolderListModel {
        id: barsModel
        nameFilters: ["*.qml"]
        folder: Qt.resolvedUrl(Paths.shellDir + "/modules/main/bar/layouts")
        showDirs: false
        showFiles: true
    }
}
