#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# All-in-one: reset vite.config.js (proxy to 10.10.31.31:80) +
# enforce SSE path priority (/stream first) in src/api.js
# Usage:
#   chmod +x ./all_in_one_stream_fix.sh
#   ./all_in_one_stream_fix.sh
#   npm run dev
# ------------------------------------------------------------

if [[ ! -f package.json ]]; then
  echo "[ERROR] Run this in the FRONTEND folder (where package.json exists)." >&2
  exit 1
fi

BACKUP_TS=$(date +%Y%m%d%H%M%S)

backup() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp "$f" "$f.bak.${BACKUP_TS}"
    echo "[backup] $f -> $f.bak.${BACKUP_TS}"
  fi
}

# 1) Reset vite.config.js to a known-good configuration
if [[ -f vite.config.js ]]; then
  backup vite.config.js
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
      '/api': { target: 'http://10.10.31.31', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31', changeOrigin: true },
    },
    // hmr: { host: '10.10.31.31', port: 5173 },
  },
})
JS

echo "[ok] vite.config.js written"

# 2) Ensure src/api.js exists and prioritize /stream in PATHS
if [[ ! -f src/api.js ]]; then
  echo "[WARN] src/api.js not found; skipping PATHS update" >&2
else
  backup src/api.js
  node - <<'JS'
const fs = require('fs');
const path = 'src/api.js';
let s = fs.readFileSync(path, 'utf8');

// If PATHS array exists, replace its contents to prioritize /stream
if (/const\s+PATHS\s*=\s*\[[^\]]*\]/m.test(s)) {
  s = s.replace(/const\s+PATHS\s*=\s*\[[^\]]*\]/m,
                'const PATHS = ["/stream", "/api/stream", "/api/sse", "/events"]');
  fs.writeFileSync(path, s);
  console.log('[ok] src/api.js: PATHS set to ["/stream", "/api/stream", "/api/sse", "/events"]');
} else {
  // If openStream function not found, just append a comment to warn user
  console.log('[info] PATHS array not found in src/api.js (maybe different structure). No changes applied.');
}
JS
fi

echo "\n✅ Done. Now run: npm run dev"
