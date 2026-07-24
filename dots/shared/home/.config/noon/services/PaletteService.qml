pragma Singleton
import QtQuick
import qs.common
import qs.common.utils

Singleton {
    readonly property var colors: Mem.colors
    readonly property string current: Mem.options.appearance.colors.palettePath

    onCurrentChanged: if (current !== "auto")
        WallpaperService.loadJson(current);
    else
        WallpaperService.applyWallpaper(WallpaperService.currentWallpaper)

}
