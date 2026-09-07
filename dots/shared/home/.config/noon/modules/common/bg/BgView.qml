import QtQuick
import Quickshell.Hyprland

import qs.data
import qs.services
import qs.common
import qs.common.utils
import qs.common.widgets

import qs.modules.main.desktop.widgets

Item {
    id: root

    readonly property string wallpaper: WallpaperService.currentWallpaper
    readonly property bool enableDepthMode: Mem.options.desktop.bg.depthMode
    readonly property bool enableParallax: Mem.options.desktop.bg.parallax.enabled

    readonly property real focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property real wallpaperScale: Mem.options.desktop.bg.parallax.parallaxStrength + 1
    readonly property real effectiveWallpaperScale: enableParallax ? wallpaperScale : 1.0
    readonly property real effectiveMovableXSpace: (effectiveWallpaperScale - 1) * 0.5 * screen.width
    readonly property real effectiveMovableYSpace: (effectiveWallpaperScale - 1) * 0.5 * screen.height

    readonly property real parallaxFactor: {
        const values = Hyprland.workspaces.values;
        let minId = Infinity;
        let maxId = -Infinity;

        for (let i = 0; i < values.length; ++i) {
            const id = values[i].id;
            if (id >= 0) {
                if (id < minId)
                    minId = id;
                if (id > maxId)
                    maxId = id;
            }
        }

        const firstId = minId === Infinity ? 1 : minId;
        const lastId = maxId === -Infinity ? Mem.options.bar.workspaces.number : maxId;
        const range = lastId - firstId;

        return range > 0 ? Math.max(0, Math.min(1, (focusedWorkspaceId - firstId) / range)) : 0.5;
    }

    function calculateWidgetMargin() {
        if (!enableParallax)
            return 0;
        const directionOffset = BarData.position === "left" ? -1 : 1;
        return directionOffset * Mem.options.desktop.bg.parallax.parallaxStrength * (Globals.main?.sidebar?.sidebarWidth ?? 0);
    }

    readonly property real bgParallaxX: Mem.hypr.vertical ? calculateWidgetMargin() : -effectiveMovableXSpace - (parallaxFactor - 0.5) * 2 * effectiveMovableXSpace
    readonly property real bgParallaxY: Mem.hypr.vertical ? -effectiveMovableYSpace - (parallaxFactor - 0.5) * 2 * effectiveMovableYSpace : 0

    readonly property int currentBarSize: BarData?.currentBarExclusiveSize ?? 0
    readonly property string currentBarPos: BarData?.position ?? ""

    Component.onCompleted: bgLayer.load(wallpaper)
    onWallpaperChanged: bgLayer.load(wallpaper)

    anchors.fill: parent

    DesktopWidgets {
        z: 9999
        anchors.fill: parent
    }

    StyledLoader {
        fade: true
        shown: NameFilters.video.some(format => wallpaper.endsWith(format.substring(1)))
        anchors.fill: parent
        sourceComponent: VidLayer {}
    }

    BgLayer {
        id: bgLayer
        z: 1
        anchors.fill: parent
        enableParallax: root.enableParallax
        effectiveWallpaperScale: root.effectiveWallpaperScale
        effectiveMovableXSpace: root.effectiveMovableXSpace
        effectiveMovableYSpace: root.effectiveMovableYSpace
        bgParallaxX: root.bgParallaxX
        bgParallaxY: root.bgParallaxY
        Behavior on bgParallaxX {
            SAnim {}
        }
        Behavior on bgParallaxY {
            SAnim {}
        }
    }

    Loader {
        id: layerClock
        z: 1
        active: fgLoader.item && fgLoader.item.status === Image.Ready && root.enableDepthMode
        sourceComponent: LayerClock {}
        asynchronous: true
    }

    StyledLoader {
        id: fgLoader
        z: 2
        anchors.fill: parent
        visible: active
        fade: true
        asynchronous: true
        active: WallpaperService.fgReady && root.enableDepthMode
        sourceComponent: FgLayer {}
    }
}
