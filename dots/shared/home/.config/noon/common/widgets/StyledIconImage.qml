import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs.common
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    id: root

    property real tint: 0.6
    property bool colorize: Mem.options.appearance.icons.tint
    property color tintColor: Colors.m3.m3surfaceTint
    property int implicitSize: 24
    property string _source: ""

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    roundToIconSize: false
    animated: true
    source: NoonUtils.iconPath(_source.toLowerCase()) ?? ""

    Loader {
        opacity: 1 - root.tint
        active: colorize
        anchors.fill: root
        asynchronous: true

        sourceComponent: Item {
            ColorOverlay {
                z: 1
                anchors.fill: parent
                source: root
                color: root.tintColor
            }
        }
    }
}
