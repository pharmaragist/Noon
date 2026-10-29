pragma Singleton
import QtQuick
import qs.common.utils

Singleton {
    readonly property real scale: presets[(Mem.options.appearance.rounding.preset ?? "normal")]
    readonly property int verytiny: 2 * scale
    readonly property int tiny: 6 * scale
    readonly property int verysmall: 8 * scale
    readonly property int small: 10 * scale
    readonly property int normal: 14 * scale
    readonly property int large: 18 * scale
    readonly property int verylarge: 22 * scale
    readonly property int huge: 24 * scale
    readonly property int veryhuge: 26 * scale
    readonly property int massive: 30 * scale
    readonly property int silly: 34 * scale
    readonly property int full: 999

    readonly property var presets: {
        "tiny": 0.25,
        "small": 0.5,
        "normal": 1.0,
        "large": 1.5,
        "veryLarge": 1.75
    }
}
