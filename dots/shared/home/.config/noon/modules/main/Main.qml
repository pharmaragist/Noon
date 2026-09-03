import QtQuick
import qs.services
import qs.store
import qs.common
import qs.common.utils

import "bar"
import "beam"
import "dock"
import "lock"
import "notificationPopup"
import "osd"
import "sidebar"
import "desktop"
import "clipboard"

Scope {
    NIPC {}
    Desktop {}
    // Beats {}

    WidgetLoader {
        enabled: !(Globals?.topLevel?.fullscreen ?? false) && Notifications.popupAppNameList.length > 0 && Globals.main.canNotify
        NotificationPopup {}
    }

    WidgetLoader {
        reloadOn: BarData.currentModeInfo.position
        Sidebar {}
    }

    WidgetLoader {
        enabled: Mem.options.dock.enabled
        Dock {}
    }

    WidgetLoader {
        enabled: Globals.main.locked
        Lock {}
    }

    WidgetLoader {
        reloadOn: BarData.currentModeInfo.position
        Bar {}
    }

    WidgetLoader {
        enabled: Mem.options.osd.enabled
        OSDs {}
    }

    WidgetLoader {
        reloadOn: Mem.options.beam.behavior.topMode
        Beam {}
    }

    WidgetLoader {
        enabled: Globals.main.clipboard.mode.length > 0
        ClipboardPanel {}
    }
}
