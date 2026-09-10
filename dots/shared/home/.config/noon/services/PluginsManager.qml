pragma Singleton
import QtQuick
import Noon.Utils
import Quickshell
import Quickshell.Io
import Qt.labs.platform
import qs.common
import qs.common.utils
import qs.common.functions
import qs.services
import qs.data

Singleton {
    id: root

    property string selectedLocation: ""
    readonly property bool developmentMode: true
    readonly property bool enablePlugins: true
    readonly property list<string> plugins: allPlugins.map(plugin => plugin.group)

    // available from the static hub index (see store-providers.json)
    property var hubPlugins: []
    property string hubProvider: ""


    function refreshHub() {
        StoreService.ensureProviders(list => {
            const hubs = (list || []).filter(p => p && p.static);
            if (!hubs.length) {
                root.hubPlugins = [];
                return;
            }
            root.hubProvider = hubs[0].id;
            StoreService.contentSearch(root.hubProvider, "", "", [], "", 0, 100, (res, err) => {
                root.hubPlugins = !err && res && Array.isArray(res.items) ? res.items : [];
            });
        });
    }

    function installFromHub(id) {
        const hit = hubPlugins.find(p => p && (p.id === id || p.name === id));
        if (!hit || !hubProvider)
            return;
        StoreService.contentInstall(hubProvider, hit.id, "noon-plugin", hit.typeId + "/" + hit.id, (res, err) => {
            if (!err)
                refreshAll();
        });
    }

    readonly property alias sidebarPlugins: sidebar?.plugins
    readonly property alias dockPlugins: dock?.plugins
    readonly property alias beamPlugins: beam?.plugins
    readonly property alias desktopWidgetsPlugins: desktopWidgets?.plugins

    readonly property var allPlugins: [
        {
            group: "sidebar",
            data: PluginsManager.sidebarPlugins
        },
        {
            group: "dock",
            data: PluginsManager.dockPlugins
        },
        {
            group: "beam",
            data: PluginsManager.beamPlugins
        },
        {
            group: "widgets",
            data: PluginsManager.desktopWidgetsPlugins
        }
    ]

    PluginExtractor {
        id: dock
        group: "dock"
    }

    PluginExtractor {
        id: beam
        group: "beam"
    }

    PluginExtractor {
        id: sidebar
        group: "sidebar"
        onPluginsChanged: SidebarData.rebuildAll()
    }

    PluginExtractor {
        id: desktopWidgets
        group: "widgets"
    }

    function select() {
        selectionDialog.open();
    }

    function selectAndInstall() {
        selectionDialog.open();
        selectionDialog.onAccepted.connect(() => {
            install();
        });
    }

    function disable(group, name) {
        actionProc.command = [Paths.scriptsDir + "/plugins_helper.sh", "disable", group, name];
        actionProc.running = true;
    }
    function enable(group, name) {
        actionProc.command = [Paths.scriptsDir + "/plugins_helper.sh", "enable", group, name];
        actionProc.running = true;
    }
    function install(zip = root.selectedLocation) {
        actionProc.command = [Paths.scriptsDir + "/plugins_helper.sh", "install", zip];
        actionProc.running = true;
    }
    function remove(group, name) {
        actionProc.command = [Paths.scriptsDir + "/plugins_helper.sh", "remove", group, name];
        actionProc.running = true;
    }

    function action(plugin, action) {
        if (!plugin)
            return;
        actionProc.command = [Paths.scriptsDir + "/plugins_helper.sh", action, plugin];
        actionProc.running = true;
    }

    QmlCrawler {
        enabled: root.developmentMode
        folder: Qt.resolvedUrl(Paths.plugins.main)
        onContentsChanged: Quickshell.reload(true)
    }

    FileDialog {
        id: selectionDialog
        title: "Select Plugin Dir"
        nameFilters: ["*.zip *.tar.gz *.tar", "All files (*)"]
        onAccepted: {
            root.selectedLocation = Paths.methods.trim(currentFile);
            Ipc.call(["sidebar", "reveal", "Plugins"]);
        }
    }

    function refreshAll() {
        dock.refresh();
        sidebar.refresh();
        beam.refresh();
    }

    Component.onCompleted: refreshHub()

    Process {
        id: actionProc
        onStarted: console.log(command.join())
        onExited: refreshAll()
    }

    NpcHandler {
        target: "plugins"
        function reload(): void {
            root.refreshAll();
        }
    }
}
