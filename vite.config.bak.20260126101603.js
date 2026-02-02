
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '10.10.31.31',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': { target: 'http://10.10.31.31', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31', changeOrigin: true },
    },
      '/stream': {
        target: 'http://10.10.31.31', // ← reenvía el SSE
        changeOrigin: true,
      },
    },
    // Si el HMR no conecta desde otra máquina, descomenta:
    // hmr: { host: '10.10.31.31', port: 5173 },
  },
})

