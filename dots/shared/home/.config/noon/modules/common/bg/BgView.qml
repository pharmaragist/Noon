import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import qs.services
import qs.data
import qs.modules.main.desktop.widgets

Item {
    id: root

    readonly property string wallpaper: WallpaperService.currentWallpaper
    readonly property bool enableDepthMode: Mem.options.desktop.bg.depthMode
    readonly property bool enableParallax: Mem.options.desktop.bg.parallax.enabled
    readonly property var workspaceList: Hyprland.workspaces.values.filter(ws => ws.id >= 0).sort((a, b) => a.id - b.id)
    readonly property real currentWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property real wallpaperScale: Mem.options.desktop.bg.parallax.parallaxStrength + 1
    readonly property real effectiveWallpaperScale: enableParallax ? wallpaperScale : 1.0
    readonly property real effectiveMovableXSpace: (effectiveWallpaperScale - 1) / 2 * screen.width
    readonly property real effectiveMovableYSpace: (effectiveWallpaperScale - 1) / 2 * screen.height

    readonly property bool verticalParallaxMode: Mem.options.desktop.bg.parallax.verticalParallax
    readonly property real parallaxFactor: {
        const firstId = workspaceList[0]?.id || 1;
        const lastId = workspaceList[workspaceList.length - 1]?.id || Mem.options.bar.workspaces.number;
        const range = lastId - firstId;
        const offset = range > 0 ? ((currentWorkspace - firstId) / range) : 0.5;
        return Math.max(0, Math.min(1, offset));
    }

    function calculateWidgetMargin() {
        if (!Mem.options.desktop.bg.parallax.widgetParallax || !enableParallax)
            return 0;
        const directionOffset = BarData.currentInfo.position === "left" ? -1 : 1;
        return directionOffset * Mem.options.desktop.bg.parallax.parallaxStrength * Globals.main.sidebar.sidebarWidth;
    }

    readonly property real bgParallaxX: verticalParallaxMode ? calculateWidgetMargin() : -effectiveMovableXSpace - (parallaxFactor - 0.5) * 2 * effectiveMovableXSpace
    readonly property real bgParallaxY: verticalParallaxMode ? -effectiveMovableYSpace - (parallaxFactor - 0.5) * 2 * effectiveMovableYSpace : 0
    readonly property bool showOverview: Globals.main?.showBgOverview ?? false
    readonly property size controlsSize: Sizes?.beam?.appearance
    Component.onCompleted: bgLayer.load(wallpaper)
    onWallpaperChanged: bgLayer.load(wallpaper)

    anchors.fill: parent

    BlurredImage {
        z: 0
        anchors.fill: parent
        blur: true
        source: Qt.resolvedUrl(root.wallpaper)
        opacity: root.showOverview ? 1 : 0

        Rectangle {
            anchors.fill: parent
            color: Colors.m3.m3scrim
            opacity: 0.45
        }

        Behavior on opacity {
            Anim {}
        }
    }

    function getMargin(direction) {
        if (!root.showOverview)
            return 0;
        let _margin = 0;
        const base = 100;
        const bar = BarData?.currentBarExclusiveSize;
        const pos = BarData?.position;
        const controls = (controlsSize?.height ?? 100) + Padding.huge;




        if (pos === direction)
            _margin += (base + bar);
        else
            _margin += base;

        return _margin;
    }

    StyledRectangularShadow {
        z: 1
        target: clipRect
        show: root.showOverview
        transparency: 0.25
    }

    DesktopWidgets {
        z: 9999
        function mg(d) {
            let bd = d === BarData.position ? BarData.currentBarExclusiveSize + Padding.huge : Sizes.elevationMargin;
            return Math.max(root.getMargin(d), bd);
        }
        anchors {
            topMargin: mg("top")
            bottomMargin: mg("bottom")
            leftMargin: mg("left")
            rightMargin: mg("right")
        }
        Behavior on anchors.topMargin {
            Anim {}
        }
        Behavior on anchors.leftMargin {
            Anim {}
        }
        Behavior on anchors.rightMargin {
            Anim {}
        }
        Behavior on anchors.bottomMargin {
            Anim {}
        }
    }

    ClippingRectangle {
        id: clipRect
        z: 1
        anchors.fill: parent
        anchors {
            topMargin: root.getMargin("top")
            bottomMargin: root.getMargin("bottom")
            leftMargin: root.getMargin("left")
            rightMargin: root.getMargin("right")
        }
        color: "transparent"
        radius: !root.showOverview ? 0 : Rounding.silly
        border.width: root.showOverview ? 1 : 0
        border.color: Colors.colOutline
        clip: true

        Behavior on anchors.topMargin {
            Anim {}
        }
        Behavior on anchors.leftMargin {
            Anim {}
        }
        Behavior on anchors.rightMargin {
            Anim {}
        }
        Behavior on anchors.bottomMargin {
            Anim {}
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
                Anim {}
            }

            Behavior on bgParallaxY {
                Anim {}
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
}
