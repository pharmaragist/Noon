import QtQuick
import Quickshell
import qs.common
import qs.common.utils
import qs.common.functions

Scope {
    id: root
    NpcHandler {
        id: ipc
        target: "nobuntu"
        //* Show/hide the dashboard (db) panel.
        function toggle_db() {
            Globals.nobuntu.db.show = !Globals.nobuntu.db.show;
        }
        //* Show/hide the activities overview.
        function toggle_overview() {
            Globals.nobuntu.overview.show = !Globals.nobuntu.overview.show;
        }
        //* Show/hide the notifications center.
        function toggle_notifs() {
            Globals.nobuntu.notifs.show = !Globals.nobuntu.notifs.show;
        }
        //* Show/hide the clipboard panel.
        function toggle_clipboard() {
            Globals.nobuntu.clipboard.show = !Globals.nobuntu.clipboard.show;
        }
    }
}
