pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils
import qs.common.functions

Singleton {
    id: root

    signal responseFinished

    readonly property bool isResponding: requester.running
    readonly property var states: Mem.ai
    readonly property string currentSessionId: states.currentSessionId
    readonly property var tokenCount: states.tokenCount
    readonly property var modelList: states.models ?? []
    readonly property string currentModelId: states.model
    readonly property string currentEffortId: states.effort ?? ""
    readonly property var skills: states.skills
    readonly property string baseCmd: Paths.scriptsDir + "/go/ai/harness"
    readonly property int maxLoadedMessages: 200
    readonly property string systemPrompt: states.systemPrompt
    readonly property var bridgeEnv: ({ "SESSION_DIR": root.states.sessionDir })
    property string liveContent: ""
    property bool liveThinking: false
    property bool liveDone: false
    property var sessions: []
    property var effortOptions: []
    property var messageIDs: []
    property var _idsBuf: []
    property bool _idsDirty: false
    property var messageQueue: []
    property var messageByID: ({})
    property string _pendingSend: ""

    Component.onCompleted: {
        root.refreshSessions();
        skillsFetcher.refresh();
        modelsFetcher.refresh();
        root.maybePreload();
    }

    // Opt-in (ai.preloadMessages): recall the persisted session on shell
    // start — one page honoring recallLimit. Runs on completion and again
    // when state arrives, since Mem.ai may load after us.
    function maybePreload() {
        if ((root.states.preloadMessages ?? false) && root.currentSessionId && root.messageIDs.length === 0 && !root.loadingMessages)
            root.loadChat(root.currentSessionId);
    }

    onStatesChanged: root.maybePreload()

    onSystemPromptChanged: if (systemPrompt) {
        setupPersonality();
    }

    function setupPersonality() {
        const m = Paths.methods;
        const targetInstPath = Paths.services.harnessPersonality;
        const targetInstPathClean = m.collapsePath(targetInstPath);
        const opencodeConfigPath = m.trim(Paths.standard.config) + "/opencode/opencode.jsonc";

        // For opencode.jsonc
        const cmd = `jq --arg p "${targetInstPathClean}" '.instructions = (if .instructions == null then [$p] elif (.instructions | index($p)) then .instructions else .instructions + [$p] end)' "${opencodeConfigPath}" > "${opencodeConfigPath}.tmp" && mv "${opencodeConfigPath}.tmp" "${opencodeConfigPath}"`;
        NoonUtils.execDetached(cmd);

        m.createFileWith(targetInstPath, systemPrompt);
    }

    function plainMessage(fields) {
        return {
            "role": fields.role ?? "",
            "content": fields.content ?? "",
            "rawContent": fields.rawContent ?? "",
            "model": fields.model ?? "",
            "thinking": fields.thinking ?? false,
            "done": fields.done ?? true,
            "queued": fields.queued ?? false,
            "tools": fields.tools ?? [],
            "annotationSources": fields.annotationSources ?? [],
            "visibleToUser": fields.visibleToUser ?? true,
            "functionPending": fields.functionPending ?? false
        };
    }

    function trimBlob(v, max) {
        if (typeof v === "string")
            return v.length > max ? v.slice(0, max) + "…" : v;
        if (v && typeof v === "object" && typeof v.content === "string" && v.content.length > max)
            return Object.assign({}, v, {
                content: v.content.slice(0, max) + "…"
            });
        return v;
    }

    function addToolPart(message, p) {
        const st = p.state || {};
        const entry = {
            tool: p.tool,
            callID: p.callID,
            status: st.status || "pending",
            input: root.trimBlob(st.input, 4000),
            output: root.trimBlob(st.output, 4000) ?? ""
        };
        const tools = message.tools || [];
        const idx = tools.findIndex(t => t.callID === p.callID);
        if (idx >= 0)
            tools[idx] = entry;
        else
            tools.push(entry);
        message.tools = tools.slice();
        root.touchMessage(message);
    }

    function acpWrite(cmd) {
        if (acpProc.running)
            acpProc.write(JSON.stringify(cmd) + "\n");
    }

    function handleSSELine(line) {
        try {
            root.handleSSE(JSON.parse(line));
        } catch (e) {
            console.warn("handleSSELine parse error:", e, "line:", line);
        }
    }

    function handleSSE(event) {
        if (event.type === "session") {
            if (event.sessionId) {
                root.states.currentSessionId = event.sessionId;
                requester._sessionBusy = false;
                // A new session while a response is flagged running means the
                // old turn died without its idle event (bridge restart, lost
                // status). Settle it so queued messages aren't stuck behind
                // requester.running forever.
                if (requester.running)
                    requester.markDone();
                if (Array.isArray(event.efforts))
                    root.effortOptions = event.efforts;
                const text = root._pendingSend;
                root._pendingSend = "";
                if (text.length > 0)
                    finishSend(text);
            }
            return;
        }
        if (event.type === "efforts") {
            if (Array.isArray(event.efforts))
                root.effortOptions = event.efforts;
            return;
        }
        if (event.type === "error") {
            console.warn("acp bridge error:", event.message);
            requester._sessionBusy = false;
            root._pendingSend = "";
            if (requester.running)
                requester.markDone();
            return;
        }
        if (event.type === "session.status") {
            var s = event.properties && event.properties.status;
            if (s) {
                requester._sessionBusy = s.type === "busy";
                if (s.type === "idle" && requester.running)
                    requester.markDone();
            }
            return;
        }
        if (!requester.running)
            return;
        if (event.type === "permission.asked") {
            var p = event.properties;
            if (p && p.tool) {
                const msgID = p.tool.messageID;
                let target = requester.message && requester.message.opencodeId === msgID ? requester.message : null;
                if (!target) {
                    for (const id of root._idsBuf) {
                        const m = root.messageByID[id];
                        if (m && m.opencodeId && m.opencodeId === msgID) {
                            target = m;
                            break;
                        }
                    }
                }
                if (!target && requester.running)
                    target = requester.message;
                if (target) {
                    target.functionPending = true;
                    target.permissionID = p.id;
                    target.permissionCallID = p.tool.callID;
                    target.permissionSessionID = p.sessionID;
                    root.touchMessage(target);
                }
            }
            return;
        }
        if (event.type === "message.updated") {
            var info = event.properties && event.properties.info;
            if (info && info.role === "user")
                requester._userMessageId = info.id;
        }
        if (event.type === "message.part.updated") {
            var part = event.properties && event.properties.part;
            if (part && part.messageID !== requester._userMessageId)
                requester.processPart(part);
        }
    }

    function idForMessage(message) {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    function scheduleIdsFlush() {
        if (!root._idsDirty) {
            root._idsDirty = true;
            NoonUtils.inlineTimer(root._flushIds, 0);
        }
    }

    function _flushIds() {
        root._idsDirty = false;
        // ScriptModel diffs assignments into incremental row ops, so no need
        // to skip no-op reassigns here (it early-returns on equal values).
        root.messageIDs = root._idsBuf.slice();
    }

    // QML `var` mutations don't notify: replacing the message object AND the
    // container identity is what makes exactly one delegate re-evaluate,
    // without touching the model array (no full ListView reset).
    function touchMessage(msg) {
        for (const id of root._idsBuf) {
            if (root.messageByID[id] === msg) {
                const next = Object.assign({}, root.messageByID);
                next[id] = Object.assign({}, msg);
                root.messageByID = next;
                // The map now holds a copy: rebind any live reference so later
                // mutations (text chunks, markDone) land on the stored object.
                if (requester.message === msg)
                    requester.message = next[id];
                return id;
            }
        }
        return "";
    }

    function pushMessage(msg) {
        const id = idForMessage(msg);
        root.messageByID[id] = msg;
        root._idsBuf.push(id);
        while (root._idsBuf.length > root.maxLoadedMessages) {
            const oldId = root._idsBuf.shift();
            delete root.messageByID[oldId];
        }
        root.scheduleIdsFlush();
        return id;
    }

    function queueMessage(id, text) {
        root.messageQueue = [...root.messageQueue,
            {
                id: id,
                text: text
            }
        ];
        if (!requester.running)
            processQueue();
    }

    function openInTerm(sessionId = root.states.currentSessionId) {
        NoonUtils.runInTerminal(`opencode -s '${sessionId}'`);
    }

    function addMessage(message, role) {
        if (message.length === 0)
            return;
        const aiMessage = root.plainMessage({
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true
        });
        root.pushMessage(aiMessage);
    }

    function removeMessage(index) {
        if (index < 0 || index >= root._idsBuf.length)
            return;
        const id = root._idsBuf[index];
        root._idsBuf.splice(index, 1);
        delete root.messageByID[id];
        root.scheduleIdsFlush();
    }

    function clearMessages() {
        root._idsBuf = [];
        root.messageByID = ({});
        root.messageIDs = [];
        root._idsDirty = false;
        root.hasMoreMessages = false;
        root.loadingMoreMessages = false;
        root.chatOffset = 0;
        root.liveContent = "";
        root.liveThinking = false;
        root.liveDone = false;
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
    }

    function newSession() {
        root.clearMessages();
        root.messageQueue = [];
        root.states.currentSessionId = "";
        refreshSessions();
    }

    function loadChat(id) {
        if (!id)
            return;
        root.clearMessages();
        root.messageQueue = [];
        root.states.currentSessionId = id.trim().toString();
        loadMessages(root.states.currentSessionId);
    }

    // Harness clamps to 1..50 server-side, so clamp here too.
    readonly property int chatBatch: Math.max(1, Math.min(50, states?.recallLimit ?? 10))
    property bool hasMoreMessages: false
    property bool loadingMoreMessages: false
    property bool loadingMessages: false
    property string _loadingSession: ""
    // Cumulative history offset. NOT _idsBuf.length: that is capped at
    // maxLoadedMessages, so past 200 loaded messages the offset would stall
    // and every page would refetch the same batch forever.
    property int chatOffset: 0

    function loadMessages(id) {
        if (root.loadingMessages && root._loadingSession === id)
            return;
        root.loadingMessages = true;
        root._loadingSession = id;
        root.runHelper("chat", [id, String(root.chatBatch), "0"], out => {
            root.loadingMessages = false;
            if (root._loadingSession !== root.currentSessionId)
                return;
            if (!Array.isArray(out))
                return;
            const batch = [];
            for (const m of out) {
                const key = root.idForMessage(m);
                root.messageByID[key] = m;
                batch.push(key);
            }
            if (batch.length)
                root._idsBuf = root._idsBuf.concat(batch);
            while (root._idsBuf.length > root.maxLoadedMessages) {
                const oldId = root._idsBuf.shift();
                delete root.messageByID[oldId];
            }
            root.chatOffset = root._idsBuf.length;
            root.hasMoreMessages = out.length >= root.chatBatch;
            root.scheduleIdsFlush();
        });
    }

    function loadMoreMessages(onDone) {
        if (root.loadingMoreMessages || root.loadingMessages || !root.hasMoreMessages || !root.currentSessionId) {
            if (onDone)
                onDone();
            return;
        }
        root.loadingMoreMessages = true;
        const sessionAtStart = root.currentSessionId;
        const offsetAtStart = root.chatOffset;
        root.runHelper("chat", [sessionAtStart, String(root.chatBatch), String(offsetAtStart)], out => {
            root.loadingMoreMessages = false;
            if (sessionAtStart !== root.currentSessionId) {
                if (onDone)
                    onDone();
                return;
            }
            if (Array.isArray(out) && out.length > 0) {
                const batch = [];
                for (const m of out) {
                    const key = root.idForMessage(m);
                    root.messageByID[key] = m;
                    batch.push(key);
                }
                root._idsBuf = batch.concat(root._idsBuf);
                while (root._idsBuf.length > root.maxLoadedMessages) {
                    // _idsBuf is oldest-first; the excess after prepending older
                    // history is the oldest, at the front. (pop() here used to
                    // drop the newest messages instead.)
                    const oldId = root._idsBuf.shift();
                    delete root.messageByID[oldId];
                }
                root.chatOffset = offsetAtStart + out.length;
                root.hasMoreMessages = out.length >= root.chatBatch;
            } else {
                root.hasMoreMessages = false;
            }
            root.scheduleIdsFlush();
            if (onDone)
                onDone();
        });
    }

    function getModel() {
        return {
            name: root.currentModelId
        };
    }

    function setSkill(skillName) {
        const trimmed = skillName.trim();
        if (root.skills.includes(trimmed))
            console.log("[AI] skill selected:", trimmed);
    }

    function setModel(modelId) {
        if (!modelId || modelId.length === 0)
            return;
        states.model = modelId;
        if (root.currentSessionId)
            root.acpWrite({
                cmd: "model",
                sessionId: root.currentSessionId,
                model: modelId,
                cwd: root.sessionCwd(root.currentSessionId)
            });
        root.addMessage("Model set to " + modelId, "interface");
    }

    readonly property var effortList: ["minimal", "low", "medium", "high", "xhigh"]

    function setEffort(effort) {
        const valid = root.effortOptions.length > 0 ? root.effortOptions : root.effortList;
        if (!effort || !valid.includes(effort))
            return;
        states.effort = effort;
        root.addMessage("Effort set to " + effort, "interface");
    }

    function respondToPermission(messageData, response) {
        if (!messageData || messageData.permissionID === undefined)
            return;
        root.acpWrite({
            cmd: "reply",
            reqId: Number(messageData.permissionID),
            approved: response !== "reject"
        });
        messageData.functionPending = false;
        delete messageData.permissionID;
        delete messageData.permissionSessionID;
        root.touchMessage(messageData);
    }
    function approveCommand(messageData) {
        root.respondToPermission(messageData, "once");
    }
    function rejectCommand(messageData) {
        root.respondToPermission(messageData, "reject");
    }

    // StandardPaths yields url strings ("file:///home/..."); the server
    // path-joins a scheme-prefixed cwd into garbage like
    // "/home/pharmaracist/file:/home/pharmaracist" and then fails EVERY
    // prompt in that session at SystemPrompt realPath. So: always trim,
    // and refuse anything that isn't a clean absolute path. This also
    // heals old poisoned sessions: resume passes our cwd, not the stored one.
    function cleanDir(dir) {
        const clean = Paths.methods.trim(String(dir ?? ""));
        if (!clean.startsWith("/") || clean.includes("file:"))
            return Paths.methods.trim(Paths.standard.home);
        return clean;
    }

    function sessionCwd(sessionId) {
        for (const s of root.sessions) {
            if (s && s.id === sessionId && s.directory)
                return root.cleanDir(s.directory);
        }
        return root.cleanDir("");
    }

    function createSessionAndSend(message) {
        requester._sessionBusy = true;
        root._pendingSend = message;
        root.acpWrite({
            cmd: "new",
            cwd: root.sessionCwd(root.currentSessionId)
        });
    }

    function sendUserMessage(message) {
        if (message.length === 0)
            return;
        if (requester._sessionBusy)
            createSessionAndSend(message);
        else if (!root.currentSessionId)
            createSessionAndSend(message);
        else
            finishSend(message);
    }

    function finishSend(message) {
        const aiMessage = root.plainMessage({
            "role": "user",
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
            "queued": true
        });
        const id = root.pushMessage(aiMessage);
        root.queueMessage(id, message);
    }

    function processQueue() {
        if (root.messageQueue.length === 0)
            return;
        const next = root.messageQueue[0];
        root.messageQueue = root.messageQueue.slice(1);
        const msg = root.messageByID[next.id];
        if (msg) {
            msg.queued = false;
            root.touchMessage(msg);
        }
        requester.makeRequest(next.text);
    }

    function finalizeResponse() {
        refreshSessions();
        root.responseFinished();
        processQueue();
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= root._idsBuf.length)
            return;
        const id = root._idsBuf[messageIndex];
        const message = root.messageByID[id];
        if (message.role !== "assistant")
            return;
        for (let i = root._idsBuf.length - 1; i >= messageIndex; i--)
            root.removeMessage(i);
        const lastUserID = root._idsBuf[root._idsBuf.length - 1];
        const lastUser = root.messageByID[lastUserID];
        if (lastUser) {
            root.messageQueue = [
                {
                    id: lastUserID,
                    text: lastUser.rawContent
                },
                ...root.messageQueue];
            if (!requester.running)
                processQueue();
        }
    }

    function stop() {
        if (!requester.running)
            return;
        requester.running = false;
        root.acpWrite({
            cmd: "cancel",
            sessionId: root.currentSessionId
        });
        if (requester.message) {
            requester.message.thinking = false;
            requester.message.done = true;
            requester.message.rawContent += "\n\n*[Stopped]*";
            requester.message.content += "\n\n*[Stopped]*";
            root.touchMessage(requester.message);
            requester.syncLive();
        }
        root.finalizeResponse();
    }

    function refreshSessions() {
        sessionsFetcher.refresh();
    }

    Process {
        id: acpProc
        running: true
        stdinEnabled: true
        command: [baseCmd, "acp"]
        stdout: SplitParser {
            onRead: data => root.handleSSELine(data)
        }
        environment: root.bridgeEnv
        onExited: {
            console.warn("acp bridge exited, restarting");
            NoonUtils.inlineTimer(() => {
                acpProc.running = true;
            }, 1000);
        }
    }

    Fetcher {
        id: sessionsFetcher
        command: [baseCmd, "sessions"]
        environment: root.bridgeEnv
        onStreamFinished: {
            if (Array.isArray(sessionsFetcher.data))
                root.sessions = sessionsFetcher.data;
        }
    }

    Fetcher {
        id: skillsFetcher
        command: [baseCmd, "skills"]
        environment: root.bridgeEnv
        onStreamFinished: {
            if (Array.isArray(skillsFetcher.data))
                states.skills = skillsFetcher.data;
        }
    }

    Fetcher {
        id: modelsFetcher
        command: [baseCmd, "models"]
        environment: root.bridgeEnv
        onStreamFinished: {
            if (!Array.isArray(modelsFetcher.data) || modelsFetcher.data.length === 0)
                return;
            states.models = modelsFetcher.data;
            if (!states.model || states.model.length === 0)
                states.model = modelsFetcher.data[0];
        }
    }

    Fetcher {
        id: chatFetcher
        autoRun: false
        property var onDone: null
        environment: root.bridgeEnv
        onStreamFinished: {
            const cb = chatFetcher.onDone;
            chatFetcher.onDone = null;
            if (cb)
                cb(chatFetcher.data);
        }
    }

    function runHelper(cmd, args, onDone) {
        chatFetcher.command = [baseCmd, cmd].concat(args);
        chatFetcher.onDone = onDone;
        chatFetcher.refresh();
    }

    QtObject {
        id: requester
        property var message: null
        property bool startedReasoning: false
        property bool running: false
        property string _userMessageId: ""
        property bool _sessionBusy: false
        property bool _liveDirty: false

        function syncLive() {
            if (!requester.message)
                return;
            root.liveContent = requester.message.content;
            root.liveThinking = requester.message.thinking;
            root.liveDone = requester.message.done;
            requester._liveDirty = false;
        }

        function markLiveDirty() {
            if (!requester._liveDirty) {
                requester._liveDirty = true;
                NoonUtils.inlineTimer(requester.syncLive, 50);
            }
        }

        function processPart(p) {
            if (!requester.message.opencodeId && p.messageID)
                requester.message.opencodeId = p.messageID;
            if (p.type === "reasoning" && p.text) {
                requester.message.thinking = false;
                if (!requester.startedReasoning) {
                    requester.message.content += "<think>";
                    requester.startedReasoning = true;
                }
                requester.message.content += p.text;
            } else if (p.type === "text" && p.text) {
                requester.message.thinking = false;
                if (requester.startedReasoning) {
                    requester.message.content += " response";
                    requester.startedReasoning = false;
                }
                requester.message.content += p.text;
                requester.message.rawContent += p.text;
            } else if (p.type === "tool") {
                requester.message.thinking = false;
                root.addToolPart(requester.message, p);
                return;
            }
            requester.markLiveDirty();
        }

        function makeRequest(userMessage) {
            requester.running = true;
            requester.startedReasoning = false;
            requester._userMessageId = "";

            requester.message = root.plainMessage({
                "role": "assistant",
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false
            });
            requester.syncLive();
            root.pushMessage(requester.message);

            root.acpWrite({
                cmd: "send",
                sessionId: root.currentSessionId || "default",
                text: userMessage,
                model: root.currentModelId,
                effort: root.currentEffortId,
                cwd: root.sessionCwd(root.currentSessionId)
            });
        }

        function markDone() {
            const msg = requester.message;
            if (!msg || msg.done)
                return;

            requester.running = false;
            msg.done = true;
            msg.thinking = false;
            if (requester.startedReasoning)
                msg.content += " response";
            requester.startedReasoning = false;
            root.touchMessage(msg);
            requester.syncLive();
            root.finalizeResponse();
        }
    }
}
