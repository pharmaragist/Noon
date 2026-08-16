import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: './',
  css: { postcss: { plugins: [] } },
  build: {
    outDir: '../page',
    emptyOutDir: true,
  },
})
