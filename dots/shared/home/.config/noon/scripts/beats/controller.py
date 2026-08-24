from .player import MpvPlayer


class Controller:
    """Native JSON command layer over the embedded MpvPlayer.

    Used by the frontend WebSocket and the HTTP control endpoints (CLI
    one-shots). Commands return a snapshot dict, a queue list, or {"ok": true}.
    """

    def __init__(self, player: MpvPlayer):
        self.player = player
        # cmd -> callable(a, b); most commands ignore b
        self._commands = {
            "playByName": lambda a, b: player.play_by_name(a or ""),
            "playFile": lambda a, b: player.play_file(a or ""),
            "playUrl": lambda a, b: player.play_url(a or ""),
            "playFiles": lambda a, b: player.play_files(
                a if isinstance(a, list) else [a]
            ),
            "buildPlaylist": lambda a, b: player.build_playlist(a or ""),
            "playPause": lambda a, b: player.play_pause(),
            "pause": lambda a, b: player.pause(True),
            "resume": lambda a, b: player.pause(False),
            "next": lambda a, b: player.next(),
            "prev": lambda a, b: player.prev(),
            "stop": lambda a, b: player.stop(),
            "seekBy": lambda a, b: player.seek(float(a or 0), relative=True),
            "seekTo": lambda a, b: player.seek(float(a or 0), relative=False),
            "setVolume": lambda a, b: player.set_volume(int(a or 0)),
            "setRepeat": lambda a, b: player.set_repeat(a),
            "playIndex": lambda a, b: player.play_index(int(a or 0)),
            "queueAdd": lambda a, b: player.queue_add(a or ""),
            "queueRemove": lambda a, b: player.queue_remove(int(a or 0)),
            "queueMove": lambda a, b: player.queue_move(int(a or 0), int(b or 0)),
            "queueClear": lambda a, b: player.queue_clear(),
            "refreshConfig": lambda a, b: player.refresh_config(),
        }

    def handle(self, cmd: str, a=None, b=None):
        if cmd == "status":
            return self.player.snapshot()
        if cmd == "queue":
            return self.player.get_queue()
        fn = self._commands.get(cmd)
        if fn is None:
            raise ValueError(f"unknown command: {cmd}")
        fn(a, b)
        return {"ok": True}
