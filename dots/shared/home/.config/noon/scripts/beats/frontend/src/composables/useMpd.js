import { reactive, ref, shallowRef } from 'vue'

const STORAGE_KEY = 'beats-player'

class BeatsClient {
  ws = null
  player = null
  _reconnectTimer = null

  connected = ref(false)
  status = reactive({})
  currentSong = shallowRef({})
  queue = ref([])

  onConnected = null
  onDisconnected = null

  connect(player) {
    if (this.ws) return
    this.player = player
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ player }))
    this.ws = new WebSocket(`ws://${location.host}/${player}`)
    this.ws.onopen = () => {
      this.connected.value = true
      this.onConnected?.()
    }
    this.ws.onmessage = (e) => this._onMsg(e.data)
    this.ws.onclose = () => {
      this.connected.value = false
      this.ws = null
      this.onDisconnected?.()
      if (this.player) {
        this._reconnectTimer = setTimeout(() => this.connect(this.player), 3000)
      }
    }
  }

  restore() {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return false
    try {
      const { player } = JSON.parse(raw)
      if (player) {
        this.connect(player)
        return true
      }
    } catch (_) {}
    return false
  }

  disconnect() {
    clearTimeout(this._reconnectTimer)
    if (this.ws) {
      this.ws.onclose = null
      this.ws.close()
      this.ws = null
    }
    this.connected.value = false
    this.player = null
    this.queue.value = []
    this.currentSong.value = {}
    for (const k of Object.keys(this.status)) delete this.status[k]
    localStorage.removeItem(STORAGE_KEY)
    this.onDisconnected?.()
  }

  _onMsg(raw) {
    let msg
    try {
      msg = JSON.parse(raw)
    } catch (_) {
      return
    }
    if (msg.type === 'status') {
      const { type, ...fields } = msg
      Object.assign(this.status, fields)
      this.currentSong.value = {
        title: fields.title,
        artist: fields.artist,
        album: fields.album,
        file: fields.file,
        duration: fields.duration,
      }
    } else if (msg.type === 'queue') {
      this.queue.value = msg.queue
    }
  }

  _send(cmd, a, b) {
    if (this.ws) this.ws.send(JSON.stringify({ cmd, a, b }))
  }

  toggle() {
    this._send(this.status.state === 'play' ? 'pause' : 'resume')
  }

  pause() {
    this._send('pause')
  }

  resume() {
    this._send('resume')
  }

  next() {
    this._send('next')
  }

  prev() {
    this._send('prev')
  }

  stop() {
    this._send('stop')
  }

  seekTo(pos) {
    this._send('seekTo', pos)
  }

  seekBy(delta) {
    this._send('seekBy', delta)
  }

  setVolume(v) {
    this._send('setVolume', Math.max(0, Math.min(100, Math.round(v))))
  }

  setRepeat(v) {
    this._send('setRepeat', !!v)
  }

  playIndex(i) {
    this._send('playIndex', i)
  }

  playByName(name) {
    this._send('playByName', name)
  }

  playFiles(paths) {
    this._send('playFiles', paths)
  }

  queueMove(from, to) {
    this._send('queueMove', from, to)
  }

  coverUrl(rel) {
    return rel ? '/api/covers/' + rel : ''
  }
}

const beats = new BeatsClient()
export function useMpd() {
  return beats
}
