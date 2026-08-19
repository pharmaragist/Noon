from .player import MpvPlayer


class Controller:
    """Native JSON command layer over the embedded MpvPlayer.

    Used by the frontend WebSocket and the HTTP control endpoints (CLI
    one-shots). Commands return a snapshot dict, a queue list, or {"ok": true}.
    """

    def __init__(self, player: MpvPlayer):
        self.player = player

    def handle(self, cmd: str, a=None, b=None):
        p = self.player
        if cmd == "status":
            return p.snapshot()
        if cmd == "queue":
            return p.get_queue()
        if cmd == "playByName":
            p.play_by_name(a or "")
        elif cmd == "playFiles":
            p.play_files(a if isinstance(a, list) else [a])
        elif cmd == "playFile":
            p.play_file(a or "")
        elif cmd == "playUrl":
            p.play_url(a or "")
        elif cmd == "buildPlaylist":
            p.build_playlist(a or "")
        elif cmd == "playPause":
            p.play_pause()
        elif cmd == "pause":
            p.pause(True)
        elif cmd == "resume":
            p.pause(False)
        elif cmd == "next":
            p.next()
        elif cmd == "prev":
            p.prev()
        elif cmd == "stop":
            p.stop()
        elif cmd == "seekBy":
            p.seek(float(a or 0), relative=True)
        elif cmd == "seekTo":
            p.seek(float(a or 0), relative=False)
        elif cmd == "setVolume":
            p.set_volume(int(a or 0))
        elif cmd == "setRepeat":
            p.set_repeat(a)
        elif cmd == "playIndex":
            p.play_index(int(a or 0))
        elif cmd == "queueAdd":
            p.queue_add(a or "")
        elif cmd == "queueRemove":
            p.queue_remove(int(a or 0))
        elif cmd == "queueMove":
            p.queue_move(int(a or 0), int(b or 0))
        elif cmd == "queueClear":
            p.queue_clear()
        elif cmd == "refreshConfig":
            p.refresh_config()
        else:
            raise ValueError(f"unknown command: {cmd}")
        return {"ok": True}
