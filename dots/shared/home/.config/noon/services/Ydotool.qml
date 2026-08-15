pragma Singleton
pragma ComponentBehavior: Bound

import qs.common
import Quickshell

Singleton {
    id: root
    property int shiftMode: 0 
    property list<int> shiftKeys: [42, 54] 
    property list<int> altKeys: [56, 100] 
    property list<int> ctrlKeys: [29, 97] 

    onShiftModeChanged: {
        if (shiftMode === 0) {}
    }

    function releaseAllKeys() {
        const keycodes = Array.from(Array(249).keys());
        const releaseCommand = `ydotool key --key-delay 0 ${keycodes.map(keycode => `${keycode}:0`).join(" ")}`;
        NoonUtils.execDetached(releaseCommand);
        root.shiftMode = 0; 
    }

    function releaseShiftKeys() {
        const releaseCommand = `ydotool key --key-delay 0 ${root.shiftKeys.map(keycode => `${keycode}:0`).join(" ")}`;
        NoonUtils.execDetached(releaseCommand);
        root.shiftMode = 0; 
    }

    function press(keycode) {
        NoonUtils.execDetached(`ydotool key --key-delay 0 ${keycode}:1`);
    }

    function release(keycode) {
        NoonUtils.execDetached(`ydotool key --key-delay 0 ${keycode}:0`);
    }
}
