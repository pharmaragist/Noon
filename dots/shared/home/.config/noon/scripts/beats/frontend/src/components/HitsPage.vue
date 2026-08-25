<template>
  <div class="hits">
    <div class="lib-toolbar">
      <div class="search-wrap">
        <span class="icon search-icon">search</span>
        <input
          class="search-input" type="text" placeholder="Search YouTube Music…"
          v-model="query" @keydown.enter="doSearch"
        />
      </div>
    </div>

    <div class="lib-tabs">
      <button
        v-for="f in filters" :key="f.kind"
        class="tab-btn"
        :class="{ active: source === f.kind }"
        @click="setSource(f.kind)"
      >{{ f.label }}</button>
    </div>

    <div v-if="busy && !items.length" class="loading">Fetching…</div>
    <div v-else-if="!items.length" class="empty">Nothing here yet</div>

    <div v-else class="grid">
      <button
        v-for="(t, i) in items" :key="(t.videoId || t.url || '') + i"
        class="hit-card" @click="play(t)"
      >
        <div class="art">
          <img
            v-if="t.thumbnail && !t._err" :src="t.thumbnail" loading="lazy"
            @error="t._err = true"
          />
          <div v-else class="art-fallback"><span class="icon">music_note</span></div>
          <div class="art-play"><span class="icon">play_arrow</span></div>
        </div>
        <div class="card-title">{{ t.title }}</div>
        <div class="card-artist">{{ t.artist }}</div>
      </button>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useMpd } from '../composables/useMpd.js'
import { useHits } from '../composables/useHits.js'

const mpd = useMpd()

const { query, items, source, busy, loadStored, setSource, doSearch, loadMore } = useHits()

const filters = [
  { kind: 'recommend', label: 'For You' },
  { kind: 'discover', label: 'Discover' },
  { kind: 'search', label: 'Search' },
]

function play(t) {
  mpd.playUrl(t.url)
}

onMounted(() => {
  loadStored()
})
</script>

<style scoped>
.hits {
  animation: hitsFade 400ms ease both;
  width: 100%;
}

@keyframes hitsFade {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}

.lib-toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
}

.search-wrap {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 0 14px;
  transition: border-color var(--transition);
}

.search-wrap:focus-within {
  border-color: var(--text);
}

.search-icon {
  font-size: 20px;
  color: var(--text3);
  font-variation-settings: 'FILL' 0;
}

.search-input {
  flex: 1;
  padding: 11px 0;
  border: none;
  background: transparent;
  color: var(--text);
  font-size: 14px;
  font-family: var(--font-body);
  outline: none;
}

.search-input::placeholder {
  color: var(--text3);
}

.lib-tabs {
  display: flex;
  gap: 2px;
  margin-bottom: 24px;
  padding: 2px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
}

.tab-btn {
  flex: 1;
  background: none;
  border: none;
  color: var(--text2);
  padding: 8px 12px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  font-family: var(--font-body);
  transition: background 120ms, color 120ms;
  text-transform: capitalize;
}

.tab-btn:hover {
  background: var(--surface2);
  color: var(--text);
}

.tab-btn.active {
  color: var(--accent);
  font-weight: 600;
}

.loading,
.empty {
  color: var(--text3);
  font-size: 14px;
  text-align: center;
  padding: 60px 40px;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(164px, 1fr));
  gap: 14px;
}

.hit-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 10px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--surface);
  color: var(--text);
  cursor: pointer;
  text-align: left;
  font-family: var(--font-body);
  transition: background 120ms, border-color 120ms, transform 120ms;
}

.hit-card:hover {
  background: var(--surface2);
  border-color: var(--text3);
  transform: translateY(-2px);
}

.art {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  border-radius: var(--radius-sm);
  overflow: hidden;
  background: var(--surface2);
}

.art img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.art-fallback {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text3);
}

.art-fallback .icon {
  font-size: 34px;
  font-variation-settings: 'FILL' 0;
}

.art-play {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  background: rgba(0, 0, 0, 0.35);
  opacity: 0;
  transition: opacity 120ms;
}

.art-play .icon {
  font-size: 40px;
  font-variation-settings: 'FILL' 1;
}

.hit-card:hover .art-play {
  opacity: 1;
}

.card-title {
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-artist {
  font-size: 12px;
  color: var(--text3);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
