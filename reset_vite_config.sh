#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f package.json ]]; then
  echo "[ERROR] Ejecuta este script en la carpeta del frontend (donde está package.json / vite.config.js)" >&2
  exit 1
fi

if [[ -f vite.config.js ]]; then
  cp vite.config.js vite.config.bak.$(date +%Y%m%d%H%M%S).js
  echo "[backup] vite.config.js -> vite.config.bak.*"
fi

cat > vite.config.js <<'JS'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '10.10.31.31',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': {
        target: 'http://10.10.31.31',
        changeOrigin: true,
      },
      '/stream': {
        target: 'http://10.10.31.31',
        changeOrigin: true,
      },
    },
    // hmr: { host: '10.10.31.31', port: 5173 },
  },
})
JS

echo "✅ vite.config.js reescrito. Ahora ejecuta: npm run dev"
