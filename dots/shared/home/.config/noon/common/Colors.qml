pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.functions
import qs.services

Singleton {
    id: root
    function t(c, amt = transparency) {
        return methods.transparentize(c, amt * 0.7);
    }

    function calculateTransparency() {
        if (!Mem.looks.autoTransparencySelection)
            return Mem.options.appearance.transparency.scale;
        const min = 0.15;
        const max = 0.9;
        const step = 0.1;
        var current = Mem.options.appearance.transparency.scale;
        const looks = Mem.looks
        const stepCases = [ !looks.isBright , looks.mode === "dark" ]
        stepCases.forEach(c => {
            if (c)
                current += step;
        })
        return Math.min(max, Math.max(min, current));
    }

    Behavior on transparency {
        NumberAnimation {
            duration: 350
        }
    }

    readonly property QtObject methods: ColorUtils
    readonly property QtObject m3: PaletteService.colors

    property real transparency: transparent ? calculateTransparency() : 0
    readonly property bool transparent: Mem.options.appearance.transparency.enabled

    readonly property color colBackground: t(m3.m3background)
    readonly property color colOnBackground: WallpaperService.isBright ? colLayer0 : colOnLayer0
    readonly property color colSubtext: m3.m3outline

    readonly property color colLayer0: t(m3.m3background)
    readonly property color colOnLayer0: m3.m3onBackground
    readonly property color colLayer0Hover: t(m3.m3surfaceDim)
    readonly property color colLayer0Active: t(m3.m3surfaceContainerLow)
    readonly property color colLayer0Border: m3.m3outlineVariant

    readonly property color colLayer1: t(m3.m3surfaceContainerLow)
    readonly property color colOnLayer1: m3.m3onSurfaceVariant
    readonly property color colOnLayer1Inactive: colOnLayer1
    readonly property color colLayer1Hover: t(m3.m3surfaceContainer)
    readonly property color colLayer1Active: t(m3.m3surfaceContainerHigh)

    readonly property color colLayer2: t(m3.m3surfaceContainer)
    readonly property color colOnLayer2: m3.m3onSurface
    readonly property color colOnLayer2Disabled: colOnLayer2
    readonly property color colLayer2Hover: t(m3.m3surfaceContainerHigh)
    readonly property color colLayer2Active: t(m3.m3surfaceContainerHighest)
    readonly property color colLayer2Disabled: t(colLayer2, 0.5)

    readonly property color colLayer3: t(m3.m3surfaceContainerHigh)
    readonly property color colOnLayer3: m3.m3onSurface
    readonly property color colLayer3Hover: t(m3.m3surfaceContainerHighest)
    readonly property color colLayer3Active: t(m3.m3surfaceBright)

    readonly property color colLayer4: t(m3.m3surfaceContainerHighest)
    readonly property color colOnLayer4: m3.m3onSurface
    readonly property color colLayer4Hover: t(m3.m3surfaceBright)
    readonly property color colLayer4Active: t(m3.m3surfaceBright, 0.8)

    readonly property color colPrimary: m3.m3primary
    readonly property color colOnPrimary: m3.m3onPrimary
    readonly property color colPrimaryHover: m3.m3primaryFixed
    readonly property color colPrimaryActive: m3.m3primaryFixedDim

    readonly property color colPrimaryContainer: m3.m3primaryContainer
    readonly property color colOnPrimaryContainer: m3.m3onPrimaryContainer
    readonly property color colPrimaryContainerHover: m3.m3primaryFixed
    readonly property color colPrimaryContainerActive: m3.m3primaryFixedDim

    readonly property color colSecondary: m3.m3secondary
    readonly property color colOnSecondary: m3.m3onSecondary
    readonly property color colSecondaryHover: m3.m3secondaryFixed
    readonly property color colSecondaryActive: m3.m3secondaryFixedDim

    readonly property color colSecondaryContainer: t(m3.m3secondaryContainer)
    readonly property color colOnSecondaryContainer: m3.m3onSecondaryContainer
    readonly property color colSecondaryContainerHover: m3.m3secondaryFixed
    readonly property color colSecondaryContainerActive: m3.m3secondaryFixedDim

    readonly property color colTertiary: m3.m3tertiary
    readonly property color colOnTertiary: m3.m3onTertiary
    readonly property color colTertiaryHover: m3.m3tertiaryFixed
    readonly property color colTertiaryActive: m3.m3tertiaryFixedDim

    readonly property color colTertiaryContainer: t(m3.m3tertiaryContainer)
    readonly property color colOnTertiaryContainer: m3.m3onTertiaryContainer
    readonly property color colTertiaryContainerHover: m3.m3tertiaryFixed
    readonly property color colTertiaryContainerActive: m3.m3tertiaryFixedDim

    readonly property color colOnSurface: m3.m3onSurface
    readonly property color colOnSurfaceVariant: m3.m3onSurfaceVariant
    readonly property color colOnSurfaceDisabled: t(colOnSurface, 0.4)
    readonly property color colOnSurfaceLowEmphasis: t(colOnSurface, 0.6)
    readonly property color colInverseSurface: m3.m3inverseSurface
    readonly property color colInverseOnSurface: m3.m3inverseOnSurface

    readonly property color colSurfaceContainerLow: t(m3.m3surfaceContainerLow)
    readonly property color colSurfaceContainer: t(m3.m3surfaceContainer)
    readonly property color colSurfaceContainerHigh: t(m3.m3surfaceContainerHigh)
    readonly property color colSurfaceContainerHighest: t(m3.m3surfaceContainerHighest)
    readonly property color colSurfaceContainerHighestHover: t(m3.m3surfaceBright)
    readonly property color colSurfaceContainerHighestActive: t(m3.m3surfaceBright, 0.8)

    readonly property color colSuccess: m3.m3success
    readonly property color colOnSuccess: m3.m3onSuccess
    readonly property color colSuccessContainer: m3.m3successContainer
    readonly property color colOnSuccessContainer: m3.m3onSuccessContainer

    readonly property color colError: m3.m3error
    readonly property color colOnError: m3.m3onError
    readonly property color colErrorHover: t(m3.m3errorContainer)
    readonly property color colErrorActive: t(m3.m3errorContainer, 0.8)

    readonly property color colErrorContainer: m3.m3errorContainer
    readonly property color colOnErrorContainer: m3.m3onErrorContainer
    readonly property color colErrorContainerHover: m3.m3error
    readonly property color colErrorContainerActive: t(m3.m3error, 0.8)

    readonly property color colOutline: m3.m3surfaceContainerHighest
    readonly property color colOutlineVariant: m3.m3outlineVariant
    readonly property color colTooltip: m3.m3background
    readonly property color colOnTooltip: m3.m3onBackground
    readonly property color colScrim: t(m3.m3scrim, 0.4)
    readonly property color colShadow: m3.m3shadow
}
