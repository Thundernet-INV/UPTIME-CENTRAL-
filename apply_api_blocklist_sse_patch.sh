#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Patch: api.js (summary + monitors fallback + SSE autodetect + blocklist fallback)
#        + ErrorBoundary.jsx + wrap in main.jsx
# Uso:   ./apply_api_blocklist_sse_patch.sh
# ------------------------------------------------------------

ROOT_DIR=$(pwd)
SRC_DIR="${ROOT_DIR}/src"
COMP_DIR="${SRC_DIR}/components"
API_FILE="${SRC_DIR}/api.js"
MAIN_FILE="${SRC_DIR}/main.jsx"
ERR_B_FILE="${COMP_DIR}/ErrorBoundary.jsx"
TS=$(date +%Y%m%d%H%M%S)

need() {
  local f="$1"; if [[ ! -f "$f" ]]; then echo "[ERROR] No se encontró $f" >&2; exit 1; fi
}

ensure_tree() { mkdir -p "$COMP_DIR"; }

backup() { local f="$1"; [[ -f "$f" ]] && cp "$f" "$f.bak.${TS}" && echo "[backup] $f -> $f.bak.${TS}" || true; }

main() {
  echo "== Aplicando patch de API + ErrorBoundary =="
  need "$API_FILE"
  need "$MAIN_FILE"
  ensure_tree

  # ---- Backup ----
  backup "$API_FILE"
  backup "$MAIN_FILE"
  [[ -f "$ERR_B_FILE" ]] && backup "$ERR_B_FILE"

  # ---- api.js (reemplazo completo) ----
  cat > "$API_FILE" <<'JS'
const API = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE) || "/";

const log  = (...args) => console.info("[kuma-api]", ...args);
const warn = (...args) => console.warn("[kuma-api]", ...args);
const err  = (...args) => console.error("[kuma-api]", ...args);

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

// Intenta rutas alternativas; si ninguna existe, devuelve [] y se esperará al SSE
export async function fetchMonitors() {
  const candidates = [
    "api/monitors",
    "api/monitor",
    "api/monitor/list",
    "api/monitors/list",
    "api/state",
    "monitors",
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
  warn("Ninguna ruta de 'monitors' respondió. Se esperará al SSE.");
  return [];
}

// SSE: prueba varias rutas/eventos y reconecta
export function openStream(onMessage, { retryMs = 2000, maxRetryMs = 15000 } = {}) {
  const PATHS = ["/api/stream", "/stream", "/api/sse", "/events"];
  const EVENTS = ["tick", "message"];
  let stopped = false, es = null, pathIdx = 0, backoff = retryMs, received = false;

  const attach = () => {
    EVENTS.forEach(ev => {
      es.addEventListener(ev, (e) => {
        try {
          const payload = JSON.parse(e.data);
          received = true; backoff = retryMs;
          log(`SSE '${ev}' via ${PATHS[pathIdx]}`);
          onMessage?.(payload);
        } catch (e) { warn("SSE parse err:", e); }
      });
    });
    es.onmessage = (e) => {
      try {
        const payload = JSON.parse(e.data);
        received = true; backoff = retryMs;
        log(`SSE 'message' (sin event) via ${PATHS[pathIdx]}`);
        onMessage?.(payload);
      } catch (e) { warn("SSE parse err (message):", e); }
    };
  };

  const tryNext = () => {
    if (stopped) return;
    if (pathIdx >= PATHS.length) {
      setTimeout(() => { if (!stopped) { pathIdx = 0; backoff = Math.min(backoff * 2, maxRetryMs); start(); } }, backoff);
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
    es.onerror = () => { clearTimeout(watchdog); es?.close?.(); if (!stopped) { warn("SSE error en", path, "→ siguiente"); pathIdx++; tryNext(); } };
    attach();
  };

  start();
  return () => { stopped = true; try { es?.close?.(); } catch {} };
}

// Blocklist con fallback en localStorage
const BL_KEY = "kuma_blocklist_v1";

export async function getBlocklist() {
  try {
    const r = await fetchJSON("api/blocklist");
    log("blocklist server OK");
    return r;
  } catch (e) {
    try {
      const raw = localStorage.getItem(BL_KEY);
      const val = raw ? JSON.parse(raw) : { monitors: [] };
      warn("blocklist server no disponible, usando localStorage");
      return val;
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
    return;
  } catch (e) {
    try {
      localStorage.setItem(BL_KEY, JSON.stringify(b));
      warn("blocklist guardado en localStorage (fallback)");
    } catch (e2) {
      err("no se pudo guardar blocklist ni en server ni en localStorage", e2);
    }
  }
}
JS

  echo "[ok] api.js actualizado"

  # ---- ErrorBoundary.jsx (crear si no existe) ----
  cat > "$ERR_B_FILE" <<'JSX'
import React from "react";

export default class ErrorBoundary extends React.Component {
  constructor(props) { super(props); this.state = { hasError: false, error: null, info: null }; }
  static getDerivedStateFromError(error) { return { hasError: true, error }; }
  componentDidCatch(error, info) { console.error("[ErrorBoundary] render error:", error, info); this.setState({ info }); }
  render() {
    if (this.state.hasError) {
      return (
        <div style={{padding:16}}>
          <h2>Se produjo un error en la UI</h2>
          <pre style={{whiteSpace:"pre-wrap"}}>{String(this.state.error)}</pre>
          {this.state.info && (
            <details style={{whiteSpace:"pre-wrap"}}>
              <summary>Detalle</summary>
              {this.state.info.componentStack}
            </details>
          )}
        </div>
      );
    }
    return this.props.children;
  }
}
JSX
  echo "[ok] ErrorBoundary.jsx creado/actualizado"

  # ---- Patch main.jsx: importar y envolver <App/> con <ErrorBoundary> (idempotente) ----
  node - <<'JS'
const fs = require('fs');
const f = 'src/main.jsx';
let s = fs.readFileSync(f, 'utf8');
let changed = false;
if (!/ErrorBoundary/.test(s)) {
  // insertar import antes de la primera línea que empiece con import App
  s = s.replace(/(import\s+App\s+from\s+"\.\/App";?)/, `import ErrorBoundary from "./components/ErrorBoundary.jsx";\n$1`);
  changed = true;
}
// envolver <App /> si no está envuelto
if (!/<ErrorBoundary>/.test(s)) {
  s = s.replace(/<React\.StrictMode>\s*([\s\S]*?)<\/React\.StrictMode>/m, (m, inner) => {
    let inner2 = inner.replace(/<App\s*\/>/, `<ErrorBoundary>\n      <App />\n    </ErrorBoundary>`);
    if (inner2 === inner) {
      // fallback: si no encontró <App/>, sólo inserta
      inner2 = `  <ErrorBoundary>\n    <App />\n  </ErrorBoundary>`;
    }
    return `<React.StrictMode>\n${inner2}\n</React.StrictMode>`;
  });
  changed = true;
}
if (changed) fs.writeFileSync(f, s);
console.log('[ok] main.jsx envuelto con ErrorBoundary');
JS

  echo "\n✅ Patch aplicado. Ahora ejecuta:  npm run dev"
  echo "- Revisa en DevTools → Console los logs [kuma-api] del SSE (intentando rutas)"
  echo "- En Network filtra 'api' para ver summary=200 y el EventStream en pending"
}

main "$@"
