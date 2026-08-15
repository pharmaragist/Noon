import QtQuick
import qs.services

import qs.common
import qs.common.utils

import "widgets"
import "icons"
import "dialogs"
import "toasts"
import "clock"

Scope {
    id: root
    readonly property var opts: Mem.options.desktop

    DialogPanel {}

    WidgetLoader {
        enabled: !opts.bg.depthMode && !WallpaperService.fgReady && opts.clock.enabled
        DesktopClock {}
    }

    WidgetLoader {
        enabled: opts.screenCorners !== "Disabled"
        ScreenCorners {}
    }

    WidgetLoader {
        enabled: opts.icons.enabled
        DesktopIcons {}
    }

    WidgetLoader {
        enabled: opts.toasts.enabled && Globals.common.toasts.data.length > 0
        Toasts {}
    }
}
