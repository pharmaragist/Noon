pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.platform
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils
import qs.common.functions
import qs.common.widgets

Singleton {
    id: root

    signal responseFinished
    signal permissionAsked(string title)

    readonly property bool isResponding: requester.running
    readonly property var states: Mem.ai
    readonly property string currentSessionId: states.currentSessionId
    readonly property var tokenCount: states.tokenCount
    readonly property var modelList: states.models ?? []
    readonly property string currentModelId: states.model
    readonly property string currentEffortId: states.effort ?? ""
    readonly property string currentAgentId: states.agent ?? "plan"
    property var skills: []
    readonly property string baseCmd: Paths.scripts.harness
    readonly property int maxLoadedMessages: 200
    readonly property var bridgeEnv: ({
            "SESSION_DIR": root.states.sessionDir,
            "XDG_CONFIG_HOME": root.sideConfigHome
        })
    readonly property string sideConfigHome: root.cleanDir(root.states.sessionDir) + "/config"
    readonly property int chatBatch: Math.max(1, Math.min(50, states?.recallLimit ?? 10))
    readonly property var effortList: ["minimal", "low", "medium", "high", "xhigh"]
    readonly property var modeFallback: ["build", "plan"]

    property string liveContent: ""
    property string liveThinkText: ""
    property bool liveThinking: false
    property bool liveDone: false
    property var sessions: []
    property var effortOptions: []
    property var modeOptions: []
    property var contextUsage: null
    property var turnCost: null
    property var pendingPermission: null
    property var pendingElicitation: null
    property bool autoApproveSession: false
    property var messageIDs: []
    property var messageQueue: []
    property var messageByID: ({})
    property string pendingSkill: ""
    property bool hasMoreMessages: false
    property bool loadingMoreMessages: false
    property bool loadingMessages: false
    property int chatOffset: 0

    property var _idsBuf: []
    property bool _idsDirty: false
    property var _pendingSend: []
    property var _pendingAnnotations: []
    property bool _waitingForScreenshot: false
    property bool _sessDirty: false
    property string _loadingSession: ""
    property int _idSeq: 0
    property int _liveCount: 0
    property int _restartCount: 0
    property var _byOcId: ({})
    property var _cwdBySession: ({})
    property var _permQueue: []
    property var _permMsgIds: []
    property var _permDialog: null
    property var _pendingAttachments: []
    property string _lastCompactionPhase: ""

    Component.onCompleted: {
        root.setupPersonality();
        root.refreshSessions();
        skillsFetcher.refresh();
        root.maybePreload();
    }

    onStatesChanged: root.maybePreload()
    onSessionsChanged: root._rebuildCwdMap()

    onPermissionAsked: text => {
        if (Globals.main.sidebar.selectedCategory === "AI")
            return;
        const p = root.pendingPermission;
        const rid = p ? p.reqId : "";
        const options = p && Array.isArray(p.options) ? p.options : [];
        if (options.length > 0) {
            root._showPermissionOptions(text, rid, options);
            return;
        }
        NoonUtils.requestDialog("assure", {
            title: "Permission Request",
            description: text,
            acceptText: "Accept",
            onAccepted: () => root.resolvePermission(rid, true),
            onCanceled: () => root.resolvePermission(rid, false)
        });
    }

    function maybePreload() {
        if ((root.states.preloadMessages ?? false) && root.currentSessionId && root.messageIDs.length === 0 && !root.loadingMessages)
            root.loadChat(root.currentSessionId);
    }

    function setupPersonality() {
        const m = Paths.methods;
        const cfg = m.trim(Paths.standard.config);
        const cmd = `rm -rf "${root.cleanDir(root.states.sessionDir)}/persona" "${root.sideConfigHome}/opencode/system.md" "${cfg}/opencode/agents/noon.md" "${cfg}/opencode/tools/noon_shell.ts"`;

        NoonUtils.execDetached(cmd);
        root.syncSystemPrompt();
        root.runToolsHelper([Paths.shellDir], text => {
            if (typeof text !== "string" || text.length === 0)
                return;
            const toolsPath = root.sideConfigHome + "/opencode/tools/noon_shell.ts";
            let cur = "";
            try {
                cur = m.readFile(toolsPath);
            } catch (e) {
                cur = "";
            }
            if (cur !== text)
                m.createFileWith(toolsPath, text);
        });
    }

    function syncSystemPrompt() {
        const m = Paths.methods;
        const globalCfg = m.trim(Paths.standard.config) + "/opencode/opencode.jsonc";
        const sideDir = root.sideConfigHome + "/opencode";
        NoonUtils.inlineStdProc([root.baseCmd, "sync-config", globalCfg, sideDir], text => {
            if (text !== "ok")
                root.addMessage("Error: sidebar config sync failed (" + text + ")", "interface");
        });
    }

    function _newId() {
        root._idSeq += 1;
        return "m" + root._idSeq.toString(36);
    }

    function idForMessage(message) {
        return root._newId();
    }

    function plainMessage(fields) {
        return {
            "role": fields.role ?? "",
            "content": fields.content ?? "",
            "thinkText": fields.thinkText ?? "",
            "rawContent": fields.rawContent ?? "",
            "model": fields.model ?? "",
            "thinking": fields.thinking ?? false,
            "done": fields.done ?? true,
            "queued": fields.queued ?? false,
            "tools": fields.tools ?? [],
            "annotationSources": fields.annotationSources ?? [],
            "attachments": fields.attachments ?? [],
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

    function scheduleIdsFlush() {
        if (!root._idsDirty) {
            root._idsDirty = true;
            NoonUtils.inlineTimer(root._flushIds, 0);
        }
    }

    function _flushIds() {
        root._idsDirty = false;
        root.messageIDs = root._idsBuf.slice();
    }

    function _commit(id, next) {
        const map = Object.assign({}, root.messageByID);
        map[id] = next;
        root.messageByID = map;
        if (requester.messageId === id)
            requester.message = next;
    }

    function updateMessage(id, mutate) {
        const cur = root.messageByID[id];
        if (!cur)
            return null;
        const next = Object.assign({}, cur);
        mutate(next);
        root._commit(id, next);
        return next;
    }

    function touchMessage(msg) {
        const id = msg ? msg._id : "";
        if (!id || !root.messageByID[id])
            return "";
        root._commit(id, Object.assign({}, msg));
        return id;
    }

    function _drop(id) {
        const m = root.messageByID[id];
        if (m && m.opencodeId && root._byOcId[m.opencodeId] === id)
            delete root._byOcId[m.opencodeId];
        delete root.messageByID[id];
    }

    function _trim() {
        const extra = root._idsBuf.length - root.maxLoadedMessages;
        if (extra <= 0)
            return;
        let hist = 0;
        for (const id of root._idsBuf.splice(0, extra)) {
            const m = root.messageByID[id];
            if (m && m._hist)
                hist++;
            root._drop(id);
        }
        if (hist > 0 && root.currentSessionId) {
            root.chatOffset = Math.max(0, root.chatOffset - hist);
            root.hasMoreMessages = true;
        }
    }

    function pushMessage(msg) {
        const id = root._newId();
        msg._id = id;
        root.messageByID[id] = msg;
        root._idsBuf.push(id);
        if (msg.role === "user" || msg.role === "assistant")
            root._liveCount++;
        root._trim();
        root.scheduleIdsFlush();
        return id;
    }

    function addMessage(message, role) {
        if (message.length === 0)
            return;
        root.pushMessage(root.plainMessage({
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true
        }));
    }

    function removeMessage(index) {
        if (index < 0 || index >= root._idsBuf.length)
            return;
        const id = root._idsBuf[index];
        root._idsBuf.splice(index, 1);
        root._drop(id);
        root.scheduleIdsFlush();
    }

    function addToolPart(message, p) {
        const st = p.state || {};
        const entry = {
            tool: p.tool,
            callID: p.callID,
            kind: p.kind || "",
            status: st.status || "pending",
            input: root.trimBlob(st.input, 4000),
            output: root.trimBlob(st.output, 4000) ?? ""
        };
        const tools = (message.tools || []).slice();
        const idx = tools.findIndex(t => t.callID === p.callID);
        if (idx >= 0)
            tools[idx] = entry;
        else
            tools.push(entry);
        message.tools = tools;
        root.touchMessage(message);
    }

    function clearMessages() {
        moreFetcher.running = false;
        moreFetcher.token++;
        chatFetcher.running = false;
        chatFetcher.token++;
        root._idsBuf = [];
        root.messageByID = ({});
        root._byOcId = ({});
        root.messageIDs = [];
        root._idsDirty = false;
        root._liveCount = 0;
        root.hasMoreMessages = false;
        root.loadingMoreMessages = false;
        root.loadingMessages = false;
        root._loadingSession = "";
        root.chatOffset = 0;
        root.liveContent = "";
        root.liveThinkText = "";
        root.liveThinking = false;
        root.liveDone = false;
        root.tokenCount.input = -1;
        root.tokenCount.output = -1;
        root.tokenCount.total = -1;
    }

    function resetView() {
        root.messageQueue = [];
        if (requester.running)
            root.stop();
        root._pendingSend = [];
        root.clearAttachments();
        requester._sessionBusy = false;
        root.clearPermissionFlags();
        root.contextUsage = null;
        root.clearMessages();
        root.autoApproveSession = false;
    }

    function newSession() {
        root.resetView();
        root.states.currentSessionId = "";
        root.refreshSessions();
    }

    function loadChat(id) {
        if (!id)
            return;
        root.resetView();
        root.states.currentSessionId = id.trim().toString();
        root.loadMessages(root.states.currentSessionId);
    }

    function insertBatch(out, prepend) {
        if (!Array.isArray(out) || out.length === 0)
            return 0;
        const map = root.messageByID;
        const batch = new Array(out.length);
        for (let i = 0; i < out.length; i++) {
            const m = out[i];
            const key = root._newId();
            m._id = key;
            m._hist = true;
            if (m.opencodeId)
                root._byOcId[m.opencodeId] = key;
            map[key] = m;
            batch[i] = key;
        }
        root._idsBuf = prepend ? batch.concat(root._idsBuf) : root._idsBuf.concat(batch);
        if (!prepend)
            root._trim();
        root.scheduleIdsFlush();
        return out.length;
    }

    function loadMessages(id) {
        if (root.loadingMessages && root._loadingSession === id)
            return;
        root.loadingMessages = true;
        root._loadingSession = id;
        root.runHelper("chat", [id, String(root.chatBatch), "0"], out => {
            root.loadingMessages = false;
            if (root._loadingSession !== root.currentSessionId)
                return;
            root.insertBatch(out, false);
            if (Array.isArray(out)) {
                root.chatOffset = out.length;
                root.hasMoreMessages = out.length >= root.chatBatch;
            }
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
        const args = [sessionAtStart, String(root.chatBatch), String(offsetAtStart + root._liveCount)];
        root._runOn(moreFetcher, "chat", args, out => {
            root.loadingMoreMessages = false;
            if (sessionAtStart !== root.currentSessionId) {
                if (onDone)
                    onDone();
                return;
            }
            const n = root.insertBatch(out, true);
            if (n > 0) {
                root.chatOffset = offsetAtStart + n;
                root.hasMoreMessages = out.length >= root.chatBatch;
            } else {
                root.hasMoreMessages = false;
            }
            if (onDone)
                onDone();
        });
    }

    function acpWrite(cmd) {
        if (!acpProc.running) {
            console.warn("acp bridge down, dropped:", cmd.cmd);
            if (cmd.cmd === "send" || cmd.cmd === "new") {
                root.settleTurn();
                root.addMessage("Error: agent bridge is not running — restarting, try again", "interface");
            }
            return false;
        }
        acpProc.write(JSON.stringify(cmd) + "\n");
        return true;
    }

    function sessionCmd(cmd, extra) {
        return Object.assign({
            cmd: cmd,
            sessionId: root.currentSessionId,
            cwd: root.sessionCwd(root.currentSessionId)
        }, extra ?? {});
    }

    function settleTurn() {
        requester._sessionBusy = false;
        root._pendingSend = [];
        if (requester.running)
            requester.markDone();
    }

    function adoptStr(obj, key, value) {
        if (typeof value === "string" && value.length > 0)
            obj[key] = value;
    }

    function adoptModels(list) {
        if (!Array.isArray(list) || list.length === 0)
            return;
        const known = Array.isArray(states.models) ? states.models : [];
        const seen = new Set(known);
        const merged = known.slice();
        for (const m of list) {
            if (!seen.has(m)) {
                seen.add(m);
                merged.push(m);
            }
        }
        if (merged.length !== known.length)
            states.models = merged;
    }

    function handleSSELine(line) {
        if (!line)
            return;
        try {
            root.handleSSE(JSON.parse(line));
        } catch (e) {
            console.warn("handleSSELine parse error:", e, "line:", line);
        }
    }

    function _onSession(event) {
        if (!event.sessionId)
            return;
        root.states.currentSessionId = event.sessionId;
        requester._sessionBusy = false;
        if (requester.running)
            requester.markDone();
        if (Array.isArray(event.efforts))
            root.effortOptions = event.efforts;
        if (Array.isArray(event.modes))
            root.modeOptions = event.modes;
        root.adoptModels(event.models);
        root.adoptStr(states, "model", event.model);
        root.adoptStr(states, "agent", event.mode);
        root.adoptStr(states, "effort", event.effort);
        const pending = root._pendingSend;
        root._pendingSend = [];
        for (const entry of pending)
            root.finishSend(entry.text, entry.attachments);
    }

    function handleSSE(event) {
        if (!event || typeof event.type !== "string")
            return;
        switch (event.type) {
        case "ready":
            root._restartCount = 0;
            if (root.currentSessionId)
                root.acpWrite(root.sessionCmd("sync"));
            return;
        case "session":
            root._onSession(event);
            return;
        case "efforts":
            if (Array.isArray(event.efforts))
                root.effortOptions = event.efforts;
            root.adoptStr(states, "effort", event.effort);
            return;
        case "model":
            root.adoptStr(states, "model", event.model);
            return;
        case "models":
            root.adoptModels(event.models);
            return;
        case "usage":
            root.tokenCount.input = Number(event.input ?? -1);
            root.tokenCount.output = Number(event.output ?? -1);
            root.tokenCount.total = Number(event.total ?? -1);
            return;
        case "context":
            root.contextUsage = {
                used: Number(event.used ?? 0),
                size: Number(event.size ?? 0)
            };
            root.turnCost = event.cost ?? null;
            return;
        case "session.info":
            root.refreshSessions();
            return;
        case "mode":
            root.adoptStr(states, "agent", event.mode);
            if (Array.isArray(event.modes) && event.modes.length > 0)
                root.modeOptions = event.modes;
            return;
        case "error":
            console.warn("acp bridge error:", event.message);
            root.clearAttachments();
            root.settleTurn();
            root.addMessage("Error: " + (event.message || "unknown bridge error"), "interface");
            return;
        case "agent.exited":
            console.warn("acp agent process exited:", event.message);
            root.settleTurn();
            root.addMessage("Error: agent process died (" + (event.message || "unknown") + ") — reload the shell to respawn it", "interface");
            return;
        case "session.status":
            {
                const s = event.properties && event.properties.status;
                if (s) {
                    requester._sessionBusy = s.type === "busy";
                    if (s.type === "idle" && requester.running)
                        requester.markDone();
                }
            }
            return;
        case "permission.asked":
            root._onPermissionEvent(event);
            return;
        case "message.updated":
            if (requester.running) {
                const info = event.properties && event.properties.info;
                if (info && info.role === "user")
                    requester._userMessageId = info.id;
            }
            return;
        case "message.part.updated":
            if (requester.running) {
                const part = event.properties && event.properties.part;
                if (part && part.messageID !== requester._userMessageId)
                    requester.processPart(part);
            }
            return;
        case "elicitation":
            root._onElicitation(event);
            return;
        case "compaction":
            root._onCompaction(event);
            return;
        case "child.session":
            root._onChildSession(event);
            return;
        case "steer.result":
            if (event.outcome === "promptRequired")
                NoonUtils.toast({
                    id: 18,
                    header: qsTr("Steer"),
                    content: qsTr("Prompt required"),
                    icon: "info"
                });
            return;
        case "session.forked":
            root.refreshSessions();
            return;
        }
    }

    function _onPermissionEvent(event) {
        const p = event.properties;
        if (!p || !p.tool)
            return;
        if (root._permQueue.some(q => q.reqId === p.id))
            return;

        const title = p.tool.title || "Tool call";
        const mid = root._byOcId[p.tool.messageID] ?? requester.messageId;
        if (mid && root.messageByID[mid]) {
            root.updateMessage(mid, m => {
                m.functionPending = true;
                m.permissionID = p.id;
                m.permissionCallID = p.tool.callID;
                m.permissionSessionID = p.sessionID;
            });
            if (!root._permMsgIds.includes(mid))
                root._permMsgIds = root._permMsgIds.concat([mid]);
        }

        const entry = {
            title: title,
            callID: p.tool.callID,
            reqId: p.id,
            sessionID: p.sessionID,
            options: Array.isArray(p.options) ? p.options : []
        };
        root._permQueue = root._permQueue.concat([entry]);

        if (root.autoApproveSession) {
            root.resolvePermission(entry.reqId, true);
            return;
        }
        if (root._permQueue.length === 1) {
            root.pendingPermission = entry;
            root.permissionAsked(title);
        }
    }

    function _clearFlagsFor(callID) {
        const keep = [];
        for (const id of root._permMsgIds) {
            const m = root.messageByID[id];
            if (!m)
                continue;
            if (callID === undefined || m.permissionCallID === callID) {
                root.updateMessage(id, n => {
                    n.functionPending = false;
                    delete n.permissionID;
                    delete n.permissionCallID;
                    delete n.permissionSessionID;
                });
            } else {
                keep.push(id);
            }
        }
        root._permMsgIds = keep;
    }

    function resolvePermission(reqId, approved, optionId) {
        if (reqId === undefined || reqId === "")
            return;
        const reply = {
            cmd: "reply",
            reqId: reqId,
            approved: approved
        };
        if (optionId !== undefined && optionId !== null && optionId !== "")
            reply.optionId = optionId;
        root.acpWrite(reply);
        if (root._permDialog && root._permDialog.reqId === reqId) {
            const dlg = root._permDialog;
            root._permDialog = null;
            Qt.callLater(() => dlg.destroy());
        }
        const entry = root._permQueue.find(e => e.reqId === reqId);
        if (!entry)
            return;
        const wasHead = root.pendingPermission && root.pendingPermission.reqId === reqId;
        root._permQueue = root._permQueue.filter(e => e.reqId !== reqId);
        root._clearFlagsFor(entry.callID);
        if (!wasHead)
            return;
        const head = root._permQueue.length > 0 ? root._permQueue[0] : null;
        root.pendingPermission = head;
        if (!head)
            return;
        if (root.autoApproveSession)
            root.resolvePermission(head.reqId, true);
        else
            root.permissionAsked(head.title);
    }

    function _showPermissionOptions(text, reqId, options) {
        if (root._permDialog) {
            const old = root._permDialog;
            root._permDialog = null;
            Qt.callLater(() => old.destroy());
        }
        const parent = Globals.main.sidebar;
        if (!parent) {
            NoonUtils.requestDialog("assure", {
                title: "Permission Request",
                description: text,
                acceptText: "Accept",
                onAccepted: () => root.resolvePermission(reqId, true),
                onCanceled: () => root.resolvePermission(reqId, false)
            });
            return;
        }
        const buttons = [{
                label: qsTr("Reject"),
                action: () => root.resolvePermission(reqId, false)
            }];
        for (const opt of options) {
            const approved = !String(opt.kind ?? "").startsWith("reject");
            buttons.push({
                label: String(opt.name ?? opt.optionId ?? "Allow"),
                action: () => root.resolvePermission(reqId, approved, opt.optionId)
            });
        }
        root._permDialog = permissionDialogComponent.createObject(parent, {
            reqId: reqId,
            dialogText: text,
            buttonData: buttons
        });
    }

    function respondToPermission(messageData, response) {
        if (!messageData || messageData.permissionID === undefined)
            return;
        root.resolvePermission(messageData.permissionID, response !== "reject");
    }

    function answerPending(approved) {
        const p = root.pendingPermission;
        if (!p)
            return;
        root.resolvePermission(p.reqId, approved);
    }

    function answerAll() {
        root.autoApproveSession = true;
        root.answerPending(true);
        NoonUtils.toast({
            id: 7,
            header: qsTr("Auto-approve on"),
            content: qsTr("All tool calls this session run without asking"),
            icon: "check"
        });
    }

    function clearPermissionFlags(callID) {
        if (callID === undefined) {
            root._permQueue = [];
            root.pendingPermission = null;
            if (root._permDialog) {
                const dlg = root._permDialog;
                root._permDialog = null;
                Qt.callLater(() => dlg.destroy());
            }
        } else {
            root._permQueue = root._permQueue.filter(e => e.callID !== callID);
            root.pendingPermission = root._permQueue.length > 0 ? root._permQueue[0] : null;
        }
        root._clearFlagsFor(callID);
    }

    function approveCommand(messageData) {
        root.respondToPermission(messageData, "once");
    }

    function rejectCommand(messageData) {
        root.respondToPermission(messageData, "reject");
    }

    function _onElicitation(event) {
        if (event.reqId === undefined)
            return;
        const schema = event.schema && typeof event.schema === "object" ? event.schema : {};
        const props = schema.properties && typeof schema.properties === "object"
            ? schema.properties : {};
        const fields = [];
        const values = {};
        for (const key of Object.keys(props)) {
            const spec = props[key] || {};
            let def = spec.default;
            if (def === undefined) {
                if (spec.type === "boolean")
                    def = false;
                else if (spec.type === "array")
                    def = [];
                else if (spec.type === "number" || spec.type === "integer")
                    def = 0;
                else if (NoonUtils.isList(spec.oneOf))
                    def = spec.oneOf[0]?.const ?? "";
                else if (NoonUtils.isList(spec.enum))
                    def = spec.enum[0] ?? "";
                else
                    def = "";
            }
            values[key] = def;
            fields.push({ key: key, spec: spec, values: values });
        }
        root.pendingElicitation = {
            reqId: event.reqId,
            message: String(event.message ?? ""),
            fields: fields,
            values: values
        };
    }

    function answerElicitation(accepted, values) {
        const pending = root.pendingElicitation;
        if (!pending)
            return;
        root.pendingElicitation = null;
        root._writeElicitation(pending.reqId, accepted, values ?? pending.values);
    }

    function _writeElicitation(reqId, accepted, values) {
        const cmd = {
            cmd: "elicit",
            reqId: reqId,
            accepted: accepted
        };
        if (accepted)
            cmd.content = Object.assign({}, values);
        root.acpWrite(cmd);
    }

    function _onCompaction(event) {
        const phase = String(event.phase ?? "start");
        if (phase === root._lastCompactionPhase)
            return;
        root._lastCompactionPhase = phase;
        NoonUtils.toast({
            id: 17,
            header: qsTr("Compaction"),
            content: phase === "start" ? qsTr("Compacting context…") : qsTr("Context compacted"),
            icon: "autorenew"
        });
    }

    function _onChildSession(event) {
        const msg = requester.message;
        if (!msg)
            return;
        root.addToolPart(msg, {
            tool: "child.session",
            callID: String(event.childSessionId ?? ""),
            kind: "child",
            state: {
                status: "info",
                input: {
                    title: String(event.title ?? event.childSessionId ?? "child"),
                    depth: Number(event.depth ?? 0)
                },
                output: ""
            }
        });
    }

    function openInTerm(sessionId = root.states.currentSessionId) {
        NoonUtils.runInTerminal(`opencode -s '${sessionId}'`);
    }

    function getModel() {
        return {
            name: root.currentModelId
        };
    }

    function showStatus() {
        const tc = root.tokenCount;
        const cu = root.contextUsage;
        const lines = ["Session: " + (root.currentSessionId || "(none)"), "Model: " + (root.currentModelId || "(none)") + (root.modelList.length > 0 ? "" : "  [server list not loaded yet]"), "Effort: " + (root.currentEffortId || "(none)") + (root.effortOptions.length > 0 ? "  (server offers: " + root.effortOptions.join(", ") + ")" : "  [server offers none for this model]"), "Agent mode: " + root.currentAgentId + (root.modeOptions.length > 0 ? "  (server offers: " + root.modeOptions.join(", ") + ")" : "  [server modes not loaded yet]"), "Auto-approve: " + (root.autoApproveSession ? "on (this session)" : "off"), "Last turn tokens: " + ((tc && tc.total >= 0) ? ("in " + tc.input + " / out " + tc.output + " / total " + tc.total) : "(none yet)"), "Context window: " + (cu && cu.size > 0 ? (cu.used + " / " + cu.size + " (" + Math.round(100 * cu.used / cu.size) + "%)") : "(unknown)")];
        root.addMessage(lines.join("\n"), "interface");
    }

    function setModel(modelId) {
        if (!modelId || modelId.length === 0)
            return;
        states.model = modelId;
        if (root.currentSessionId)
            root.acpWrite(root.sessionCmd("model", {
                model: modelId
            }));
        root.addMessage("Model set to " + modelId, "interface");
    }

    function setEffort(effort) {
        const e = (effort ?? "").trim();
        if (!e) {
            states.effort = "";
            root.addMessage("Effort cleared", "interface");
            return;
        }
        if (root.effortOptions.length > 0 && !root.effortOptions.includes(e)) {
            root.addMessage("Effort '" + e + "' not offered by server (offers: " + root.effortOptions.join(", ") + ")", "interface");
            return;
        }
        states.effort = e;
        if (root.effortOptions.length === 0)
            root.addMessage("Effort set to " + e + " (server offers no effort levels for the current model — stored, applies when available)", "interface");
        else
            root.addMessage("Effort set to " + e, "interface");
    }

    function setAgent(mode) {
        const m = (mode ?? "").trim();
        if (!m)
            return;
        const valid = root.modeOptions.length > 0 ? root.modeOptions : root.modeFallback;
        if (!valid.includes(m)) {
            root.addMessage("Unknown agent mode '" + m + "' (known: " + valid.join(", ") + ")", "interface");
            return;
        }
        states.agent = m;
        if (root.currentSessionId)
            root.acpWrite(root.sessionCmd("mode", {
                mode: m
            }));
        root.addMessage("Agent mode set to " + m + " (server confirms on next event)", "interface");
    }

    function setSkill(skillName) {
        const s = (skillName ?? "").trim();
        if (!s) {
            root.pendingSkill = "";
            root.addMessage("Skill cleared", "interface");
            return;
        }
        const known = Array.isArray(root.skills) ? root.skills : [];
        if (!known.includes(s)) {
            root.addMessage("Unknown skill '" + s + "' (known: " + known.join(", ") + ")", "interface");
            return;
        }
        root.pendingSkill = s;
        root.addMessage("Skill '" + s + "' armed — the agent will load it via its skill tool on your next message (watch for the skill tool call + possible approval)", "interface");
    }

    function skillPromptPrefix() {
        if (!root.pendingSkill)
            return "";
        const name = root.pendingSkill;
        root.pendingSkill = "";
        return "Invoke the \"" + name + "\" skill using your skill tool and follow it for the task below. If the skill tool is unavailable, say so instead of guessing.\n\nTask:\n";
    }

    function cleanDir(dir) {
        const clean = Paths.methods.trim(String(dir ?? ""));
        if (!clean.startsWith("/") || clean.includes("file:"))
            return Paths.methods.trim(Paths.standard.home);
        return clean;
    }

    function _rebuildCwdMap() {
        const map = ({});
        for (const s of root.sessions) {
            if (s && s.id && s.directory)
                map[s.id] = root.cleanDir(s.directory);
        }
        root._cwdBySession = map;
    }

    function sessionCwd(sessionId) {
        return root._cwdBySession[sessionId] ?? root.cleanDir("");
    }

    function refreshSessions() {
        if (root._sessDirty)
            return;
        root._sessDirty = true;
        NoonUtils.inlineTimer(() => {
            root._sessDirty = false;
            sessionsFetcher.refresh();
        }, 100);
    }

    function createSessionAndSend(message) {
        const attachments = root._pendingAttachments.slice();
        root.clearAttachments();
        requester._sessionBusy = true;
        root._pendingSend = [...root._pendingSend, { text: message, attachments: attachments }];
        root.acpWrite(root.sessionCmd("new", {
            model: root.currentModelId,
            effort: root.effortOptions.includes(root.currentEffortId) ? root.currentEffortId : "",
            mode: root.currentAgentId
        }));
    }

    function sendUserMessage(message) {
        if (message.length === 0 && root._pendingAttachments.length === 0)
            return;
        if (requester._sessionBusy || !root.currentSessionId)
            root.createSessionAndSend(message);
        else
            root.finishSend(message);
    }

    function finishSend(message, attachments) {
        const atts = attachments ?? root._pendingAttachments.slice();
        root.clearAttachments();
        const id = root.pushMessage(root.plainMessage({
            "role": "user",
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
            "queued": true,
            "attachments": atts
        }));
        root.queueMessage(id, message, atts);
    }

    function queueMessage(id, text, attachments) {
        root.messageQueue = [...root.messageQueue,
            {
                id: id,
                text: text,
                attachments: attachments ?? []
            }
        ];
        if (!requester.running)
            root.processQueue();
    }

    function processQueue() {
        if (requester.running)
            return;
        while (root.messageQueue.length > 0) {
            const next = root.messageQueue[0];
            root.messageQueue = root.messageQueue.slice(1);
            if (!root.messageByID[next.id])
                continue;
            root.updateMessage(next.id, m => {
                m.queued = false;
            });
            requester.makeRequest(next.text, next.attachments);
            return;
        }
    }

    function finalizeResponse() {
        root.refreshSessions();
        root.responseFinished();
        root.processQueue();
    }

    function regenerate(messageIndex) {
        const buf = root._idsBuf;
        if (messageIndex < 0 || messageIndex >= buf.length)
            return;
        const message = root.messageByID[buf[messageIndex]];
        if (!message || message.role !== "assistant")
            return;
        for (const id of buf.splice(messageIndex, buf.length - messageIndex))
            root._drop(id);
        root.scheduleIdsFlush();

        let lastUserID = "";
        for (let i = buf.length - 1; i >= 0; i--) {
            const m = root.messageByID[buf[i]];
            if (m && m.role === "user") {
                lastUserID = buf[i];
                break;
            }
        }
        if (!lastUserID)
            return;
        root.messageQueue = [
            {
                id: lastUserID,
                text: root.messageByID[lastUserID].rawContent,
                attachments: root.messageByID[lastUserID].attachments ?? []
            },
            ...root.messageQueue];
        if (!requester.running)
            root.processQueue();
    }

    function stop() {
        if (!requester.running)
            return;
        requester.running = false;
        root.acpWrite({
            cmd: "cancel",
            sessionId: root.currentSessionId
        });
        root.clearPermissionFlags();
        const mark = "\n\n*[Stopped]*";
        const apply = m => {
            m.thinking = false;
            m.done = true;
            m.rawContent += mark;
            m.content += mark;
        };
        if (requester.message) {
            if (!root.updateMessage(requester.messageId, apply))
                apply(requester.message);
            requester.syncLive();
        }
        root.finalizeResponse();
    }

    function addAnnotations(urls) {
        const list = Array.isArray(urls) ? urls : [urls];
        const valid = list.map(u => {
            const s = String(u ?? "").trim();
            if (!s)
                return "";
            return s.startsWith("file://") ? s : "file://" + s;
        }).filter(u => u.length > 7 && !root._pendingAnnotations.includes(u));

        if (valid.length > 0) {
            root._pendingAnnotations = root._pendingAnnotations.concat(valid);
            return true;
        }
        return false;
    }

    function removeAnnotation(uri) {
        root._pendingAnnotations = root._pendingAnnotations.filter(i => i !== uri);
    }

    function clearAnnotations() {
        root._pendingAnnotations = [];
    }

    function pickAttachments() {
        attachmentFileDialog.open();
    }

    function addAttachment(path) {
        let p = String(path ?? "");
        if (p.startsWith("file://")) {
            p = p.slice(7);
            try {
                p = decodeURIComponent(p);
            } catch (e) {
                // Leave malformed encoding untouched.
            }
        }
        if (p && !root._pendingAttachments.includes(p))
            root._pendingAttachments = root._pendingAttachments.concat([p]);
    }

    function removeAttachment(path) {
        root._pendingAttachments = root._pendingAttachments.filter(p => p !== path);
    }

    function clearAttachments() {
        root._pendingAttachments = [];
    }

    function captureWindowAnnotation() {
        root._waitingForScreenshot = true;
        ScreenShotService.request({
            region: ScreenShotService.Regions.Window,
            temp: true
        });
    }

    Connections {
        target: ScreenShotService
        function onScreenshotCompleted(path) {
            if (!root._waitingForScreenshot)
                return;
            root._waitingForScreenshot = false;
            root.addAnnotations(path);

            if (!Globals.main.sidebar.reveal || Globals.main.sidebar.selectedCategory !== "AI")
                Ipc.call(["sidebar", "reveal", "AI"]);
        }
        function onScreenshotCancelled() {
            root._waitingForScreenshot = false;
        }
    }

    FileDialog {
        id: attachmentFileDialog
        title: qsTr("Attach files")
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            for (const f of files)
                root.addAttachment(f);
        }
    }

    Component {
        id: permissionDialogComponent
        CenterDialog {
            id: permDlg
            property var reqId: ""
            property string dialogText: ""

            show: true
            onDismissed: root.resolvePermission(permDlg.reqId, false)

            contentItem: Item {
                implicitWidth: 400
                implicitHeight: msg.implicitHeight

                StyledText {
                    id: msg
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    text: permDlg.dialogText
                    wrapMode: Text.WordWrap
                    color: Colors.colOnLayer0
                    font: Fonts.request("main", "small")
                }
            }
        }
    }

    Process {
        id: acpProc
        running: true
        stdinEnabled: true
        command: [root.baseCmd, "acp"]
        stdout: SplitParser {
            onRead: data => root.handleSSELine(data)
        }
        environment: root.bridgeEnv
        onExited: {
            console.warn("acp bridge exited, restarting");
            root.settleTurn();
            root._restartCount++;
            NoonUtils.inlineTimer(() => {
                acpProc.running = true;
            }, Math.min(1000 * root._restartCount, 10000));
        }
    }

    Fetcher {
        id: sessionsFetcher
        command: [root.baseCmd, "sessions"]
        environment: root.bridgeEnv
        onStreamFinished: {
            if (Array.isArray(sessionsFetcher.data))
                root.sessions = sessionsFetcher.data;
        }
    }

    Fetcher {
        id: skillsFetcher
        command: [root.baseCmd, "skills"]
        environment: root.bridgeEnv
        onStreamFinished: {
            if (Array.isArray(skillsFetcher.data))
                root.skills = skillsFetcher.data;
        }
    }

    Fetcher {
        id: chatFetcher
        autoRun: false
        property int token: 0
        property var onDone: null
        environment: root.bridgeEnv
        onStreamFinished: {
            const cb = chatFetcher.onDone;
            chatFetcher.onDone = null;
            if (cb)
                cb(chatFetcher.data);
        }
    }

    Fetcher {
        id: moreFetcher
        autoRun: false
        property int token: 0
        property var onDone: null
        environment: root.bridgeEnv
        onStreamFinished: {
            const cb = moreFetcher.onDone;
            moreFetcher.onDone = null;
            if (cb)
                cb(moreFetcher.data);
        }
    }

    Fetcher {
        id: toolsFetcher
        autoRun: false
        property int token: 0
        property var onDone: null
        environment: root.bridgeEnv
        onStreamFinished: {
            const cb = toolsFetcher.onDone;
            toolsFetcher.onDone = null;
            if (cb)
                cb(toolsFetcher.data);
        }
    }

    function _runOn(fetcher, cmd, args, onDone) {
        fetcher.running = false;
        const t = ++fetcher.token;
        fetcher.command = [root.baseCmd, cmd].concat(args);
        fetcher.onDone = data => {
            if (t === fetcher.token && onDone)
                onDone(data);
        };
        fetcher.refresh();
    }

    function runHelper(cmd, args, onDone) {
        root._runOn(chatFetcher, cmd, args, onDone);
    }

    function runToolsHelper(args, onDone) {
        root._runOn(toolsFetcher, "gen-tools", args, onDone);
    }

    QtObject {
        id: requester
        property var message: null
        property string messageId: ""
        property bool running: false
        property string _userMessageId: ""
        property bool _sessionBusy: false
        property bool _liveDirty: false

        function syncLive() {
            const m = requester.message;
            if (!m)
                return;
            root.liveContent = m.content;
            root.liveThinkText = m.thinkText;
            root.liveThinking = m.thinking;
            root.liveDone = m.done;
            requester._liveDirty = false;
        }

        function markLiveDirty() {
            if (!requester._liveDirty) {
                requester._liveDirty = true;
                NoonUtils.inlineTimer(requester.syncLive, 50);
            }
        }

        function processPart(p) {
            const msg = requester.message;
            if (!msg)
                return;
            if (!msg.opencodeId && p.messageID) {
                msg.opencodeId = p.messageID;
                if (requester.messageId)
                    root._byOcId[p.messageID] = requester.messageId;
            }
            if (p.type === "reasoning" && p.text) {
                msg.thinking = false;
                msg.thinkText += p.text;
            } else if (p.type === "text" && p.text) {
                msg.thinking = false;
                msg.content += p.text;
                msg.rawContent += p.text;
            } else if (p.type === "tool") {
                msg.thinking = false;
                root.addToolPart(msg, p);
                return;
            }
            requester.markLiveDirty();
        }

        function makeRequest(userMessage, attachments) {
            const atts = Array.isArray(attachments) ? attachments : [];
            requester.running = true;
            requester._userMessageId = "";

            requester.message = root.plainMessage({
                "role": "assistant",
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false
            });
            requester.messageId = "";
            requester.syncLive();
            requester.messageId = root.pushMessage(requester.message);

            root.acpWrite(root.sessionCmd("send", {
                text: (userMessage.startsWith("/") ? "" : root.skillPromptPrefix()) + userMessage,
                model: root.currentModelId,
                effort: root.effortOptions.includes(root.currentEffortId) ? root.currentEffortId : "",
                mode: root.currentAgentId,
                attachments: atts
            }));
        }

        function markDone() {
            const msg = requester.message;
            if (!msg || msg.done)
                return;
            requester.running = false;
            const apply = m => {
                m.done = true;
                m.thinking = false;
            };
            if (!root.updateMessage(requester.messageId, apply))
                apply(msg);
            requester.syncLive();
            root.finalizeResponse();
        }
    }
}
