#!/bin/sh
# POSIX-safe version (no bashisms). Works with /bin/sh (dash)
# Sets up Socket.IO (WebSocket) + SSE support in the frontend
# - Installs socket.io-client
# - Rewrites vite.config.js with proxy for /api, /stream and /socket.io (ws:true)
# - Rewrites src/api.js to prefer WebSocket (Socket.IO) then fallback to SSE
# Usage:
#   chmod +x ./enable_ws_and_stream_posix.sh
#   ./enable_ws_and_stream_posix.sh
#   npm run dev

set -eu

BACKEND=${BACKEND:-"http://10.10.31.31:8080"}
TS=$(date +%Y%m%d%H%M%S)

# 0) Sanity
if [ ! -f package.json ]; then
  echo "[ERROR] Run this script in the frontend folder (where package.json exists)." >&2
  exit 1
fi

# 1) Install socket.io-client
printf "== Installing socket.io-client ==\n"
# Prefer local install without sudo
npm i socket.io-client --save

# 2) Write vite.config.js with proper proxy (ws:true)
printf "== Updating vite.config.js (proxy -> %s) ==\n" "$BACKEND"
if [ -f vite.config.js ]; then
  cp vite.config.js "vite.config.js.bak.${TS}"
  echo "[backup] vite.config.js -> vite.config.js.bak.${TS}"
fi
cat > vite.config.js <<JS
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
      '/socket.io':{ target: '${BACKEND}', changeOrigin: true, ws: true },
    },
    // hmr: { host: '10.10.31.31', port: 5173 },
  },
})
JS

# 3) Rewrite src/api.js with WS-first + SSE fallback
printf "== Rewriting src/api.js (WS first + SSE fallback) ==\n"
if [ ! -f src/api.js ]; then
  echo "[ERROR] src/api.js not found; aborting to avoid breaking your project." >&2
  exit 1
fi
cp src/api.js "src/api.js.bak.${TS}"
echo "[backup] src/api.js -> src/api.js.bak.${TS}"

cat > src/api.js <<'JS'
import { io } from "socket.io-client";

const API = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE) || "/";

const log  = (...a) => console.info("[kuma-api]", ...a);
const warn = (...a) => console.warn("[kuma-api]", ...a);
const err  = (...a) => console.error("[kuma-api]", ...a);

async function fetchJSON(path, init = {}) {
  const res = await fetch(API + path, {
    headers: { "Accept": "application/json", ...(init.headers || {}) },
    ...init,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} ${res.statusText} - ${text}`);
  }
  return res.json();
}

export async function fetchSummary() {
  const r = await fetchJSON("api/summary");
  log("summary OK");
  return r;
}

export async function fetchMonitors() {
  const candidates = [
    "api/monitors", "api/monitor", "api/monitor/list",
    "api/monitors/list", "api/state", "monitors",
  ];
  for (const p of candidates) {
    try {
      const r = await fetchJSON(p);
      const arr = Array.isArray(r)
        ? r
        : Array.isArray(r?.monitors)
          ? r.monitors
          : Array.isArray(r?.data?.monitors)
            ? r.data.monitors
            : null;
      if (arr) { log("monitors OK via", p, `(${arr.length})`); return arr; }
      warn("monitors shape inesperada en", p, r);
    } catch (e) {
      log("monitors no en", p, "-", (e && e.message) || e);
    }
  }
  warn("Ninguna ruta de 'monitors' respondió. Se esperará a WS/SSE.");
  return [];
}

function pickMonitors(p) {
  if (!p) return [];
  if (Array.isArray(p)) return p;
  if (Array.isArray(p.monitors)) return p.monitors;
  if (Array.isArray(p?.data?.monitors)) return p.data.monitors;
  if (Array.isArray(p?.payload?.monitors)) return p.payload.monitors;
  if (Array.isArray(p.items)) return p.items;
  return [];
}

export function openStream(onMessage, { retryMs = 2000, maxRetryMs = 15000 } = {}) {
  // ===== 1) WebSocket (Socket.IO) primero =====
  try {
    const base = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE)
      ? import.meta.env.VITE_API_BASE.replace(/\/$/, "")
      : ""; // vacío → relativo al dev server (proxy)

    const socket = io(base || undefined, {
      path: "/socket.io",
      transports: ["websocket"],
      withCredentials: true,
    });

    socket.on("connect", () => log("WS conectado", socket.id));

    ["tick", "monitors", "message", "data"].forEach(ev =>
      socket.on(ev, (payload) => {
        log(`WS '${ev}' recibido`);
        try { onMessage?.(payload); }
        catch(e){ err("onMessage error:", e); }
      })
    );

    socket.on("disconnect", (reason) => warn("WS desconectado:", reason));

    // Si WS funciona, devolvemos su close y listo.
    return () => { try { socket.close(); } catch {} };
  } catch (e) {
    warn("WS init error, fallback a SSE:", e);
  }

  // ===== 2) Fallback SSE =====
  const PATHS = ["/stream", "/api/stream", "/api/sse", "/events"];
  let stopped = false, es = null, pathIdx = 0, backoff = retryMs, received = false;

  const attach = () => {
    const handler = (label, e) => {
      try { onMessage?.(JSON.parse(e.data)); }
      catch (err2) { warn("SSE parse err", label, err2); }
    };
    es.addEventListener("tick",    (e)=>handler("tick", e));
    es.addEventListener("message", (e)=>handler("message", e));
    es.onmessage = (e)=>handler("onmessage", e);
  };

  const tryNext = () => {
    if (stopped) return;
    if (pathIdx >= PATHS.length) {
      setTimeout(() => {
        if (!stopped) { pathIdx = 0; backoff = Math.min(backoff * 2, maxRetryMs); start(); }
      }, backoff);
      return;
    }
    start();
  };

  const start = () => {
    const path = PATHS[pathIdx]; received = false;
    try { log("SSE intentando", path); es = new EventSource(API + path); }
    catch (e) { warn("EventSource init err:", e); pathIdx++; return tryNext(); }

    const watchdog = setTimeout(() => {
      if (!received) { warn("SSE sin datos en", path, "→ siguiente"); es.close(); pathIdx++; tryNext(); }
    }, 5000);

    es.onopen = () => log("SSE abierto en", path);
    es.onerror = () => { clearTimeout(watchdog); es?.close?.(); if (!stopped) { warn("SSE error", path, "→ siguiente"); pathIdx++; tryNext(); } };
    attach();
  };

  start();
  return () => { stopped = true; try { es?.close?.(); } catch {} };
}

const BL_KEY = "kuma_blocklist_v1";
export async function getBlocklist() {
  try {
    const r = await fetchJSON("api/blocklist");
    log("blocklist server OK");
    return r;
  } catch (e) {
    try {
      const raw = localStorage.getItem(BL_KEY);
      return raw ? JSON.parse(raw) : { monitors: [] };
    } catch {
      return { monitors: [] };
    }
  }
}
export async function saveBlocklist(b) {
  try {
    await fetchJSON("api/blocklist", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(b),
    });
    log("blocklist server guardado");
  } catch (e) {
    try { localStorage.setItem(BL_KEY, JSON.stringify(b)); }
    catch (e2) { err("no se pudo guardar blocklist", e2); }
  }
}
JS

printf "\n✅ Done. Now run: npm run dev\n"
printf "- En Network deberías ver /socket.io (101 websocket).\n"
printf "- Si el backend también expone SSE, /stream quedará en (pending).\n"
