import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.common
import qs.common.utils
import "startMenu"
import "controlPanel"
import "bar"
import "run"
























Scope {
    WidgetLoader {
        Bar {}
    }
    WidgetLoader {
        StartMenu {}
    }
    WidgetLoader {
        Run {}
    }
    XIPC {}
}
