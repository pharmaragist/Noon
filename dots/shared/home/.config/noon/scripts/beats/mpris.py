import asyncio
import hashlib

from dbus_next import Variant
from dbus_next.aio import MessageBus
from dbus_next.service import (
    PropertyAccess,
    ServiceInterface,
    dbus_property,
    method,
    signal,
)

from .player import MpvPlayer

BUS_NAME = "org.mpris.MediaPlayer2.noon"
PATH = "/org/mpris/MediaPlayer2"
PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"
SYNC_INTERVAL = 0.25
_MP_STATUS = {"play": "Playing", "pause": "Paused", "stop": "Stopped"}


class MprisRoot(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2")

    @dbus_property(access=PropertyAccess.READ)
    def CanQuit(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def CanRaise(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def HasTrackList(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> "s":
        return "beats"

    @dbus_property(access=PropertyAccess.READ)
    def DesktopEntry(self) -> "s":
        return "beats"

    @dbus_property(access=PropertyAccess.READ)
    def SupportedUriSchemes(self) -> "as":
        return ["file", "http", "https"]

    @dbus_property(access=PropertyAccess.READ)
    def SupportedMimeTypes(self) -> "as":
        return []

    @method()
    def Raise(self):
        pass

    @method()
    def Quit(self):
        pass


class MprisPlayer(ServiceInterface):
    def __init__(self, player: MpvPlayer, cover_url=None):
        super().__init__(PLAYER_IFACE)
        self._player = player
        self._cover_url = cover_url
        self._snap = {}

    def _refresh(self):
        self._snap = self._player.snapshot()

    def _meta(self) -> dict:
        s = self._snap
        file_rel = s.get("file", "")
        if not file_rel:
            return {}
        meta = {}
        if s.get("title"):
            meta["xesam:title"] = Variant("s", s["title"])
        if s.get("artist"):
            meta["xesam:artist"] = Variant("as", [s["artist"]])
        if s.get("album"):
            meta["xesam:album"] = Variant("s", s["album"])
        if s.get("duration"):
            meta["mpris:length"] = Variant("x", int(s["duration"] * 1_000_000))
        meta["mpris:trackid"] = Variant(
            "o", "/org/mpris/MediaPlayer2/Track/" + hashlib.sha1(file_rel.encode()).hexdigest()
        )
        if not file_rel.startswith(("http://", "https://")):
            meta["xesam:url"] = Variant("s", f"file://{file_rel}")
        if self._cover_url:
            url = self._cover_url(file_rel)
            if url:
                meta["mpris:artUrl"] = Variant("s", url)
        return meta

    def _loop_status(self) -> str:
        if self._snap.get("loop_track"):
            return "Track"
        return "Playlist" if self._snap.get("repeat") else "None"

    # ── read-only properties ──

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> "s":
        return _MP_STATUS.get(self._snap.get("state"), "Stopped")

    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> "a{sv}":
        return self._meta()

    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> "x":
        return int(self._snap.get("position", 0) * 1_000_000)

    @dbus_property(access=PropertyAccess.READ)
    def MinimumRate(self) -> "d":
        return 0.5

    @dbus_property(access=PropertyAccess.READ)
    def MaximumRate(self) -> "d":
        return 2.0

    @dbus_property(access=PropertyAccess.READ)
    def CanGoNext(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanGoPrevious(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanPause(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanSeek(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> "b":
        return True

    # ── read-write properties ──

    @dbus_property(access=PropertyAccess.READWRITE)
    def LoopStatus(self) -> "s":
        return self._loop_status()

    @LoopStatus.setter
    def LoopStatus(self, value: "s"):
        self._player.set_loop_track(value == "Track")
        self._player.set_repeat(value == "Playlist")
        self._refresh()

    @dbus_property(access=PropertyAccess.READWRITE)
    def Rate(self) -> "d":
        return self._snap.get("rate", 1.0)

    @Rate.setter
    def Rate(self, value: "d"):
        self._player.set_rate(float(value))
        self._refresh()

    @dbus_property(access=PropertyAccess.READWRITE)
    def Shuffle(self) -> "b":
        return self._snap.get("random", False)

    @Shuffle.setter
    def Shuffle(self, value: "b"):
        self._player.set_random(bool(value))
        self._refresh()

    @dbus_property(access=PropertyAccess.READWRITE)
    def Volume(self) -> "d":
        return self._snap.get("volume", 0) / 100.0

    @Volume.setter
    def Volume(self, value: "d"):
        self._player.set_volume(int(round(value * 100)))
        self._refresh()

    # ── methods ──

    @signal()
    def Seeked(self, position: "x") -> "x":
        return position

    @method()
    def Next(self):
        self._player.next()

    @method()
    def Previous(self):
        self._player.prev()

    @method()
    def Pause(self):
        self._player.pause(True)

    @method()
    def PlayPause(self):
        self._player.play_pause()

    @method()
    def Stop(self):
        self._player.stop()

    @method()
    def Play(self):
        self._player.play()

    @method()
    def Seek(self, offset: "x"):
        self._player.seek(offset / 1_000_000, relative=True)
        self._emit_seeked()

    @method()
    def SetPosition(self, playlist_id: "o", position: "x"):
        self._player.seek(position / 1_000_000, relative=False)
        self._emit_seeked()

    @method()
    def OpenUri(self, uri: "s"):
        if uri.startswith("file://"):
            from urllib.parse import unquote, urlparse
            uri = unquote(urlparse(uri).path)
        self._player.play_file(uri)

    def _emit_seeked(self):
        self._refresh()
        self.Seeked(int(self._snap.get("position", 0) * 1_000_000))

    def emit(self, changed: dict):
        self.emit_properties_changed(changed, [])


class MprisService:
    def __init__(self, player: MpvPlayer, cover_url=None):
        self.player = player
        self._root = MprisRoot()
        self._player_iface = MprisPlayer(player, cover_url)
        self._bus = MessageBus()

    async def start(self):
        self._loop = asyncio.get_running_loop()
        await self._bus.connect()
        self._bus.export(PATH, self._root)
        self._bus.export(PATH, self._player_iface)
        try:
            await self._bus.request_name(BUS_NAME)
        except Exception:
            print(f"  MPRIS name {BUS_NAME} already taken; continuing.", flush=True)
        self.player.seek_hook = lambda: self._loop.call_soon_threadsafe(self._player_iface._emit_seeked)
        self._loop.create_task(self._sync())

    async def _sync(self):
        iface = self._player_iface
        last = {}
        while True:
            try:
                iface._refresh()
                s = iface._snap
                changed = {
                    "PlaybackStatus": _MP_STATUS.get(s.get("state"), "Stopped"),
                    "LoopStatus": iface._loop_status(),
                    "Shuffle": s.get("random", False),
                    "Rate": round(s.get("rate", 1.0), 3),
                    "Metadata": iface._meta(),
                    "Volume": round(s.get("volume", 0) / 100.0, 3),
                }
                if s.get("state") != "stop":
                    changed["Position"] = int(s.get("position", 0) * 1_000_000)
                if changed != last:
                    last = changed
                    iface.emit(changed)
            except Exception:
                pass
            await asyncio.sleep(SYNC_INTERVAL)
