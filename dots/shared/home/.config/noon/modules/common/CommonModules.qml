import QtQuick

import "bg"

import qs.common
import qs.common.utils

Scope {
    id: root

    WidgetLoader {
        enabled: Mem.options.desktop.enableFrame
        Border {}
    }

    WidgetLoader {
        Bg {}
    }
}
