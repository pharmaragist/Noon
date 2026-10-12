# Noon Plugins — Create & Publish

Plugins live in `~/.noon_plugins/<group>/<name>/` and hot-reload on change.
Groups: `sidebar`, `dock`, `beam`, `palettes`, `widgets`.
License: keep it GPLv3-compatible. If AI-generated, set `mentainer` to the model name.

## Layout

```
~/.noon_plugins/<group>/<name>/
├── manifest.json
└── main.qml          # entry (name it however the manifest says)
```

No nested subdirectories inside the plugin folder (breaks `qmldir` resolution).

## manifest.json

Shared fields:

```json
{
  "name": "sokoun",
  "pluginGroup": "sidebar",
  "mentainer": "your-name",
  "enabled": true,
  "icon": "equalizer",
  "entry": "@plugins/Ambients.qml",
  "singletons": []
}
```

`name` must match the folder name (case-insensitive). `entry` points at your root QML file.

Group extras:

- **sidebar** — `searchable`, `expandable`, `detachable`, `incubatable`, `stealth`, `shape`, `activeIcon`, `expandSize`. Root item contract: `property string searchQuery`, `property bool expanded`, `property bool detached`, signals `dismiss`, `searchFocusRequested`, `contentFocusRequested`.
- **dock** — `direction` (relative to existing dock apps).
- **beam** — prefix-driven command, no `main.qml`. Needs `prefix` (e.g. `"'"`), `placeholder`, `showHint`, plus JS-string `hinter`/`executor`:
  ```json
  {
    "name": "tldr",
    "pluginGroup": "beam",
    "prefix": "'",
    "placeholder": "Learn More",
    "hinter": "() => { shell('tldr \"$q\"'); return activeHint; }",
    "executor": "() => exec('wl-copy \"$q\"')"
  }
  ```
  Runtime: `cleanQuery` (input minus prefix), `activeHint` (R/W), `exec(cmd)` fire-and-forget, `shell(cmd, cb?)` with result in `activeHint`. `%q` = build-time query, `$q` = call-time (inside `exec`/`shell` only).
- **palettes** — no `manifest.json`/`main.qml`. Single `palette.json`: `base16` (base00–base0f), Material `colors` tokens, `palettes` tonal scales, each `{ dark, default, light } → { hex, red, green, blue, hex_stripped }`. Template: `~/.config/noon/assets/db/palettes/dracula.json`.

## QML rules

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common                  // Colors, Padding, Rounding, Fonts, Animations, Sizes
import qs.common.widgets          // Styled* components, Symbol, RippleButton
import qs.common.utils            // PluginFileView, ConfigFileView
import qs.common.functions        // TextUtils, ColorUtils, FileUtils
import qs.services                // PaletteService, WallpaperService, PluginsManager, ...
```

- Style: `Colors.*` layers, `Padding.*` spacing, `Rounding.*` radii, `Fonts.request("main", "small")`, `Symbol` + Material icon names.
- Persist with `PluginFileView { fileName: "..." }` → `~/.local/state/noon/plugins/<fileName>.json`, reactive auto-save. Never write `Mem.*` (read-only).
- Prefer existing `qs.common.widgets` over raw QtQuick. Deletion over addition.

## Test locally

1. Copy the folder to `~/.noon_plugins/<group>/<name>/` — the shell picks it up (hot reload in dev mode).
2. Zip it (`<name>/manifest.json` at zip root, max depth 2) and validate:
   ```
   ~/.config/noon/scripts/plugins_helper.sh install <name>.zip
   ```
   Same check the Store runs. Remove with `plugins_helper.sh remove <group> <name>`.

## Publish to the hub

Hub repo: `pharmaragist/Noon-Plugins`. Publishing = pull request adding four things:

1. Source: `<group>/<name>/` (manifest + QML, same layout as above).
2. Zip: `zip/<group>/<name>.zip` — lowercase filename, plugin folder at archive root.
3. Thumbnail (optional, recommended): `assets/thumbs/<group>/<name>.png`. Missing thumbs fall back to the manifest `icon` in the Store; nothing breaks.
4. Index entry in `plugins.json`:
   ```json
   {
     "id": "sokoun",
     "name": "Sokoun",
     "group": "sidebar",
     "description": "Ambient sounds mixer",
     "version": "1.2.0",
     "maintainer": "you",
     "icon": "equalizer",
     "preview": "https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/main/assets/thumbs/sidebar/sokoun.png",
     "download": "https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/main/zip/sidebar/sokoun.zip"
   }
   ```
   `id` should equal the manifest `name`. `download` must be the raw zip URL. `preview` may be omitted.

Users get it via the Store app (plugins rail) or `PluginsManager.installFromHub(id)` once their `~/.noon/user/store-providers.json` points at the raw `plugins.json`:
```json
{"static": [{"id": "noon-plugins", "name": "Noon Plugins", "index": "https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/main/plugins.json"}]}
```
