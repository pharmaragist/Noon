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
    readonly property var shaderOpts: Mem.options.desktop.bg
    readonly property var availableShaders: WallpaperService.availableShaders
    readonly property string shaderName: {
        const selected = root.shaderOpts.shaderName;
        if (root.availableShaders.includes(selected))
            return selected;
        return root.availableShaders.length > 0 ? root.availableShaders[0] : "";
    }
    readonly property string shaderPath: WallpaperService.shaderPathFor(root.shaderName)
    readonly property string shader: root.shaderPath.length > 0 ? Qt.resolvedUrl(root.shaderPath) : ""
    readonly property bool enableShaders: root.shaderOpts.enableShaderWallpaper
    readonly property bool shaderActive: root.enableShaders && root.shaderPath.length > 0
        && Paths.methods.exists(root.shaderPath)
    readonly property real shaderQuality: Math.max(0.1, Math.min(1, root.shaderOpts.shaderQuality))
    readonly property int shaderFramerate: Math.max(1, root.shaderOpts.shaderFramerate)
    readonly property color shaderColorA: shaderColor(root.shaderOpts.shaderColorA)
    readonly property color shaderColorB: shaderColor(root.shaderOpts.shaderColorB)
    readonly property color shaderColorC: shaderColor(root.shaderOpts.shaderColorC)
    readonly property bool enableDepthMode: Mem.options.desktop.bg.depthMode
    readonly property bool enableParallax: Mem.options.desktop.bg.parallax.enabled
    readonly property bool parallaxAllWorkspaces: Mem.options.desktop.bg.parallax.allWorkspaces
    readonly property bool parallaxMouseEnabled: Mem.options.desktop.bg.parallax.mouseEnabled
    readonly property real effectiveParallaxLevel: Mem.options.desktop.bg.parallax.parallaxLevel / 50
    readonly property real mouseSens: 2
    readonly property real focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property real wallpaperScale: effectiveParallaxLevel + 1
    readonly property real effectiveWallpaperScale: (enableParallax || parallaxMouseEnabled) ? wallpaperScale : 1.0
    readonly property real effectiveMovableXSpace: (effectiveWallpaperScale - 1) * 0.5 * screen.width
    readonly property real effectiveMovableYSpace: (effectiveWallpaperScale - 1) * 0.5 * screen.height
    readonly property real mouseFactorX: (parallaxMouseEnabled && mouseTracker.containsMouse && mouseTracker.width > 0) ? Math.max(0, Math.min(1, mouseTracker.mouseX / mouseTracker.width)) : 0.5
    readonly property real mouseFactorY: (parallaxMouseEnabled && mouseTracker.containsMouse && mouseTracker.height > 0) ? Math.max(0, Math.min(1, mouseTracker.mouseY / mouseTracker.height)) : 0.5
    readonly property real wsShare: enableParallax ? (parallaxMouseEnabled ? 0.5 : 1.0) : 0.0
    readonly property real mouseShare: parallaxMouseEnabled ? (enableParallax ? 0.5 : 1.0) : 0.0
    function panOffset(factor, movable, share) {
        if (share <= 0) return 0;
        return -2 * movable * share * factor;
    }
    function shaderColor(token) {
        return Colors.methods.applyAlpha(Colors.byName(token), 1);
    }
    function mouseOffset(factor, movable, share) {
        if (share <= 0) return 0;
        const raw = (factor - 0.5) * 2 * movable * share * effectiveParallaxLevel * mouseSens;
        return Math.max(-movable, Math.min(movable, raw));
    }
    readonly property real parallaxFactor: {
        if (root.parallaxAllWorkspaces) {
            const firstId = 1;
            const lastId = Mem.options.bar.workspaces.number;
            const range = lastId - firstId;
            return range > 0 ? Math.max(0, Math.min(1, (focusedWorkspaceId - firstId) / range)) : 0.5;
        }
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
        const sidebar = Globals.main?.sidebar;
        const hovered = !sidebar?.isHovered && !sidebar?.reveal;
        if (!enableParallax || hovered) return 0;
        const directionOffset = BarData.position === "left" ? -1 : 1;
        return directionOffset * root.effectiveParallaxLevel * (sidebar.sidebarWidth ?? 0);
    }
    readonly property real bgParallaxX: {
        const mouseDelta = mouseOffset(mouseFactorX, effectiveMovableXSpace, mouseShare);
        if (Mem.hypr.vertical) {
            return calculateWidgetMargin() + mouseDelta;
        }
        const wsDelta = panOffset(parallaxFactor, effectiveMovableXSpace, wsShare);
        return wsDelta + mouseDelta;
    }
    readonly property real bgParallaxY: {
        const mouseDelta = mouseOffset(mouseFactorY, effectiveMovableYSpace, mouseShare);
        if (Mem.hypr.vertical) {
            const wsDelta = panOffset(parallaxFactor, effectiveMovableYSpace, wsShare);
            return wsDelta + mouseDelta;
        }
        return mouseDelta;
    }
    readonly property int currentBarSize: BarData?.currentBarExclusiveSize ?? 0
    readonly property string currentBarPos: BarData?.position ?? ""
    Component.onCompleted: bgLayer.load(wallpaper)
    onWallpaperChanged: bgLayer.load(wallpaper)
    anchors.fill: parent
    MouseArea {
        id: mouseTracker
        anchors.fill: parent
        hoverEnabled: root.parallaxMouseEnabled
        acceptedButtons: Qt.NoButton
        z: -1
    }
    DesktopWidgets {
        z: 9999
        anchors.fill: parent
    }
    StyledLoader {
        fade: true
        shown: !root.shaderActive && NameFilters.video.some(format => wallpaper.endsWith(format.substring(1)))
        anchors.fill: parent
        sourceComponent: VidLayer {}
    }
    BgLayer {
        id: bgLayer
        z: 1
        anchors.fill: parent
        enableParallax: root.enableParallax || root.parallaxMouseEnabled
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
    StyledLoader {
        id: shaderLoader
        z: 1
        anchors.fill: parent
        fade: true
        shown: root.shaderActive
        sourceComponent: ShaderEffect {
            anchors.fill: parent
            property real time: 0
            property vector2d resolution: Qt.vector2d(
                root.shaderQuality < 1 ? Math.max(1, Math.round(width * root.shaderQuality)) : width,
                root.shaderQuality < 1 ? Math.max(1, Math.round(height * root.shaderQuality)) : height)
            property real speed: root.shaderOpts.shaderSpeed
            property color colorA: root.shaderColorA
            property color colorB: root.shaderColorB
            property color colorC: root.shaderColorC
            layer.enabled: root.shaderQuality < 1
            layer.smooth: true
            layer.textureSize: Qt.size(resolution.x, resolution.y)
            blending: true
            fragmentShader: root.shader

            Timer {
                interval: Math.max(1, Math.round(1000 / root.shaderFramerate))
                running: root.shaderOpts.shaderSpeed > 0
                repeat: true
                onTriggered: time += 1.0 / root.shaderFramerate
            }
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
        active: WallpaperService.fgReady && root.enableDepthMode && root.enableShaders
        sourceComponent: FgLayer {}
    }
}
