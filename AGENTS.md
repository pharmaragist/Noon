# AGENTS.md — Noon coding style

Coding style and conventions for Noon (Quickshell/QML shell at `~/.config/noon`). This covers the shell source, not plugins. GPLv3-compatible code.

## Formatting

Enforced via `~/.config/noon/qmlformat.ini`:

- 4-space indent, no tabs.
- Unix newlines.
- Max column width 110.
- ObjectsSpacing enabled (`qmlformat` with the repo config).

## Imports

Allowed QML imports:

```
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtQuick.Shapes
import QtMultimedia
import Qt.labs.platform
import Qt.labs.folderlistmodel

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.common.functions
import qs.services
```

## Design tokens (scaled by user preference)

- Spacing via `Padding.*` (`tiny: 2` … `massive: 20`).
- Corner radii via `Rounding.*` (`verytiny: 2` … `silly: 32`, `full: 999`).
- Colors via `Colors.*`: `Colors.t(c, amt)` to transparentize, layer system `colLayer0`–`colLayer4` (with `*Hover`/`*Active`/`colOnLayer*`), M3 palette at `Colors.m3.*` (from `PaletteService.colors`).
- Typography via `Fonts.request(name, size, props)`; default `Fonts.request("main", "small")` (16px).
- Motion via `Animations.*` durations (`verysmall: 100` … `massive: 1500`) and curves (`standard`, `standardAccel`, `standardDecel`, `emphasized`) applied as `Easing.BezierSpline` / `easing.bezierCurve`.

## Prefer existing components over raw QML

Use `qs.common.widgets` (in `common/widgets/`) before reaching for raw QtQuick:

- Layout: `RLayout`, `CLayout`, `Spacer`, `Separator`.
- Primitives: `StyledRect`, `StyledText`, `StyledIconImage`, `StyledDropShadow`, `StyledBlurEffect`.
- Inputs: `StyledTextField`, `StyledSlider`, `StyledSwitch`, `StyledComboBox`, `StyledSpinBox`, `StyledCheckbox`, `StyledRadioButton`, `StyledTextArea`.
- Buttons: `RippleButton` (props: `toggled`, `buttonText`, `colBackground`/`Hover`/`Toggled`, `downAction`/`releaseAction`/`altAction`), `FloatingActionButton`, `MenuButton`, `GroupButton`, `SegmentedButtonGroup`, toolbar/tab buttons.
- Data/containers: `StyledListView`, `StyledGridView`, `StyledFlickable`, `StyledSwipeView`, `StyledStackView`, `StyledLoader` (`shown`, `binds`, `reload()`), `StyledPopup`, `StyledMenu`, `StyledMenuItem`, `StyledToolTip`, `StyledScrollBar`, `FocusHandler`, `HoverHandler`, dialogs (`WindowDialog`, `CenterDialog`, `SidebarDialog`, `BottomDialog`).
- Icons: `Symbol` (Material Symbols, props `icon`, `iconSize`, `fill` 0–1). Shapes: `MaterialShape`, `MaterialCookie` (`sides`, `implicitSize`, `color`).

## Utilities

- Helper functions via `.methods`: `Colors.methods` → `ColorUtils` (`transparentize`, `mix`, `applyAlpha`, `getReadableColOn`, `isValidColor`); `Fonts.methods` → `TextUtils` (`capitalizeFirstLetter`, `format`, `friendlyTimeForSeconds`, `toTitleCase`, `wordWrap`, `getDomain`); `Directories.methods` → `FileUtils` (`trim`, `fileExists`, `readFile`, `mkdir`, `copyItem`, `moveItem`).
- Services from `qs.services` (in `services/`): `PaletteService.colors`, `WallpaperService`, `AudioService`, `MprisController`, `Notifications`, `ClipboardService`, `PluginsManager`, `NetworkService`, `BluetoothService`, `BatteryService`, `CalendarService`, `DateTimeService`, `WeatherService`, `HyprlandService`, `TimerService`, `ResourcesService`, `SysInfoService`, `EmojisService`, `SpeechService`, and more.
- `NoonUtils.*`: `toast(...)`, `notify(content, title)`, `playSound(sound)`, `execDetached(command, log?)`, `iconPath(icon, fallback)`, `openFile(path)`, `deleteFile(path)`, `setHyprKey(key, value)`, `requestDialog(dialog, data)`, `callIpc(request)`, `inlineTimer(callback, delay)`.
- Persistence: `PluginFileView { id; fileName }` → reactive JSON auto-persisted at `~/.local/state/noon/plugins/<fileName>.json`. Extends `ConfigFileView` (`fileName`, `data`, `path`, `contentChanged`).

## Read-only state

- `Mem.*` is read-only: `Mem.options`, `Mem.states`, `Mem.looks` (`mode`, `isBright`), `Mem.hypr`, `Mem.ready`. Never write to it; use `PluginFileView` for persistent data.

## Known rules of thumb

- When unsure about a component or service, check the real source code by fuzzy searching
- Deletion over addition, boring over clever, fewest files possible.
