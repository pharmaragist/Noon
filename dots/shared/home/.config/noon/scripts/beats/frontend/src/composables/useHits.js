import { ref, computed } from 'vue'

// module-level: survives route switches
const feed = ref([])
const searchResults = ref([])
const source = ref('recommend')
const query = ref('')
const busy = ref(false)
const loaded = ref(false)

const items = computed(() => (source.value === 'search' ? searchResults.value : feed.value))

async function fetchHits(kind, params) {
  busy.value = true
  try {
    const qs = new URLSearchParams(params).toString()
    const resp = await fetch(`/api/hits/${kind}?${qs}`)
    if (resp.ok) return await resp.json()
  } catch (_) {}
  return []
}

async function loadStored() {
  if (loaded.value) return
  try {
    const resp = await fetch('/api/hits/feed')
    if (resp.ok) {
      const d = await resp.json()
      feed.value = d.feed || []
      searchResults.value = d.searchResults || []
      loaded.value = true
    }
  } catch (_) {}
}

async function setSource(kind) {
  source.value = kind
  if (kind === 'search') return
  if (!loaded.value) await loadStored()
}

async function doSearch() {
  const q = query.value.trim()
  if (!q) return
  busy.value = true
  source.value = 'search'
  searchResults.value = await fetchHits('search', { query: q, limit: 18 })
  busy.value = false
}

async function loadMore() {
  const batch = await fetchHits(source.value, { limit: 18 })
  const seen = new Set(feed.value.map(t => t.videoId || t.url))
  feed.value = [...feed.value, ...batch.filter(t => !seen.has(t.videoId || t.url))]
  busy.value = false
}

export function useHits() {
  return { query, items, source, busy, loadStored, setSource, doSearch, loadMore }
}
