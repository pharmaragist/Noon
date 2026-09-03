import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.common
import qs.common.utils
import qs.common.functions
import qs.common.widgets
import qs.services
import qs.data

Scope {
    IpcHandler {
        target: "noon"

        function toggle_expose() {
            Globals.main.exposeView = !Globals.main.exposeView;
        }

        function reveal_beam(mode: string) {
            const opts = Globals.main.beam;
            if (opts.reason === mode) {
                opts.show = false;
                opts.reason = "default";
                return;
            }
            opts.show = true;
            opts.reason = mode;
        }

        function toggle_beam() {
            const opts = Globals.main.beam;
            opts.show = !opts.show;
            Qt.callLater(() => {
                if (opts.reason !== "default")
                    opts.reason = "default";
            });
        }

        function toggle_history() {
            Globals.main.clipboard.mode === "history" ? Globals.main.clipboard.mode = "" : Globals.main.clipboard.mode = "history";
        }

        function toggle_emoji() {
            Globals.main.clipboard.mode === "emoji" ? Globals.main.clipboard.mode = "" : Globals.main.clipboard.mode = "emoji";
        }

        function translate(query: string): string {
            BeamData.query = "< " + query;
            toggle_beam();
        }

        function toggle_zen() {
            const prefix = BarData.isVertical ? "V" : "";
            const set = n => BarData.currentInfo.layout = prefix + n.trim();
            BarData.currentInfo.layout.includes("Sleek") ? set("Dynamic") : set("Sleek");
        }

        function toggle_bar_mode() {
            BarData.toggleLayout();
        }
        function swap_bar_position() {
            BarData.swapPosition();
        }
        function toggle_dock_pin() {
            Mem.states.dock.pinned = !Mem.states.dock.pinned;
        }
    }
}
