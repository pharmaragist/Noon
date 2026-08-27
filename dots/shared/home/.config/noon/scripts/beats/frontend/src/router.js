import { createRouter, createWebHashHistory } from 'vue-router'
import NowPlaying from './components/NowPlaying.vue'
import LibraryView from './components/LibraryView.vue'
import HitsPage from './components/HitsPage.vue'

const routes = [
  { path: '/', redirect: '/player' },
  { path: '/player', name: 'player', component: NowPlaying },
  { path: '/hits', name: 'hits', component: HitsPage },
  { path: '/tracks', name: 'tracks', component: LibraryView },
  { path: '/albums', name: 'albums', component: LibraryView },
  { path: '/artists', name: 'artists', component: LibraryView },
  ]

export default createRouter({
  history: createWebHashHistory(),
  routes,
})
