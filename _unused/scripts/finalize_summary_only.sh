
#!/bin/sh
# Deja el front usando SOLO /api/summary (+polling), sin WS/SSE.
# Uso:
#   chmod +x ./finalize_summary_only.sh
#   BACKEND="http://10.10.31.31:80" ./finalize_summary_only.sh
#   npm run dev

set -eu

BACKEND="${BACKEND:-http://10.10.31.31:80}"
TS=$(date +%Y%m%d%H%M%S)

need() { [ -f "$1" ] || { echo "[ERROR] Falta $1" >&2; exit 1; }; }

need package.json
need vite.config.js
need src/api.js

echo "== Backups =="
cp vite.config.js "vite.config.js.bak.$TS" && echo "[backup] vite.config.js"
cp src/api.js     "src/api.js.bak.$TS"     && echo "[backup] src/api.js"

echo "== Reescribiendo vite.config.js con proxy solo /api -> $BACKEND =="
cat > vite.config.js <<EOF
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '10.10.31.31',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': { target: '${BACKEND}', changeOrigin: true }
    }
  }
})
EOF

echo "== Reescribiendo src/api.js (summary-only + polling) =="
cat > src/api.js <<'JS'
// API base
const API = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE) || "/";

const log = (...a) => console.log("[kuma-api]", ...a);
const err = (...a) => console.error("[kuma-api]", ...a);

// Helpers
async function get(path) {
  const res = await fetch(API + path);
  if (!res.ok) throw new Error("HTTP " + res.status);
  return res.json();
}

// Lee todo de /api/summary
export async function fetchAll() {
  try {
    const data = await get("api/summary");
    const instances = data.instances || [];
    const monitors  = data.monitors  || [];
    return { instances, monitors };
  } catch (e) {
    err("fetchAll()", e);
    return { instances: [], monitors: [] };
  }
}

// Compatibilidad con UI
export async function fetchSummary() {
  const { instances } = await fetchAll();
  return {
    up:   instances.filter(i => i.ok).length,
    down: instances.filter(i => !i.ok).length,
    total: instances.length,
  };
}

export async function fetchMonitors() {
  const { monitors } = await fetchAll();
  return monitors;
}

// NO stream: hacemos polling y llamamos onMessage(monitors)
export function openStream(onMessage) {
  let stop = false;
  async function loop() {
    if (stop) return;
    try {
      const { monitors } = await fetchAll();
      onMessage(monitors);
    } catch {}
    setTimeout(loop, 5000); // ajusta el intervalo si quieres
  }
  loop();
  return () => { stop = true; };
}

// Blocklist opcional con fallback local
export async function getBlocklist() {
  try { return await get("api/blocklist"); }
  catch {
    const raw = localStorage.getItem("blocklist");
    return raw ? JSON.parse(raw) : { monitors: [] };
  }
}
export async function saveBlocklist(b) {
  try {
    await fetch(API + "api/blocklist", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(b),
    });
  } catch {
    localStorage.setItem("blocklist", JSON.stringify(b));
  }
}
JS

echo "== Desinstalando socket.io-client (ya no se usa) =="
npm rm socket.io-client || true

# .env de ejemplo (por si luego quieres apuntar directo sin proxy)
if [ ! -f .env ]; then
  cat > .env <<'ENV'
# Si quieres saltarte el proxy de Vite y llamar directo al backend, descomenta:
# VITE_API_BASE=http://10.10.31.31:80/
ENV
fi

echo "✅ Listo. Levanta: npm run dev"

