import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.common

Scope {
    id: root

    enum ActionEnum {
        Unlock,
        Poweroff,
        Reboot
    }

    
    
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property var targetAction: LockContext.ActionEnum.Unlock

    signal shouldReFocus
    signal unlocked(var targetAction)
    signal failed

    function resetTargetAction() {
        root.targetAction = LockContext.ActionEnum.Unlock;
    }

    function clearText() {
        root.currentText = "";
    }

    function resetClearTimer() {
        passwordClearTimer.restart();
    }

    function reset() {
        root.resetTargetAction();
        root.clearText();
        root.unlockInProgress = false;
    }

    function tryUnlock() {
        root.unlockInProgress = true;
        pam.start();
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            showFailure = false;
        }
        passwordClearTimer.restart();
    }

    Timer {
        id: passwordClearTimer

        interval: 10000
        onTriggered: {
            root.reset();
        }
    }

    PamContext {
        id: pam

        
        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText);
        }
        
        onCompleted: result => {
            if (result == PamResult.Success) {
                root.unlocked(root.targetAction);
            } else {
                root.clearText();
                root.unlockInProgress = false;
                root.showFailure = true;
            }
        }
    }
}
