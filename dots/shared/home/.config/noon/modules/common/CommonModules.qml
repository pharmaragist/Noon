import QtQuick

import "bg"
import "big_view"

import qs.common
import qs.common.utils

Scope {
    id: root

    WidgetLoader {
        active: Globals.common.openGameUI
        BigView {}
    }

    WidgetLoader {
        enabled: Mem.options.desktop.enableFrame
        Border {}
    }

    WidgetLoader {
        Bg {}
    }
}
