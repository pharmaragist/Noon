import QtQuick
import qs.common
import qs.common.widgets
import qs.data

RLayout {
    id: appletsArea
    z: 999

    spacing: Padding.normal

    Repeater {
        model: ScriptModel {
            values: {
                if (!Mem.options.beam.behavior.enableApplets)
                    return [];
                const all = BeamData.applets.filter(a => (a.visible ?? true));
                const enabled = Mem.options.beam.behavior.enabledApplets;
                return all.filter(applet => enabled.includes(applet.name));
            }
        }

        StyledLoader {
            required property var modelData
            required property int index
            fade: true
            source: Qt.resolvedUrl("../" + modelData.path + ".qml")
        }
    }
}
