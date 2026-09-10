pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils

Singleton {
    id: root
    property var pending: ({})

    // single alias into the persisted adapter; every cache.x assign writes to disk
    property alias cache: cacheView.data

    // ponytail: grid/dialog only need these; descriptions bloat the state file
    function stripItem(it) {
        return {
            id: it ? it.id : "",
            name: it ? it.name : "",
            icon: it ? it.icon || "" : "",
            installed: !!(it && it.installed),
            previews: it ? it.previews || [] : [],
            downloadsCount: it ? it.downloadsCount || 0 : 0,
            typeId: it ? it.typeId || "" : ""
        };
    }

    function send(m, p, cb) {
        const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
        if (cb)
            pending[id] = cb;
        proc.write(JSON.stringify({
            id,
            method: m,
            params: p
        }) + "\n");
        return id;
    }

    function providersList(cb) {
        send("providers.list", {}, cb);
    }

    function categoriesList(provider, cb) {
        send("categories.list", {
            provider
        }, cb);
    }

    function contentSearch(provider, query, xdgType, cats, sort, page, pageSize, cb) {
        send("content.search", {
            provider,
            query: query || "",
            xdgType: xdgType || "",
            categoryIds: cats || [],
            sort: sort || "",
            page: page || 0,
            pageSize: pageSize || 30
        }, cb);
    }

    function contentGet(provider, id, cb) {
        send("content.get", {
            provider,
            contentId: id
        }, cb);
    }

    function contentPreview(provider, id, src, size, cb) {
        if (typeof src === "function") {
            cb = src;
            src = "";
            size = "";
        } else if (typeof size === "function") {
            cb = size;
            size = "";
        }
        const key = provider + ":" + id + ":" + (size || "");
        if (cache.previewCache[key]) {
            if (cb)
                cb({
                    path: cache.previewCache[key]
                }, null);
            return key;
        }
        const p = {
            provider,
            contentId: id
        };
        if (Array.isArray(src))
            p.previews = src;
        else if (src)
            p.url = src;
        if (size)
            p.size = size;
        return send("content.previewImage", p, (res, err) => {
            if (!err && res && res.path) {
                const pc = Object.assign({}, cache.previewCache);
                pc[key] = res.path;
                cache.previewCache = pc;
            }
            if (cb)
                cb(res, err);
        });
    }

    function contentDownload(provider, id, item, cb) {
        const p = {
            provider,
            contentId: id
        };
        if (item != null)
            p.downloadItemId = item;
        send("content.download", p, cb);
    }

    function contentInstall(provider, id, kind, name, cb) {
        if (typeof name === "function") {
            cb = name;
            name = "";
        }
        const p = {
            provider,
            contentId: id,
            kind
        };
        if (name)
            p.name = name;
        send("content.install", p, cb);
    }

    // transient (never persisted): one active install, rest queued
    property var dlQueue: []
    property var dlActive: null

    function enqueueDownload(provider, contentId, kind, name, cb) {
        if ((dlActive && dlActive.provider === provider && dlActive.contentId === contentId)
            || dlQueue.some(j => j.provider === provider && j.contentId === contentId))
            return false;
        dlQueue = dlQueue.concat([{
            provider, contentId, kind, name: name || contentId, cb: cb || null
        }]);
        pumpQueue();
        return true;
    }

    function pumpQueue() {
        if (dlActive || !dlQueue.length)
            return;
        const job = dlQueue[0];
        dlQueue = dlQueue.slice(1);
        const p = {
            provider: job.provider,
            contentId: job.contentId,
            kind: job.kind
        };
        if (job.kind === "noon-plugin")
            p.name = job.name;
        const rpcId = send("content.install", p, (res, err) => {
            dlActive = null;
            if (job.cb)
                job.cb(res, err);
            pumpQueue();
        });
        dlActive = {
            provider: job.provider,
            contentId: job.contentId,
            kind: job.kind,
            name: job.name,
            rpcId: rpcId,
            phase: "starting",
            received: 0,
            total: 0,
            progress: 0
        };
    }

    function catsFor(provider) {
        return cache.catsByProvider[provider] || [];
    }

    function groupIcon(g) {
        switch (g) {
        case "sidebar":
            return "view_sidebar";
        case "dock":
            return "dock";
        case "beam":
            return "terminal";
        case "widgets":
            return "widgets";
        case "palettes":
            return "palette";
        default:
            return "extension";
        }
    }

    function xdgIcon(x) {
        if (!x)
            return "";
        if (x === "icons")
            return "emoji_symbols";
        if (x === "cursors")
            return "arrow_selector_tool";
        if (x.indexOf("wallpaper") !== -1)
            return "photo";
        if (x.indexOf("plasma") !== -1 || x.indexOf("desktoptheme") !== -1 || x.indexOf("look_and_feel") !== -1)
            return "dashboard";
        return "category";
    }

    function catIcon(c) {
        const x = c && c.xdgType ? xdgIcon(c.xdgType) : "";
        if (x)
            return x;
        if (c && c.id)
            return groupIcon(c.id);
        return "category";
    }

    function chipModel(provider, xdg) {
        const all = catsFor(provider);
        const list = xdg ? all.filter(c => c && c.xdgType === xdg) : all.filter(c => c && !c.parentId);
        return list.map(c => ({
            id: c.id, name: c.name, icon: catIcon(c)
        }));
    }

    function ensureProviders(cb) {
        if (cache.providers.length) {
            if (cb)
                cb(cache.providers, null);
            return;
        }
        providersList((res, err) => {
            if (!err)
                cache.providers = Array.isArray(res) ? res : res && Array.isArray(res.providers) ? res.providers : [];
            if (cb)
                cb(cache.providers, err || null);
        });
    }

    function ensureCategories(provider, cb) {
        if (cache.catsByProvider[provider]) {
            if (cb)
                cb(cache.catsByProvider[provider], null);
            return;
        }
        categoriesList(provider, (res, err) => {
            if (!err) {
                const c = Object.assign({}, cache.catsByProvider);
                c[provider] = Array.isArray(res) ? res : res && Array.isArray(res.categories) ? res.categories : [];
                cache.catsByProvider = c;
            }
            if (cb)
                cb(catsFor(provider), err || null);
        });
    }

    function markInstalled(id) {
        const fix = list => list.map(i => (i && i.id === id) ? Object.assign({}, i, {
            installed: true
        }) : i);
        cache.items = fix(cache.items);
        const sc = Object.assign({}, cache.searchCache);
        let touched = false;
        for (const k in sc) {
            if (sc[k] && Array.isArray(sc[k].items) && sc[k].items.some(i => i && i.id === id)) {
                sc[k] = {
                    items: fix(sc[k].items),
                    hasMore: sc[k].hasMore
                };
                touched = true;
            }
        }
        if (touched)
            cache.searchCache = sc;
    }

    function searchKeyFor(provider, query, xdg, cats, sort) {        return [provider, query || "", xdg || "", (cats || []).join(","), sort || ""].join("|");
    }

    function ensureSearch(o, append, cb) {
        const key = searchKeyFor(o.provider, o.query, o.xdgType, o.categoryIds, o.sort);
        const pg = append ? cache.page + 1 : 0;
        if (!append && cache.searchCache[key]) {
            const hit = cache.searchCache[key];
            cache.items = hit.items;
            cache.hasMore = hit.hasMore;
            cache.page = 0;
            cache.searchKey = key;
            if (cb)
                cb({
                    items: cache.items,
                    hasMore: cache.hasMore
                }, null);
            return;
        }
        contentSearch(o.provider, o.query, o.xdgType, o.categoryIds, o.sort, pg, o.pageSize || 30, (res, err) => {
            if (!err && res) {
                const raw = Array.isArray(res.items) ? res.items : [];
                const fresh = raw.map(stripItem);
                cache.items = append && key === cache.searchKey ? cache.items.concat(fresh) : fresh;
                cache.hasMore = !!res.hasMore;
                cache.page = pg;
                cache.searchKey = key;
                if (pg === 0) {
                    const sc = Object.assign({}, cache.searchCache);
                    sc[key] = {
                        items: cache.items,
                        hasMore: cache.hasMore
                    };
                    const ks = Object.keys(sc);
                    if (ks.length > 20)
                        delete sc[ks[0]];
                    cache.searchCache = sc;
                }
            }
            if (cb)
                cb(err ? null : {
                    items: cache.items,
                    hasMore: cache.hasMore
                }, err || null);
        });
    }

    function handleLine(d) {
        let m;
        try {
            m = JSON.parse(d);
        } catch (e) {
            return;
        }
        if (m.event === "progress") {
            if (dlActive && String(m.id) === String(dlActive.rpcId)) {
                const d = m.data || {};
                const total = d.totalBytes || 0;
                const recv = d.receivedBytes || 0;
                dlActive = Object.assign({}, dlActive, {
                    phase: d.phase || dlActive.phase,
                    received: recv,
                    total: total,
                    progress: total > 0 ? Math.min(1, recv / total) : (d.phase === "installing" ? 1 : 0)
                });
            }
            return;
        }
        const cb = pending[m.id];
        if (!cb)
            return;
        delete pending[m.id];
        if (m.error)
            cb(null, m.error);
        else
            cb(m.result, null);
    }

    Process {
        id: proc
        running: true
        stdinEnabled: true
        command: [Paths.scriptsDir + "/go/store/store-service"]
        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }
    }
     ConfigFileView {
        id: cacheView
        state: false
        parentDir: "user/"
        fileName: "store-cache"
        JsonAdapter {
            property var previewCache: ({})
            property var providers: []
            property var catsByProvider: ({})
            property var items: []
            property bool hasMore: false
            property int page: 0
            property string searchKey: ""
            property var searchCache: ({})
        }
    }
}
