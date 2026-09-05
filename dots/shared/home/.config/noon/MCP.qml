import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.common
import qs.common.utils
import qs.common.functions
import qs.common.widgets
import qs.services
import qs.data





NpcHandler {
    target: "ai"


    function create_timer(duration: int, name: string, autoStart: bool) {
        TimerService.addTimer(name, duration, false, true);
    }

    function add_task(taskName: string, taskState: string, state: int, date: string) {
        TodoService.addTask(taskName, state, date);
    }
}
