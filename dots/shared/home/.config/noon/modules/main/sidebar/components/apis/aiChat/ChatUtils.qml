import QtQuick
import Quickshell
import qs.services
import qs.common
import qs.common.functions

/*
    All AiChat logic lives here. AiChat.qml only declares UI structure,
    the command registry, and one-line delegations.
    Wiring (set by AiChat on creation): inputField, suggestionsView,
    scrollView, commands, commandPrefix.
*/

QtObject {
    id: root

    signal expandRequested

    property var inputField
    property var suggestionsView
    property var scrollView
    property var commands: []
    property string commandPrefix: "/"
    property var suggestionList: []

    readonly property var argHandlers: ({
            "model": handleModelSuggestions,
            "effort": handleEffortSuggestions,
            "agent": handleAgentSuggestions,
            "skill": handleSkillsSuggestions,
            "session": handleSessionsSuggestions
        })

    function inputQuery() {
        return (inputField?.text ?? "").split(" ")[1] ?? "";
    }

    function inputIsFirstWord() {
        return (inputField?.text ?? "").trim().split(" ").length === 1;
    }

    function sendText(text) {
        if ((text ?? "").trim().length === 0)
            return;
        const parts = text.trim().split(" ");
        const cmd = commands.find(c => c.name === parts[0].substring(1));
        text.startsWith(commandPrefix) && cmd ? cmd.execute(parts.slice(1)) : Harness.sendUserMessage(text);
        scrollView?.positionViewAtEnd();
    }

    function updateSuggestions() {
        if (suggestionsView) {
            suggestionsView.selectedIndex = 0;
            suggestionsView.pageOffset = 0;
        }
        const trimmed = (inputField?.text ?? "").trim();
        const words = trimmed.split(" ");
        const commandWord = words[0].substring(1);
        const hasArg = words.length > 1;

        if (!trimmed.startsWith(commandPrefix)) {
            suggestionList = [];
            return;
        }

        if (hasArg) {
            const handler = argHandlers[commandWord];
            handler ? handler() : (suggestionList = []);
        } else {
            const isExact = commands.some(c => c.name === commandWord);
            isExact && argHandlers[commandWord] ? argHandlers[commandWord]() : handleCommandSuggestions(commandWord);
        }
    }

    function acceptSuggestion(word) {
        if (!inputField)
            return null;
        const words = inputField.text.trim().split(/\s+/);
        words[words.length - 1] = word;
        inputField.text = words.join(" ") + " ";
        inputField.cursorPosition = inputField.text.length;
        inputField.forceActiveFocus();
        return inputField.text;
    }

    function moveSelection(delta) {
        const view = suggestionsView;
        if (!view)
            return;
        const len = suggestionList.length;
        if (len === 0) {
            view.selectedIndex = 0;
            return;
        }
        const next = view.selectedIndex + delta;
        if (next < 0 || next >= len)
            return;
        view.selectedIndex = next;
        view.pageOffset = Math.max(0, Math.min(Math.floor(next / view.pageSize) * view.pageSize, len - view.pageSize));
    }

    function acceptSelectedWord() {
        const view = suggestionsView;
        if (view && view.selectedIndex >= 0 && view.selectedIndex < suggestionList.length)
            return acceptSuggestion(suggestionList[view.selectedIndex].name);
        return null;
    }

    function handleInputKeyPress(event) {
        const view = suggestionsView;
        switch (event.key) {
        case Qt.Key_Tab:
            acceptSelectedWord();
            event.accepted = true;
            break;
        case Qt.Key_Up:
            if (view?.visible) {
                moveSelection(-1);
                event.accepted = true;
            }
            break;
        case Qt.Key_Down:
            if (view?.visible) {
                moveSelection(1);
                event.accepted = true;
            }
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // Empty input + pending approval: Enter approves,
            // Ctrl+Enter approves all for the session.
            if ((inputField?.text ?? "").trim().length === 0 && Harness.pendingPermission) {
                if (event.modifiers & Qt.ControlModifier)
                    Harness.answerAll();
                else
                    Harness.answerPending(true);
                event.accepted = true;
                break;
            }
            if (event.modifiers & Qt.ShiftModifier) {
                inputField?.insert(inputField.cursorPosition, "\n");
            } else {
                let text = inputField?.text ?? "";
                if (view?.visible && view.selectedIndex !== -1)
                    text = acceptSelectedWord();
                inputField?.clear();
                sendText(text);
            }
            event.accepted = true;
            break;
        default:
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                if (event.modifiers & Qt.ShiftModifier) {
                    if (inputField)
                        inputField.text += Quickshell.clipboardText;
                    event.accepted = true;
                    return;
                }
                const paths = clipboardFilePaths();
                if (paths.length > 0 && inputField) {
                    inputField.insert(inputField.cursorPosition, paths.join(" "));
                    event.accepted = true;
                }
            }
        }
    }

    function handleGlobalKey(event) {
        inputField?.forceActiveFocus();
        if (event.modifiers & Qt.ControlModifier) {
            switch (event.key) {
            case Qt.Key_L:
                Harness.clearMessages();
                break;
            case Qt.Key_R:
                Harness.regenerate(Harness.messageIDs.length - 1);
                break;
            case Qt.Key_O:
                root.expandRequested();
                break;
            }
            event.accepted = true;
        }
    }

    function notifyPermissionAsked(title) {
        scrollView?.positionViewAtEnd();
        NoonUtils.toast({
            header: qsTr("AI needs approval"),
            content: title,
            icon: "key"
        });
    }

    function handleCommandSuggestions(query) {
        suggestionList = commandSuggestions(commands, query, commandPrefix);
    }

    function handleModelSuggestions() {
        const entries = Harness.modelList.map(m => ({
                    value: m,
                    description: qsTr("Set model to %1").arg(m)
                }));
        suggestionList = argSuggestions(entries, inputQuery(), commandPrefix, "model", inputIsFirstWord());
    }

    function handleEffortSuggestions() {
        const list = Harness.effortOptions.length > 0 ? Harness.effortOptions : Harness.effortList;
        const entries = list.map(m => ({
                    value: m,
                    description: qsTr("Set effort to %1").arg(m)
                }));
        suggestionList = argSuggestions(entries, inputQuery(), commandPrefix, "effort", inputIsFirstWord());
    }

    function handleSkillsSuggestions() {
        const entries = Harness.skills.map(f => ({
                    value: f,
                    description: qsTr("Load %1 skill").arg(f)
                }));
        suggestionList = argSuggestions(entries, inputQuery(), commandPrefix, "skill", inputIsFirstWord());
    }

    function handleAgentSuggestions() {
        const list = Harness.modeOptions.length > 0 ? Harness.modeOptions : Harness.modeFallback;
        const entries = list.map(m => ({
                    value: m,
                    description: qsTr("Set agent mode to %1").arg(m)
                }));
        suggestionList = argSuggestions(entries, inputQuery(), commandPrefix, "agent", inputIsFirstWord());
    }

    function handleSessionsSuggestions() {
        const entries = Harness.sessions.map(s => ({
                    value: s.id,
                    display: s.title,
                    matchText: s.title,
                    description: qsTr("Session from %1").arg(friendlySessionTime(s.updated))
                }));
        suggestionList = argSuggestions(entries, inputQuery(), commandPrefix, "session", inputIsFirstWord(), e => e.matchText);
    }

    function fuzzyEntries(entries, query, nameFn) {
        if (query.length === 0)
            return entries.slice();
        const source = entries.map(e => ({
                    name: nameFn(e),
                    prepared: Fuzzy.prepare(nameFn(e)),
                    obj: e
                }));
        return Fuzzy.go(query, source, {
            all: true,
            key: "name"
        }).map(r => r.obj?.obj ?? r.obj);
    }

    function commandSuggestions(commands, query, prefix) {
        return fuzzyEntries(commands, query, c => c.name).map(cmd => ({
                    name: prefix + cmd.name,
                    displayName: prefix + cmd.name,
                    description: cmd.description ?? ""
                }));
    }

    function argSuggestions(entries, query, prefix, cmdName, isFirst, nameFn) {
        return fuzzyEntries(entries, query, nameFn ?? (e => e.value)).map(entry => ({
                    name: (isFirst ? prefix + cmdName + " " : "") + entry.value,
                    displayName: entry.display ?? entry.value,
                    description: entry.description ?? ""
                }));
    }

    function friendlySessionTime(ts) {
        const secs = Math.max(0, Math.floor((new Date() - new Date(ts)) / 1000));
        if (secs < 60)
            return "just now";
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return mins + " min ago";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + " h ago";
        const days = Math.floor(hours / 24);
        if (days < 7)
            return days + " d ago";
        return Qt.formatDateTime(new Date(ts), "MMM d, yyyy");
    }

    // File managers copy files as a text/uri-list
    // ("file:///a\nfile:///b"). Detect that shape so plain Ctrl+V drops
    // local paths instead of raw URIs; otherwise returns [] and the field
    // keeps its default paste behavior.
    function clipboardFilePaths() {
        const lines = (Quickshell.clipboardText || "").split("\n").map(l => l.trim()).filter(l => l.length > 0);
        if (lines.length === 0 || !lines.every(l => l.startsWith("file://")))
            return [];
        return lines.map(l => {
            let p;
            try {
                p = decodeURIComponent(l.replace(/^file:\/\//, ""));
            } catch (e) {
                p = l.replace(/^file:\/\//, "");
            }
            return p.includes(" ") ? `"${p}"` : p;
        });
    }
}
