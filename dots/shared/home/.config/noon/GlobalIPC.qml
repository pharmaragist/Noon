import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.common
import qs.common.utils
import qs.common.functions
import qs.common.widgets
import qs.services
import qs.data

NpcHandler {
    target: "global"

    //* reload — hot-reload shell in place.
    function spawn_app(app: string, payload: string): void {
        NoonUtils.spawnApp(app);
    }

    //* reload — hot-reload shell in place.
    function reload(): void {
        Quickshell.reload(true);
    }

    //* respawn — full shell restart via reload_shell.sh.
    function respawn(): void {
        NoonUtils.execDetached([Paths.scriptsDir + "/reload_shell.sh"]);
    }

    //* dino — open the dino easter-egg dialog.
    function dino(): void {
        NoonUtils.requestDialog("dino");
    }

    //* open_note <fileName> — open an existing note by file name.
    function open_note(fileName: string): void {
        NotesService.openNote(fileName);
    }

    //* note <content> — quick-capture a new note with given content.
    function note(content: string): void {
        NotesService.note(content);
    }

    //* toggle_screenshot — show/hide the screenshot overlay.
    function toggle_screenshot(): void {
        Globals.main.showScreenshot = !Globals.main.showScreenshot;
    }

    //* trigger_autostart_apps — run all user autoExecAppsList commands.
    function trigger_autostart_apps(): void {
        Mem.options.services.autoExecAppsList.forEach(cmd => {
            Quickshell.execDetached(["bash", "-c", cmd]);
        });
    }

    //* preview_file <type> <payload> — open path/URL in Look viewer.
    function preview_file(t: string, p: string): void {
        NoonUtils.spawnApp("Look", {
            "content": {
                "type": t,
                "payload": p
            }
        });
    }

    //* preview_url <url> — stream/preview a media URL via Beats.
    function preview_url(url: string): void {
        console.log(url);
        BeatsService.previewURL(url);
    }

    //* say <text> — speak text aloud via TTS.
    function say(text: string): void {
        if (!text)
            return;
        SpeechService.say(text);
    }

    //* thawb <link> — open thawb dialog for the given link.
    function thawb(link: string) {
        if (link)
            NoonUtils.requestDialog("thawb", link);
    }
    //* toggle_dormant_sphere — show/hide the dormant sphere overlay.
    function toggle_dormant_sphere() {
        Globals.showDormantShere = !Globals.showDormantShere;
    }
    //* toggle_dormant_state — flip deload (unload background UI).
    function toggle_dormant_state() {
        Globals.deload = !Globals.deload;
    }
    //* load — clear deload, restore full UI.
    function load() {
        Globals.deload = false;
    }
    //* deload — set deload, shed background UI to save resources.
    function deload() {
        Globals.deload = true;
    }
    //* toast <info> [state] — show a toast notification.
    function toast(info: string, state: string) {
        NoonUtils.toast({
            id: 0,
            content: info,
            status: state ?? ""
        });
    }
    //* inc_brightness — step screen brightness up.
    function inc_brightness() {
        BrightnessService.increaseBrightness();
    }
    //* dec_brightness — step screen brightness down.
    function dec_brightness() {
        BrightnessService.decreaseBrightness();
    }
    //* clear_clipboard — wipe clipboard history.
    function clear_clipboard() {
        ClipboardService.wipe();
    }
    //* refresh_appearance — re-derive theme from current wallpaper.
    function refresh_appearance() {
        WallpaperService.refreshTheme();
    }
    //* toggleLightMode — flip shell between light/dark mode.
    function toggleLightMode() {
        WallpaperService.toggleShellMode();
    }
    //* pick_accent — open accent color picker + toast confirm.
    function pick_accent() {
        WallpaperService.pickAccentColor();
        NoonUtils.toast({
            id: 1,
            content: "Color Changed",
            icon: "palette"
        });
    }
    //* pick_random_wall — apply a random wallpaper.
    function pick_random_wall() {
        WallpaperService.applyRandomWallpaper();
    }
    //* set_wall <path> — apply wallpaper at path + toast confirm.
    function set_wall(path: string) {
        WallpaperService.applyWallpaper(path);
        NoonUtils.toast({
            id: 2,
            content: "Wallpaper Changed",
            icon: "image"
        });
    }

    //* add_alarm <time> <name> — schedule a named wake alarm.
    function add_alarm(time: string, name: string) {
        TimerService.wake(time, name);
    }

    //* wake <message> — wake/flash shell with a message.
    function wake(message: string) {
        NoonUtils.wake(message);
    }

    //* lock — lock the session.
    function lock() {
        Globals.main.locked = true;
    }

    //* pause_all_players — pause every pausable MPRIS player.
    function pause_all_players(): void {
        for (const player of Mpris.players.values) {
            if (player.canPause)
                player.pause();
        }
    }

    //* dmenu_create <a|b|c> <callback> [icon] — build DMenu from |-list.
    function dmenu_create(list: string, callback: string, icon: string): void {
        const items = list.split('|').filter(item => item.trim() !== '');

        const preparedItems = items.map(item => {
            return {
                title: item.trim(),
                subtitle: "",
                icon: icon,
                action: callback
            };
        });

        Globals.main.dmenu.items = preparedItems;
        Globals.main.dmenu.action = callback;
        Ipc.call(["sidebar", "reveal", "DMenu"]);
    }

    //* toggle_playing — play/pause the active MPRIS player.
    function toggle_playing(): void {
        MprisController.togglePlaying();
    }

    //* previous_track — skip to previous track.
    function previous_track(): void {
        MprisController.previous();
    }

    //* next_track — skip to next track.
    function next_track(): void {
        MprisController.next();
    }

    //* volume_down — lower sink volume by 10%.
    function volume_down(): void {
        AudioService.sink.audio.volume -= 0.1;
    }

    //* volume_up — raise sink volume by 10%.
    function volume_up(): void {
        AudioService.sink.audio.volume += 0.1;
    }

    //* install_pkg <name> — install a system package by name.
    function install_pkg(name: string) {
        PackagesService.install(name);
    }
}
