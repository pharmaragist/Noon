pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common

Singleton {
    id: root

    readonly property string dbPath: Paths.services.screenTimeDB
    readonly property Toplevel activeTop: ToplevelManager.activeToplevel
    readonly property string activeApp: activeTop && activeTop.activated !== false
        ? (activeTop.appId ?? "")
        : ""

    property int saveInterval: 12000
    property string today: todayStr()
    property var sessions: []
    property var appTimes: []
    property string currentClass: ""
    property real sessionStart: 0
    property bool loaded: false
    property string pendingApp: ""

    Component.onCompleted: {
        Paths.methods.mkdir(dbPath);
        loadToday();
    }

    onActiveAppChanged: function () {
        if (!root.loaded) {
            root.pendingApp = root.activeApp;
            return;
        }
        setActiveApp(root.activeApp);
    }

    function dateStr(date) {
        const pad = n => String(n).padStart(2, "0");
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
    }

    function todayStr() {
        return dateStr(new Date());
    }

    function secsOf(date) {
        return date.getHours() * 3600 + date.getMinutes() * 60 + date.getSeconds();
    }

    function loadToday() {
        root.today = todayStr();
        root.loaded = false;
        root.currentClass = "";
        root.sessionStart = 0;
        dayFile.path = dbPath + "/" + root.today + ".json";
        dayFile.reload();
    }

    function flushPending() {
        const app = root.pendingApp || root.activeApp;
        root.pendingApp = "";
        setActiveApp(app);
    }

    function flushSession() {
        if (!root.currentClass || root.sessionStart <= 0)
            return;

        const nowMs = Date.now();
        const startMs = root.sessionStart;
        const delta = Math.floor((nowMs - startMs) / 1000);
        root.sessionStart = nowMs;
        if (delta <= 0 || delta > 86400)
            return;

        const startDate = new Date(startMs);
        const start = dateStr(startDate) === root.today ? secsOf(startDate) : 0;
        const end = secsOf(new Date(nowMs));

        root.sessions = root.sessions.concat([{
                class: root.currentClass,
                start: start,
                end: Math.max(end, start)
            }]);
    }

    function rebuild() {
        const totals = {};
        for (const session of root.sessions) {
            const cls = session?.class ?? "";
            totals[cls] = (totals[cls] ?? 0) + ((session?.end ?? 0) - (session?.start ?? 0));
        }
        root.appTimes = Object.keys(totals).sort().map(cls => ({
                class: cls,
                timeSeconds: totals[cls]
            }));
        root.appTimesChanged();
    }

    function setActiveApp(appId) {
        const cls = appId ?? "";
        if (root.currentClass === cls)
            return;
        flushSession();
        root.currentClass = cls;
        root.sessionStart = Date.now();
        rebuild();
        saveTimer.restart();
    }

    function save() {
        if (!root.loaded)
            return;
        dayFile.setText(JSON.stringify(root.sessions));
    }

    function checkpoint() {
        if (!root.loaded)
            return;
        flushSession();
        rebuild();
        save();

        const nowDate = todayStr();
        if (nowDate === root.today)
            return;

        root.sessions = [];
        loadToday();
    }

    function getDay(date) {
        if (date === root.today)
            return root.sessions.slice();
        const raw = Paths.methods.readFile(dbPath + "/" + date + ".json");
        if (!raw)
            return [];
        try {
            const parsed = JSON.parse(raw);
            return Array.isArray(parsed) ? parsed : [];
        } catch (error) {
            return [];
        }
    }

    function getDayTotals(date) {
        const totals = {};
        for (const session of getDay(date)) {
            const cls = session?.class ?? "";
            totals[cls] = (totals[cls] ?? 0) + ((session?.end ?? 0) - (session?.start ?? 0));
        }
        return Object.keys(totals).sort().map(cls => ({
                class: cls,
                timeSeconds: totals[cls]
            }));
    }

    function getDayTimeline(date, fromSec, toSec) {
        const totals = {};
        for (const session of getDay(date)) {
            const start = Math.max(session?.start ?? 0, fromSec);
            const end = Math.min(session?.end ?? 0, toSec);
            if (end <= start)
                continue;
            const cls = session?.class ?? "";
            totals[cls] = (totals[cls] ?? 0) + (end - start);
        }
        return Object.keys(totals).sort().map(cls => ({
                class: cls,
                timeSeconds: totals[cls]
            }));
    }

    FileView {
        id: dayFile

        onLoaded: {
            if (root.loaded)
                return;
            let parsed = [];
            try {
                parsed = JSON.parse(dayFile.text());
            } catch (error) {
                parsed = [];
            }
            root.sessions = Array.isArray(parsed) ? parsed : [];
            root.loaded = true;
            root.rebuild();
            root.flushPending();
        }

        onLoadFailed: error => {
            if (root.loaded)
                return;
            if (error !== FileViewError.FileNotFound)
                console.warn("ScreenTimeService: failed to load", dayFile.path, error);
            root.sessions = [];
            root.loaded = true;
            root.rebuild();
            root.flushPending();
        }

        onSaveFailed: error => console.warn("ScreenTimeService: failed to save", dayFile.path, error)
    }

    Timer {
        id: saveTimer
        interval: root.saveInterval
        onTriggered: root.save()
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.checkpoint()
    }
}
