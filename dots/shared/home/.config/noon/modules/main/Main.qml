import QtQuick
import qs.services
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
// import qs.modules.applications.beats

Scope {
    NIPC {}
    Desktop {}
    // Beats {}

    WidgetLoader {
        enabled: Notifications.popupAppNameList.length > 0
        NotificationPopup {}
    }

    WidgetLoader {
        reloadOn: Mem.options.bar.behavior.position
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
        reloadOn: Mem.options.bar.behavior.position
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
