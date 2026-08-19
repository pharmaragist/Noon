import QtQuick
import Quickshell
import qs.store
import qs.common
import qs.common.widgets

PanelRect {
    id: bg

    readonly property string side: Mem.options.bar.behavior.position
    readonly property bool showCorners: state === "concave"
    readonly property bool isBottom: side === "bottom"
    readonly property bool isTop: side === "top" || side === ""
    readonly property bool isLeft: side === "left"
    readonly property bool isRight: side === "right"
    readonly property bool useBg: BarData.currentModeInfo.appearance.useBg
    readonly property int exclusionOverride: bg.state && bg.state === "float" ? Sizes.barElevation : 0

    color: useBg ? Colors.colBackground : "transparent"
    anchors.fill: parent
    enableBorders: false
    state: BarData.currentModeInfo.appearance?.style ?? "float"
    animationDuration: 200

    function getGapsValue(anchor) {
        if (!anchor)
            return;
        const pairs = {
            "top": "bottom",
            "left": "right",
            "bottom": "top",
            "right": "left"
        };
        const cAnc = anc => {
            return anc[0].toUpperCase() + anc.substring(1);
        };
        const opp = pairs[anchor];
        const getEval = varName => {
            return eval(`is${cAnc(varName)}`);
        };
        return getEval(anchor) ? Sizes.barElevation : getEval(opp) ? 0 : Sizes.hyprland.gapsOut;
    }

    states: [
        State {
            name: "sharp"
        },
        State {
            name: "concave"
        },
        State {
            name: "float"
            PropertyChanges {
                target: bg

                anchors.topMargin: getGapsValue("top")
                anchors.bottomMargin: getGapsValue("bottom")
                anchors.leftMargin: getGapsValue("left")
                anchors.rightMargin: getGapsValue("right")
                radius: Rounding.verylarge
                enableBorders: BarData.currentModeInfo.appearance.outline
            }
        },
        State {
            name: "convex"
            PropertyChanges {
                target: bg
                enableBorders: false
                anchors.topMargin: (isLeft || isRight) ? Sizes.hyprland.gapsOut : 0
                anchors.bottomMargin: (isLeft || isRight) ? Sizes.hyprland.gapsOut : 0
                anchors.leftMargin: (isTop || isBottom) ? Sizes.hyprland.gapsOut : 0
                anchors.rightMargin: (isTop || isBottom) ? Sizes.hyprland.gapsOut : 0

                topRadius: isBottom ? Rounding.large : 0
                bottomRadius: isTop ? Rounding.large : 0
                leftRadius: isRight ? Rounding.large : 0
                rightRadius: isLeft ? Rounding.large : 0
            }
        }
    ]
}
