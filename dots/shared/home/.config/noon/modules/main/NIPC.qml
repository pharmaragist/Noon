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
    NpcHandler {
        target: "noon"

        //* toggle_expose — show/hide the expose window overview.
        function toggle_expose() {
            Globals.main.exposeView = !Globals.main.exposeView;
        }

        //* reveal_beam <mode> — open beam in mode, or dismiss if same.
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

        //* Toggle the beam launcher overlay (resets reason to default).
        function toggle_beam() {
            const opts = Globals.main.beam;
            opts.show = !opts.show;
            Qt.callLater(() => {
                if (opts.reason !== "default")
                    opts.reason = "default";
            });
        }

        //* Toggle clipboard history mode in the clipboard panel.
        function toggle_history() {
            Globals.main.clipboard.mode === "history" ? Globals.main.clipboard.mode = "" : Globals.main.clipboard.mode = "history";
        }

        //* Toggle emoji picker mode in the clipboard panel.
        function toggle_emoji() {
            Globals.main.clipboard.mode === "emoji" ? Globals.main.clipboard.mode = "" : Globals.main.clipboard.mode = "emoji";
        }

        //* Send query to beam translator and open beam.
        function translate(query: string): string {
            BeamData.query = "< " + query;
            toggle_beam();
        }

        //* Flip bar layout between Sleek and Dynamic variants.
        function toggle_zen() {
            const prefix = BarData.isVertical ? "V" : "";
            const set = n => BarData.currentInfo.layout = prefix + n.trim();
            BarData.currentInfo.layout.includes("Sleek") ? set("Dynamic") : set("Sleek");
        }

        //* Cycle to the next bar layout preset.
        function toggle_bar_mode() {
            BarData.toggleLayout();
        }
        //* Swap bar between top/bottom (or left/right when vertical).
        function swap_bar_position() {
            BarData.swapPosition();
        }
        //* Pin/unpin the dock so it stays visible.
        function toggle_dock_pin() {
            Mem.states.dock.pinned = !Mem.states.dock.pinned;
        }
        //* Full shell restart via reload script.
        function reload() {
            NoonUtils.execDetached(["bash", Paths.scriptsDir + "/reload_shell.sh"]);
        }
    }
}
