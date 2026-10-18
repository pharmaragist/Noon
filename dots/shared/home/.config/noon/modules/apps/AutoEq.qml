import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import qs.services

// Self-contained AutoEq browser. Searches the AutoEq measurement index, asks
// the AutoEq service for a parametric correction and saves the resulting bands
// as a custom preset on EqService (which then applies them to EasyEffects).
FloatingWindow {
    id: root
    title: "AutoEq"
    minimumSize: Qt.size(760, 580)
    maximumSize: Qt.size(760, 580)
    color: Colors.m3.m3surface
    readonly property int mainRounding: Mem.hypr.rounding

    // Built once from /entries: [{name, prepared}] so typing only runs the
    // fuzzy pass, not a re-prepare of 6k strings.
    property var index: []
    property var entries: ({})
    property string status: "Loading measurements…"
    property bool busy: false
    property bool fetching: false
    property string pendingModel: ""
    property string pendingSource: ""

    // The /entries index is ~660KB, so reuse the disk copy and only refetch
    // when it is missing or older than this.
    readonly property int staleAfterMs: 7 * 24 * 60 * 60 * 1000

    readonly property var targets: [
        "Auto", "Harman over-ear 2018", "Harman in-ear 2019", "AutoEq in-ear", "Flat"
    ]
    readonly property var sources: [
        "oratory1990", "crinacle", "Super Review", "Rtings", "HypetheSonics", "Filk"
    ]

    function dismiss() {
        root.destroy();
    }

    function subtitleFor(entry) {
        if (!entry)
            return "";
        return [entry.source, entry.form, entry.rig].filter(x => x).join(" · ");
    }

    function isPending(model) {
        return root.busy && root.pendingModel === model;
    }

    onVisibleChanged: if (!visible)
        root.destroy()

    Shortcut {
        sequences: ["Ctrl+F", "/"]
        onActivated: {
            searchField.forceActiveFocus();
            searchField.selectAll();
        }
    }

    function pickEntry(model) {
        const list = root.entries ? root.entries[model] : null;
        if (!list || list.length === 0)
            return null;
        for (const s of root.sources) {
            const hit = list.find(e => e.source === s && e.rig);
            if (hit)
                return hit;
        }
        return list.find(e => e.rig) ?? list[0];
    }

    function resolveTarget(entry) {
        const chosen = root.targets[targetCombo.currentIndex];
        if (chosen && chosen !== "Auto")
            return chosen;
        const form = (entry?.form ?? "").toLowerCase();
        return form.indexOf("over") !== -1 ? "Harman over-ear 2018" : "Harman in-ear 2019";
    }

    // AutoEq filter type -> EasyEffects/LSP band type index.
    function eeType(t) {
        if (t === "LOW_SHELF")
            return 5;
        if (t === "HIGH_SHELF")
            return 3;
        return 1;
    }

    function applyModel(model) {
        if (root.busy)
            return;
        const entry = pickEntry(model);
        if (!entry) {
            root.status = "No usable measurement for " + model;
            return;
        }

        const payload = {
            name: model,
            source: entry.source,
            target: resolveTarget(entry),
            parametric_eq: true,
            parametric_eq_config: "8_PEAKING_WITH_SHELVES",
            // The hosted API errors while reading its default response config,
            // so send one explicitly.
            response: {
                fr_f_step: 1.01,
                fr_fields: ["frequency", "raw"],
                base64fp16: false
            }
        };
        if (entry.rig)
            payload.rig = entry.rig;

        root.pendingModel = model;
        root.pendingSource = entry.source;
        root.busy = true;
        root.status = "Computing EQ for " + model + "…";
        eqFetcher.command = [
            "curl", "-sSL", "-X", "POST",
            "-H", "Content-Type: application/json",
            "-d", JSON.stringify(payload),
            "https://autoeq.app/equalize"
        ];
        eqFetcher.refresh();
    }

    // Cache the /entries index on disk so reopening the app is instant. It is
    // read synchronously at startup (no load-order race) and the network is only
    // hit when the cache is missing, stale, or explicitly refreshed.
    PluginFileView {
        id: indexCache
        fileName: "autoeq-index"

        JsonAdapter {
            property var cache: ({})
        }
    }

    function loadIndex() {
        let stored = null;
        try {
            const raw = Paths.methods.readFile(indexCache.path);
            if (raw && raw.length)
                stored = JSON.parse(raw).cache;
        } catch (e) {
            stored = null;
        }

        const cached = stored?.entries;
        if (!cached || Object.keys(cached).length === 0) {
            root.fetchEntries();
            return;
        }

        root.applyEntries(cached);
        const fetchedAt = Date.parse(stored?.fetchedAt ?? "");
        if (!isFinite(fetchedAt) || Date.now() - fetchedAt > root.staleAfterMs) {
            root.status = root.index.length + " headphones (cached) · refreshing…";
            root.fetchEntries();
        }
    }

    function applyEntries(d) {
        root.entries = d;
        root.index = Object.keys(d).map(n => ({
                    name: n,
                    prepared: Fuzzy.prepare(n)
                }));
        root.status = root.index.length + " headphones · pick one to apply";
    }

    function storeCache(d) {
        indexCache.data.cache = {
            fetchedAt: new Date().toISOString(),
            entries: d
        };
    }

    function fetchEntries() {
        if (root.fetching)
            return;
        root.fetching = true;
        entriesFetcher.refresh();
    }

    Component.onCompleted: root.loadIndex()

    Fetcher {
        id: entriesFetcher
        autoRun: false
        command: ["curl", "-sSL", "https://autoeq.app/entries"]
        onStreamFinished: {
            root.fetching = false;
            const d = entriesFetcher.data;
            if (!d) {
                const n = root.index.length;
                if (n > 0)
                    root.status = n + " headphones (cached) · offline";
                else
                    root.status = "Couldn't reach AutoEq — check your connection";
                return;
            }
            root.applyEntries(d);
            root.storeCache(d);
        }
    }

    Fetcher {
        id: eqFetcher
        autoRun: false
        onStreamFinished: {
            root.busy = false;
            const d = eqFetcher.data;
            const pe = d?.parametric_eq;
            if (!pe || !pe.filters || pe.filters.length === 0) {
                root.status = "AutoEq error: " + (d?.detail ?? "no EQ returned");
                return;
            }

            const name = root.pendingModel;
            const bands = pe.filters.map(f => ({
                        type: root.eeType(f.type),
                        freq: Math.round((f.fc ?? 1000) * 100) / 100,
                        gain: Math.round((f.gain ?? 0) * 100) / 100,
                        q: Math.round((f.q ?? 0.707) * 1000) / 1000
                    }));

            EqService.saveCustomPreset(name, {
                preamp: Math.round((pe.preamp ?? 0) * 10) / 10,
                source: root.pendingSource,
                bands: bands
            });
            EqService.applyPresetObject({
                preamp: Math.round((pe.preamp ?? 0) * 10) / 10,
                bands: bands
            });
            NoonUtils.toast({
                header: "AutoEq",
                content: name + " applied · " + bands.length + " bands",
                icon: "headphones"
            });
            root.dismiss();
        }
    }

    Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.topMargin: Padding.normal
                Layout.rightMargin: Padding.huge
                Layout.leftMargin: Padding.huge
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: Padding.normal

                Symbol {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "headphones"
                    iconSize: 18
                    color: Colors.m3.m3onSurfaceVariant
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    text: "AutoEq"
                    font: Fonts.request("title", "normal")
                    color: Colors.m3.m3onSurface
                }

                StyledComboBox {
                    id: targetCombo
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 230
                    _model: root.targets
                    currentIndex: 0
                    showDisplayIcon: false
                }

                RippleButtonWithIcon {
                    implicitSize: 25
                    buttonRadius: Rounding.normal
                    materialIcon: "refresh"
                    downAction: () => root.fetchEntries()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: Padding.huge
                Layout.leftMargin: Padding.huge
                Layout.preferredHeight: 50

                Symbol {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "search"
                    iconSize: 18
                    color: Colors.m3.m3onSurfaceVariant
                }

                StyledTextField {
                    id: searchField
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    placeholderText: "Search headphones…"
                    font: Fonts.request("main", "large")
                    color: Colors.m3.m3onSurface
                    background: null
                    focus: true
                    property string _query: ""
                    onTextChanged: NoonUtils.inlineTimer(() => {
                        _query = searchField.text;
                    }, 150)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            list.forceActiveFocus();
                            if (list.currentIndex < 0 && list.count > 0)
                                list.currentIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (list.count > 0)
                                root.applyModel(list.model.values[Math.max(0, list.currentIndex)]);
                            event.accepted = true;
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colors.m3.m3surfaceContainer
                topRadius: root.mainRounding

                StyledListView {
                    id: list
                    clip: true
                    radius: root.mainRounding - anchors.margins
                    anchors.fill: parent
                    anchors.margins: Padding.normal
                    focus: true
                    keyNavigationWraps: true
                    highlightMoveDuration: 200

                    hinter {
                        color: Colors.m3.m3surfaceContainer
                        anchors.margins: -Padding.normal
                    }

                    highlight: StyledRect {
                        width: list.width
                        height: 54
                        radius: Rounding.verylarge
                        color: Colors.m3.m3secondaryContainer
                        z: 0
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (list.currentIndex >= 0 && list.currentIndex < list.count)
                                root.applyModel(list.model.values[list.currentIndex]);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up && list.currentIndex === 0) {
                            searchField.forceActiveFocus();
                            event.accepted = true;
                        }
                    }

                    model: ScriptModel {
                        values: {
                            const query = searchField._query;
                            if (root.index.length === 0)
                                return [];
                            if (!query)
                                return root.index.slice(0, 60).map(i => i.name);

                            const results = Fuzzy.go(query, root.index, {
                                all: true,
                                key: "prepared"
                            });
                            return results.slice(0, 300).map(r => r?.obj?.name).filter(n => n);
                        }
                    }

                    delegate: Item {
                        id: delegateRoot
                        required property string modelData
                        required property int index
                        readonly property var entry: root.pickEntry(modelData)

                        anchors.left: parent?.left
                        anchors.right: parent?.right
                        implicitHeight: 54

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Padding.large
                            anchors.rightMargin: Padding.large
                            spacing: Padding.large

                            Symbol {
                                Layout.alignment: Qt.AlignVCenter
                                icon: "graphic_eq"
                                iconSize: 20
                                color: Colors.m3.m3onSurface
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: delegateRoot.modelData
                                    font: Fonts.request("main", "normal")
                                    color: Colors.m3.m3onSurface
                                    truncate: true
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: !!delegateRoot.entry
                                    text: root.subtitleFor(delegateRoot.entry)
                                    font: Fonts.request("main", 11)
                                    color: Colors.m3.m3onSurfaceVariant
                                    truncate: true
                                }
                            }

                            MaterialLoadingIndicator {
                                readonly property bool thisRow: root.isPending(delegateRoot.modelData)
                                Layout.alignment: Qt.AlignVCenter
                                loading: thisRow
                                visible: thisRow
                                implicitSize: 20
                            }

                            Symbol {
                                Layout.alignment: Qt.AlignVCenter
                                visible: !root.isPending(delegateRoot.modelData)
                                icon: "download"
                                iconSize: 18
                                color: Colors.m3.m3onSurfaceVariant
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = index
                            onClicked: {
                                list.currentIndex = index;
                                root.applyModel(delegateRoot.modelData);
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: delegateRoot.modelData
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.leftMargin: Padding.huge
                Layout.rightMargin: Padding.huge
                Layout.topMargin: Padding.small
                Layout.bottomMargin: Padding.normal
                implicitHeight: 40
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: Padding.normal

                    Symbol {
                        Layout.alignment: Qt.AlignVCenter
                        icon: "info"
                        iconSize: 16
                        color: Colors.m3.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: root.status
                        font: Fonts.request("main", "small")
                        color: Colors.m3.m3onSurfaceVariant
                        truncate: true
                    }
                }
            }
        }
    }
}
