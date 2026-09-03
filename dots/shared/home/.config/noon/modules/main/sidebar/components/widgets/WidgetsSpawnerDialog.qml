import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
BottomDialog {
    id: root
    required property var db
    readonly property var store: Mem.states.sidebar.widgets

    baseHeight: 650
    enableStagedReveal: false
    bottomAreaReveal: true
    hoverHeight: 200

    contentItem: ColumnLayout {

        anchors.fill: parent
        anchors.margins: Padding.huge
        spacing: Padding.large

        PageHeader {
            title: "Your Widgets"
            subTitle: "You Have " + (root.db.length - root.store.items.filter(w => w.enabled).length) + " disabled widgets !"
        }

        StyledListView {
            clip: true
            radius: Rounding.verylarge
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            _model: root.db
            delegate: StyledDelegateItem {
                readonly property var rec: root.store.items.find(w => w.id === modelData.id)

                anchors.right: parent?.right
                anchors.left: parent?.left
                height: 70
                title: modelData?.name
                subtext: {
                    let props = [];
                    if (modelData.expandable)
                        props.push("Expandable");
                    if (rec?.pill)
                        props.push("Pill");
                    else
                        props.push("Square");
                    if (rec?.pin)
                        props.push("Pinned");
                    if (rec?.size && rec.size !== "normal")
                        props.push(rec.size.charAt(0).toUpperCase() + rec.size.slice(1));
                    return props.length > 0 ? props.join(" • ") : "Standard widget";
                }
                colSubtext: Colors.colSubtext
                colTitle: Colors.colOnLayer2
                materialIcon: modelData.icon || "widgets"
                enabled: !(rec?.enabled ?? false)
                opacity: rec?.enabled ? 0.5 : 1
                buttonRadius: Rounding.tiny
                releaseAction: () => {
                    if (enabled) {
                        let items = root.store.items.slice();
                        let w = items.find(x => x.id === modelData.id);
                        if (w) {
                            w.enabled = true;
                            root.store.items = items;
                        }
                    }
                }
            }
        }
    }
}
