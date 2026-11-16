import QtQuick
import qs.services

import qs.common
import qs.common.utils

import "widgets"
import "icons"
import "dialogs"
import "toasts"

Scope {
    id: root
    readonly property var opts: Mem.options.desktop

    ScreenCorners {}
    DialogPanel {}
    OverlayLayer {}
    WidgetLoader {
        enabled: opts.icons.enabled
        DesktopIcons {}
    }

    WidgetLoader {
        enabled: opts.toasts.enabled && Globals.common.toasts.data.length > 0
        Toasts {}
    }
}
