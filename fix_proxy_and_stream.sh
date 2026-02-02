#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Fix Vite proxy to 10.10.31.31:80 and prioritize /stream in src/api.js SSE paths
# Usage: run this script from the FRONTEND root (where vite.config.js lives)
#   chmod +x ./fix_proxy_and_stream.sh && ./fix_proxy_and_stream.sh && npm run dev
# ------------------------------------------------------------

backup() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
    echo "[backup] $f -> $f.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

if [[ ! -f vite.config.js ]]; then
  echo "[ERROR] vite.config.js not found here. Run this from the frontend folder." >&2
  exit 1
fi

# 1) Update vite.config.js: server.host/port/strictPort and proxy for /api and /stream to :80
backup vite.config.js

node - <<'JS'
const fs = require('fs');
let s = fs.readFileSync('vite.config.js', 'utf8');

if (!/export default defineConfig\(/.test(s)) {
  console.error('[ERROR] vite.config.js does not look like a Vite config');
  process.exit(1);
}

// Ensure server block
if (!/server:\s*\{[\s\S]*?\}/.test(s)) {
  s = s.replace(/export default defineConfig\(\{([\s\S]*?)plugins:\s*\[react\(\)\],?/,
`export default defineConfig({$1plugins: [react()],
  server: {
    host: '10.10.31.31',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': { target: 'http://10.10.31.31', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31', changeOrigin: true },
    },
  },`);
} else {
  // Inject/replace proxy
  if (/proxy:\s*\{[\s\S]*?\}/.test(s)) {
    s = s.replace(/proxy:\s*\{[\s\S]*?\}/,
`proxy: {
      '/api': { target: 'http://10.10.31.31', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31', changeOrigin: true },
    }`);
  } else {
    s = s.replace(/server:\s*\{([\s\S]*?)\}/,
      (m, inner) => `server: {${inner}
    proxy: {
      '/api': { target: 'http://10.10.31.31', changeOrigin: true },
      '/stream': { target: 'http://10.10.31.31', changeOrigin: true },
    }
  }`);
  }
  // Normalize host/port/strictPort
  s = s.replace(/server:\s*\{([\s\S]*?)\}/,
    (m, inner) => {
      let x = inner;
      if (!/host:/.test(x)) x = `host: '10.10.31.31',\n` + x;
      x = x.replace(/host:\s*['"][^'\"]*['"]/g, `host: '10.10.31.31'`);
      if (!/port:/.test(x)) x = x.replace(/\{/, `{\n    port: 5173,`);
      x = x.replace(/port:\s*\d+/g, 'port: 5173');
      if (!/strictPort:/.test(x)) x = x + `\n    strictPort: true,`;
      return `server: {${x}}`;
    });
}

fs.writeFileSync('vite.config.js', s);
console.log('[ok] vite.config.js updated: proxy /api and /stream to http://10.10.31.31:80');
JS

# 2) Prioritize /stream in src/api.js SSE candidate paths
if [[ -f src/api.js ]]; then
  backup src/api.js
  # Replace PATHS array order if present
  if grep -q 'const PATHS = \["/api/stream", "/stream", "/api/sse", "/events"\]' src/api.js; then
    sed -i "s#\[\"/api/stream\", \"/stream\", \"/api/sse\", \"/events\"\]#[\"/stream\", \"/api/stream\", \"/api/sse\", \"/events\"]#g" src/api.js
    echo "[ok] src/api.js: PATHS now prioritizes /stream"
  else
    # Try to replace when array exists in any order (best-effort)
    sed -i "s#\[\"/stream\", \"/api/stream\", \"/api/sse\", \"/events\"\]#[\"/stream\", \"/api/stream\", \"/api/sse\", \"/events\"]#g" src/api.js || true
    sed -i "s#\[\"/api/stream\", \"/api/sse\", \"/events\", \"/stream\"\]#[\"/stream\", \"/api/stream\", \"/api/sse\", \"/events\"]#g" src/api.js || true
    echo "[info] Checked src/api.js for PATHS; ensure it includes /stream first."
  fi
else
  echo "[WARN] src/api.js not found; skip PATHS update."
fi

echo "\nDone. Now run: npm run dev"
