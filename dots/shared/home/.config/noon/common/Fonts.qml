pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.data
import qs.common
import qs.common.utils
import qs.common.functions

Singleton {
    id: root

    readonly property QtObject methods: TextUtils
    readonly property bool ignoreVariableSpecs: true

    readonly property JO family: JO {
        property string main: "Google Sans Flex"
        property string monospace: "Iosevka"
        property string emoji: "Noto Color Emoji"
        property string iconMaterial: "Material Symbols Rounded"
        property list<string> preferredLayerClockFonts: ["Badeen Display", "Ndot 55", "Six Caps", "Alfa Slab One", "Notable", "Monoton", "Titan One", "Bebas Neue", "Rubik", "UnifrakturCook"]
    }

    readonly property JO sizes: JO {
        property real scale: 1
        property int verysmall: 12 * scale
        property int small: 14 * scale
        property int normal: 16 * scale
        property int large: 18 * scale
        property int verylarge: 20 * scale
        property int huge: 24 * scale
        property int subTitle: 32 * scale
        property int title: 46 * scale
    }
    readonly property var presets: ({
            "main": {
                "family": root.family.main,
                "variableAxes": {
                    "rond": 100,
                    "wght": 450,
                    "wdth": 70,
                    "opsz": 100,
                    "grad": 100
                }
            },
            "banner": {
                "family": root.family.main,
                "variableAxes": {
                    "rond": 50,
                    "opsz": 95,
                    "wdth": 110,
                    "wght": 900
                }
            },
            "title": {
                "family": root.family.main,
                "variableAxes": {
                    "rond": 50,
                    "wght": 500,
                    "wdth": 67,
                    "opsz": 144,
                    "grad": 150
                }
            },
            "reading": {
                "family": root.family.main,
                "variableAxes": {
                    "wght": 450,
                    "wdth": 77,
                    "opsz": 70,
                    "grad": 74
                }
            },
            "mono": {
                "family": root.family.monospace,
                "weight": 550
            },
            "spacedMono": {
                "letterSpacing": 1.5,
                "weight": 900,
                "family": root.family.monospace
            },
            "islamic": {
                "family": "Amiri Quran",
                "weight": 650
            },
            "longNumbers": {
                "family": "Google Sans Flex",
                "variableAxes": {
                    "xtra": 100,
                    "opsz": 144,
                    "wdth": 10,
                    "wght": 400
                }
            },
            "numbers": {
                "family": "Roboto Flex",
                "variableAxes": {
                    "wght": 600,
                    "ytfi": 788,
                    "opsz": 144,
                    "wdth": 50
                }
            },
            "lyrics": {
                "family": "MilligramArabicVariableTrial",
                "variableAxes": {
                    "wght": 450
                }
            },
            "materialIcons": {
                "family": root.family.iconMaterial
            }
        })

    function request(name, size, props = {}) {
        if (!name || !size)
            return;
        const _size = typeof size === "string" ? sizes[size] : size;
        const final = Object.assign({}, presets[name], {
            "pixelSize": parseInt(_size)
        }, props);
        return Qt.font(final);
    }

    function changeSystemFont(family) {
        Quickshell.execDetached([Paths.scriptsDir + "/sync_sys_fonts.sh", "--family", family, "--size", 10]);
        Mem.hypr.font_main = family;
        root.family.main = family;
    }
}
