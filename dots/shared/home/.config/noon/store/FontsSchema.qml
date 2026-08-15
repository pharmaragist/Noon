import qs.common.utils

JsonAdapter {
    property JO sizes: JO {
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
    property JO family: JO {
        property string main: "Google Sans Flex"
        property string title: "Google Sans Flex"
        property string monospace: "Iosevka"
        property string variable: "Google Sans Flex"
        property string emoji: "Noto Color Emoji"
        property string iconMaterial: "Material Symbols Rounded"
        property list<string> preferredLayerClockFonts: ["Badeen Display", "Ndot 55", "Six Caps", "Alfa Slab One", "Notable", "Monoton", "Titan One", "Bebas Neue", "Rubik", "UnifrakturCook"]
    }
    property var presets: ({
            "main": {
                "family": family.variable,
                "variableAxes": {
                    "rond": 100,
                    "wght": 450,
                    "wdth": 70,
                    "opsz": 100,
                    "grad": 100
                }
            },
            "banner": {
                "family": family.variable,
                "variableAxes": {
                    "rond": 50,
                    "opsz": 95,
                    "wdth": 110,
                    "wght": 900
                }
            },
            "title": {
                "family": family.variable,
                "variableAxes": {
                    "rond": 50,
                    "wght": 500,
                    "wdth": 67,
                    "opsz": 144,
                    "grad": 150
                }
            },
            "reading": {
                "family": family.variable,
                "variableAxes": {
                    "wght": 450,
                    "wdth": 77,
                    "opsz": 70,
                    "grad": 74
                }
            },
            "mono": {
                "family": family.monospace,
                "weight": 550
            },
            "spacedMono": {
                "letterSpacing": 1.5,
                "weight": 900,
                "family": family.monospace
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
                "family": family.iconMaterial
            }
        })
}
