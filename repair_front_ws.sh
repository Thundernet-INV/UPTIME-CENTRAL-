
#!/bin/sh
# Repara por completo src/api.js y vite.config.js (WS + SSE + proxy correcto)
# Uso:
#   chmod +x repair_front_ws.sh
#   ./repair_front_ws.sh
#   npm run dev

set -eu

BACKEND="${BACKEND:-http://10.10.31.31:8080}"
TS=$(date +%Y%m%d%H%M%S)

echo "== Reparando FRONTEND con backend: $BACKEND =="

if [ ! -f package.json ]; then
  echo "[ERROR] No estás en el frontend. Falta package.json." >&2
  exit 1
fi

if [ ! -d src ]; then
  echo "[ERROR] Falta carpeta src/ dentro de este proyecto." >&2
  exit 1
fi

echo "== Instalando socket.io-client =="
npm i socket.io-client --save

###############################################################################
# 1) REESCRIBIR src/api.js (VERSIÓN LIMPIA Y FUNCIONAL)
###############################################################################

APIJS="src/api.js"
cp "$APIJS" "$APIJS.bak.$TS"

cat > "$APIJS" <<"EOF"
import { io } from "socket.io-client";

// API base para fetch y SSE. En dev, el proxy de Vite reescribe las rutas.
const API = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE) || "/";

// Token opcional para WebSocket
const WS_TOKEN =
  (typeof import.meta !== "undefined" && import.meta.env?.VITE_WS_TOKEN) ||
  (typeof localStorage !== "undefined" ? localStorage.getItem("KUMA_WS_TOKEN") : null);

const log  = (...a) => console.info("[kuma]", ...a);
const warn = (...a) => console.warn("[kuma]", ...a);
const err  = (...a) => console.error("[kuma]", ...a);

// ---------------- FETCH HELPERS ----------------
async function fetchJSON(path, init = {}) {
  const res = await fetch(API + path, {
    headers: { Accept: "application/json", ...(init.headers || {}) },
    ...init,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} ${res.statusText} - ${text}`);
  }
  return res.json();
}

export async function fetchSummary() {
  return fetchJSON("api/summary");
}

export async function fetchMonitors() {
  // tu backend no expone /api/monitors, así que devolvemos []
  return [];
}

// --------------- NORMALIZADOR DE PAYLOAD ----------------
function pickMonitors(p) {
  if (!p) return [];
  if (Array.isArray(p)) return p;
  if (Array.isArray(p.monitors)) return p.monitors;
  if (Array.isArray(p?.data?.monitors)) return p.data.monitors;
  if (Array.isArray(p?.payload?.monitors)) return p.payload.monitors;
  if (Array.isArray(p.items)) return p.items;
  return [];
}

// --------------- CANAL EN TIEMPO REAL (WS + fallback SSE) ---------------
export function openStream(onMessage) {
  // ----- 1) WebSocket Socket.IO -----
  try {
    const base =
      (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE)
        ? import.meta.env.VITE_API_BASE.replace(/\/$/, "")
        : "";

    const socket = io(base || undefined, {
      path: "/socket.io",
      transports: ["websocket"],
      withCredentials: true,
      auth:  WS_TOKEN ? { token: WS_TOKEN } : undefined,
      query: WS_TOKEN ? { token: WS_TOKEN } : undefined,
    });

    socket.on("connect", () => log("WS conectado", socket.id));
    socket.on("connect_error", (e) => warn("WS connect_error:", e));
    socket.on("error", (e) => warn("WS error:", e));

    // Captura TODOS los eventos emitidos por backend
    if (socket.onAny) {
      socket.onAny((ev, payload) => {
        log("[ws:any]", ev, payload);
        try {
          const list = pickMonitors(payload);
          if (list?.length) onMessage(list);
        } catch (e) {
          err("onMessage error:", e);
        }
      });
    }

    // si el backend exige una subscripción:
    if (WS_TOKEN) {
      try { socket.emit("auth", { token: WS_TOKEN }); } catch {}
      try { socket.emit("subscribe", { token: WS_TOKEN }); } catch {}
    }

    return () => { try { socket.close(); } catch {} };
  } catch(e) {
    warn("WS init error:", e);
  }

  // ----- 2) SSE Fallback -----
  const es = new EventSource(API + "/stream");
  es.onmessage = (e) => {
    try {
      const payload = JSON.parse(e.data);
      const list = pickMonitors(payload);
      if (list?.length) onMessage(list);
    } catch {}
  };
  es.onerror = () => warn("SSE error");
  return () => es.close();
}

// ---------------- BLOCKLIST localStorage ----------------
const BL_KEY = "kuma_blocklist_v1";

export async function getBlocklist() {
  try { return await fetchJSON("api/blocklist"); }
  catch { return JSON.parse(localStorage.getItem(BL_KEY) || '{"monitors":[]}'); }
}

export async function saveBlocklist(b) {
  try {
    await fetchJSON("api/blocklist", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(b),
    });
  } catch {
    localStorage.setItem(BL_KEY, JSON.stringify(b));
  }
}
EOF

echo "✔ src/api.js reparado."

###############################################################################
# 2) REESCRIBIR vite.config.js
###############################################################################

VITE="vite.config.js"
cp "$VITE" "$VITE.bak.$TS"

cat > "$VITE" <<EOF
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '10.10.31.31',
    port: 5173,
    strictPort: true,
    proxy: {
      '/api':      { target: '${BACKEND}', changeOrigin: true },
      '/stream':   { target: '${BACKEND}', changeOrigin: true },
      '/socket.io':{
        target: '${BACKEND}',
        changeOrigin: true,
        ws: true
      }
    }
  }
})
EOF

echo "✔ vite.config.js reparado."

echo ""
echo "=== TODO LISTO ==="
echo "Ejecuta: npm run dev"
echo "Luego en Network → selecciona WebSocket → verás /socket.io (101)"
echo "En Console → verás [ws:any] <evento> <payload>"
echo ""
echo "Si tu backend exige token, antes ejecuta:"
echo "echo \"VITE_WS_TOKEN=TU_TOKEN\" >> .env"

