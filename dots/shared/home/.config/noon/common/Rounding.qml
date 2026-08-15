pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common

Singleton {
    property real scale: Mem.options.appearance.rounding.scale
    property int verytiny: 2 * scale
    property int tiny: 6 * scale
    property int verysmall: 8 * scale
    property int small: 10 * scale
    property int normal: 14 * scale
    property int large: 18 * scale
    property int verylarge: 22 * scale
    property int huge: 24 * scale
    property int veryhuge: 26 * scale
    property int massive: 30 * scale
    property int silly: 34 * scale
    property int full: 999 * scale

    onScaleChanged: {
        if (Mem.options.appearance.rounding.syncCompositor)
            Mem.hypr.rounding = verylarge;
    }
}
