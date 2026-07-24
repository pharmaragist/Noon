import QtQuick
import Quickshell
import qs.common

Item {
    id: root
    enum State {
        Working,
        Error
    }
    readonly property var state: {
        if (keyColor)
            return ColorsGenerator.State.Working;
        else
            return ColorsGenerator.State.Error;
    }
    property color keyColor: "white"
    property bool active: false
    property QtObject colors: active ? template : Colors

    property QtObject template: QtObject {
        readonly property color darkerKey: Qt.darker(root.keyColor, 2)
        readonly property color slightlyDarkerKey: Qt.darker(root.keyColor, 1.2)

        property color colScrim: Colors.methods.transparentize(Colors.colScrim, darkerKey, 0.25)
        property color colSubtext: Colors.methods.colorWithLightness(colOnLayer1, 0.45)
        property color colTint: Colors.methods.transparentize(Colors.colSecondaryContainerActive, darkerKey, 0.25)

        property color colLayer0: Colors.methods.mix(Colors.colLayer0, darkerKey, 0.1)
        property color colOnLayer0: Colors.methods.mix(Colors.colOnLayer0, root.keyColor, 0.8)
        property color colLayer0Hover: Colors.methods.mix(colLayer0, colOnLayer0, 0.9)
        property color colLayer0Active: Colors.methods.mix(colLayer0, colOnLayer0, 0.8)
        property color colLayer0Border: Colors.methods.mix(Colors.m3.m3outlineVariant, colLayer0, 0.4)

        property color colLayer1: Colors.methods.mix(Colors.colLayer1, slightlyDarkerKey, 0.35)
        property color colOnLayer1: Colors.methods.mix(Colors.colOnLayer1, root.keyColor, 0.5)
        property color colOnLayer1Inactive: Colors.methods.mix(colOnLayer1, colLayer1, 0.45)
        property color colLayer1Hover: Colors.methods.mix(Colors.colLayer1Hover, root.keyColor, 0.4)
        property color colLayer1Active: Colors.methods.mix(Colors.colLayer1Active, root.keyColor, 0.5)

        property color colLayer2: Colors.methods.mix(Colors.colLayer2, root.keyColor, 0.34)
        property color colOnLayer2: Colors.methods.mix(Colors.colOnLayer2, root.keyColor, 0.45)
        property color colOnLayer2Disabled: Colors.methods.mix(colOnLayer2, Colors.m3.m3background, 0.4)
        property color colLayer2Hover: Colors.methods.mix(colLayer2, colOnLayer2, 0.9)
        property color colLayer2Active: Colors.methods.mix(colLayer2, colOnLayer2, 0.8)
        property color colLayer2Disabled: Colors.methods.mix(colLayer2, Colors.m3.m3background, 0.8)

        property color colLayer3: Colors.methods.mix(Colors.colLayer3, root.keyColor, 0.3)
        property color colOnLayer3: Colors.methods.mix(Colors.colOnLayer3, root.keyColor, 0.45)
        property color colLayer3Hover: Colors.methods.mix(colLayer3, colOnLayer3, 0.9)
        property color colLayer3Active: Colors.methods.mix(colLayer3, colOnLayer3, 0.8)

        property color colLayer4: Colors.methods.mix(Colors.colLayer4, root.keyColor, 0.25)
        property color colOnLayer4: Colors.methods.mix(Colors.colOnLayer4, root.keyColor, 0.45)
        property color colLayer4Hover: Colors.methods.mix(colLayer4, colOnLayer4, 0.9)
        property color colLayer4Active: Colors.methods.mix(colLayer4, colOnLayer4, 0.8)

        property color colPrimary: Colors.methods.mix(Colors.methods.adaptToAccent(Colors.colPrimary, root.keyColor), root.keyColor, 1)
        property color colOnPrimary: Colors.methods.mix(Colors.methods.adaptToAccent(Colors.m3.m3onPrimary, root.keyColor), root.keyColor, 0.7)
        property color colPrimaryHover: Colors.methods.mix(Colors.methods.adaptToAccent(Colors.colPrimaryHover, root.keyColor), root.keyColor, 1)
        property color colPrimaryActive: Colors.methods.mix(colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: Colors.methods.mix(Colors.colPrimaryContainer, root.keyColor, 0.3)
        property color colPrimaryContainerHover: Colors.methods.mix(colPrimaryContainer, colLayer1Hover, 0.7)
        property color colPrimaryContainerActive: Colors.methods.mix(colPrimaryContainer, colLayer1Active, 0.6)
        property color colOnPrimaryContainer: Colors.methods.mix(Colors.colOnPrimaryContainer, root.keyColor, 0.6)

        property color colSecondary: Colors.methods.mix(Colors.m3.m3secondary, root.keyColor, 0.2)
        property color colOnSecondary: Colors.methods.mix(Colors.m3.m3onSecondary, root.keyColor, 0.95)
        property color colSecondaryHover: Colors.methods.mix(Colors.m3.m3secondary, root.keyColor, 0.76)
        property color colSecondaryActive: Colors.methods.mix(colSecondary, colLayer1Active, 0.4)
        property color colSecondaryContainer: Qt.darker(colSecondary, 1.4)
        property color colSecondaryContainerHover: Colors.methods.mix(Colors.colSecondaryContainerHover, root.keyColor, 0.5)
        property color colSecondaryContainerActive: Colors.methods.mix(Colors.colSecondaryContainerActive, root.keyColor, 0.5)
        property color colOnSecondaryContainer: Colors.methods.mix(Colors.m3.m3onSurface, root.keyColor, 0.6)

        property color colOnSurface: Colors.methods.mix(Colors.colOnSurface, root.keyColor, 0.5)
        property color colOnSurfaceVariant: Colors.methods.mix(Colors.colOnSurfaceVariant, root.keyColor, 0.5)
        property color colOnSurfaceDisabled: Colors.methods.mix(colOnSurface, Colors.m3.m3background, 0.4)
        property color colOnSurfaceLowEmphasis: Colors.methods.mix(colOnSurface, colOnSurfaceVariant, 0.6)
        property color colInverseSurface: Colors.methods.mix(Colors.colInverseSurface, root.keyColor, 0.3)
        property color colInverseOnSurface: Colors.methods.mix(Colors.colInverseOnSurface, root.keyColor, 0.5)

        property color colTertiary: Colors.methods.mix(Colors.colTertiary, root.keyColor, 0.3)
        property color colTertiaryContainer: Colors.methods.mix(Colors.colTertiaryContainer, root.keyColor, 0.3)
        property color colTertiaryHover: Colors.methods.mix(colTertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: Colors.methods.mix(colTertiary, colLayer1Active, 0.4)
        property color colTertiaryContainerHover: Colors.methods.mix(colTertiaryContainer, colLayer1Hover, 0.7)
        property color colTertiaryContainerActive: Colors.methods.mix(colTertiaryContainer, colLayer1Active, 0.6)
        property color colOnTertiary: Colors.methods.mix(Colors.m3.m3onTertiary, root.keyColor, 0.6)
        property color colOnTertiaryContainer: Colors.methods.mix(Colors.m3.m3onTertiaryContainer, root.keyColor, 0.6)

        property color colSurfaceContainerLow: Colors.methods.mix(Colors.colSurfaceContainerLow, root.keyColor, 0.2)
        property color colSurfaceContainer: Colors.methods.mix(Colors.colSurfaceContainer, root.keyColor, 0.25)
        property color colSurfaceContainerHigh: Colors.methods.mix(Colors.colSurfaceContainerHigh, root.keyColor, 0.3)
        property color colSurfaceContainerHighest: Colors.methods.mix(Colors.colSurfaceContainerHighest, root.keyColor, 0.35)
        property color colSurfaceContainerHighestHover: Colors.methods.mix(colSurfaceContainerHighest, colOnSurface, 0.95)
        property color colSurfaceContainerHighestActive: Colors.methods.mix(colSurfaceContainerHighest, colOnSurface, 0.85)

        property color colError: Colors.methods.mix(Colors.colError, root.keyColor, 0.3)
        property color colOnError: Colors.methods.mix(Colors.colOnError, root.keyColor, 0.5)
        property color colErrorHover: Colors.methods.mix(colError, colLayer1Hover, 0.85)
        property color colErrorActive: Colors.methods.mix(colError, colLayer1Active, 0.7)
        property color colErrorContainer: Colors.methods.mix(Colors.colErrorContainer, root.keyColor, 0.3)
        property color colErrorContainerHover: Colors.methods.mix(colErrorContainer, Colors.m3.m3onErrorContainer, 0.9)
        property color colErrorContainerActive: Colors.methods.mix(colErrorContainer, Colors.m3.m3onErrorContainer, 0.7)
        property color colOnErrorContainer: Colors.methods.mix(Colors.colOnErrorContainer, root.keyColor, 0.6)

        property color colOutline: Colors.methods.mix(Colors.colOutline, root.keyColor, 0.3)
        property color colOutlineVariant: Colors.methods.mix(Colors.colOutlineVariant, root.keyColor, 0.3)
        property color colTooltip: Colors.methods.mix(Colors.colTooltip, root.keyColor, 0.2)
        property color colOnTooltip: Colors.colOnTooltip
        property color colShadow: Colors.methods.mix(Colors.colShadow, darkerKey, 0.3)
    }
}
