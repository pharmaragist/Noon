import QtQuick
import Quickshell

Region {
    property bool enabled: true
    property Item component: null
    property Item dummy: Item {}
    item: !enabled && component ? dummy : component
}
