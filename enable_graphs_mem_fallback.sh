#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
MEM="$ROOT/src/historyMem.js"
HIST="$ROOT/src/historyEngine.js"
APP="$ROOT/src/App.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$MEM" ]  && cp "$MEM"  "$MEM.bak_$ts"  || true
[ -f "$HIST" ] && cp "$HIST" "$HIST.bak_$ts" || true
[ -f "$APP" ]  && cp "$APP"  "$APP.bak_$ts"  || true

echo "== 1) historyMem.js: buffer en memoria (rápido para graficar) =="
cat > "$MEM" <<'JS'
// historyMem.js — fallback en memoria para series (sin depender de IndexedDB)
const seriesByKey = new Map();   // "instance::name" -> [{ts, ms}]
const lastByInstance = new Map();// "instance" -> { lastTs, count }

const MAX_POINTS_PER_SERIES = 20000; // guarda ~27h a 5s (ajusta si necesitas más)
const KEY = (instance, name='') => `${instance}::${name}`;

function addSnapshots(monitors, nowTs = Date.now()) {
  if (!Array.isArray(monitors)) return;
  let added = 0;
  for (const m of monitors) {
    const ms = (m?.latest?.responseTime ?? null);
    if (typeof ms !== 'number') continue;
    const k = KEY(m.instance, m.info?.monitor_name || '');
    const arr = seriesByKey.get(k) || [];
    arr.push({ ts: nowTs, ms });
    if (arr.length > MAX_POINTS_PER_SERIES) arr.splice(0, arr.length - MAX_POINTS_PER_SERIES);
    seriesByKey.set(k, arr);
    added++;
  }
  if (added) {
    const inst = monitors[0]?.instance;
    if (inst) lastByInstance.set(inst, { lastTs: nowTs, count: added });
  }
}

function _getRange(msBack) {
  const since = Date.now() - Math.max(0, Number(msBack) || 0);
  return since;
}

function getSeriesForMonitor(instance, name, sinceMs) {
  const arr = seriesByKey.get(KEY(instance, name)) || [];
  const since = _getRange(sinceMs);
  return arr.filter(r => r.ts >= since).map(r => ({ ts: r.ts, ms: r.ms }));
}

function getAvgSeriesByInstance(instance, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
  const since = _getRange(sinceMs);
  // sumar todas las series de esa instancia
  const sum = new Map(), count = new Map();
  const prefix = `${instance}::`;
  for (const [k, arr] of seriesByKey) {
    if (!k.startsWith(prefix)) continue;
    for (const r of arr) {
      if (r.ts < since) continue;
      const b = Math.floor(r.ts / bucketMs) * bucketMs;
      sum.set(b, (sum.get(b) || 0) + r.ms);
      count.set(b, (count.get(b) || 0) + 1);
    }
  }
  const out = [];
  for (const [b, s] of sum) out.push({ ts: b, avgMs: s / (count.get(b) || 1) });
  out.sort((a,b)=> a.ts - b.ts);
  return out;
}

function getAllForInstance(instance, sinceMs = 24*3600*1000) {
  const since = _getRange(sinceMs);
  const out = {};
  const prefix = `${instance}::`;
  for (const [k, arr] of seriesByKey) {
    if (!k.startsWith(prefix)) continue;
    const name = k.slice(prefix.length);
    out[name] = arr.filter(r => r.ts >= since).map(r => ({ ts: r.ts, ms: r.ms }));
  }
  return out;
}

function debugInfo() {
  const keys = Array.from(seriesByKey.keys());
  return {
    keys: keys.slice(0, 10),
    totalSeries: keys.length,
    lastByInstance: Array.from(lastByInstance.entries()),
  };
}

export default {
  addSnapshots,
  getSeriesForMonitor,
  getAvgSeriesByInstance,
  getAllForInstance,
  debugInfo,
};
JS

echo "== 2) historyEngine.js: usa memoria como fuente principal + IndexedDB en background =="
cat > "$HIST" <<'JS'
import Mem from './historyMem';
import DB from './historyDB'; // puede fallar en tu navegador; por eso es background

// normaliza un punto con muchos alias (compat con gráficas)
function mkPoint(ts, ms){
  const sec = (typeof ms === 'number') ? ms/1000 : null;
  return { ts, x: ts, y: sec, value: sec, sec, ms, avgMs: ms, xy: [ts, sec] };
}

const History = {
  // 1) Persistencia: primero memoria (rápido para graficar), luego IndexedDB (en background)
  addSnapshot(monitors) {
    try { Mem.addSnapshots(monitors); } catch {}
    try { DB.addSnapshots?.(monitors); DB.pruneOlderThanDays?.(7); } catch {}
    try { if (typeof window !== 'undefined') window.__histLastAddTs = Date.now(); } catch {}
  },

  // 2) Serie cruda por monitor
  async getSeriesForMonitor(instance, name, sinceMs = 15*60*1000) {
    // memoria primero
    const mem = Mem.getSeriesForMonitor(instance, name, sinceMs) || [];
    if (mem.length) return mem.map(r => mkPoint(r.ts, r.ms));
    // si memoria aún vacía (recién arrancado), intenta IndexedDB
    const key = `${instance}::${name||''}`;
    const rows = await (DB.getSeriesFor ? DB.getSeriesFor(key, sinceMs) : Promise.resolve([]));
    return (rows||[]).filter(r => typeof r.responseTime === 'number').map(r => mkPoint(r.ts, r.responseTime));
  },

  // 3) Serie promedio por instancia (buckets)
  async getAvgSeriesByInstance(instance, sinceMs = 15*60*1000, bucketMs = 60*1000) {
    const mem = Mem.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
    if (mem.length) return mem.map(p => mkPoint(p.ts, p.avgMs));
    const arr = await (DB.getAvgSeriesByInstance ? DB.getAvgSeriesByInstance(instance, sinceMs, bucketMs) : Promise.resolve([]));
    return (arr||[]).map(p => mkPoint(p.ts, p.avgMs));
  },

  // 4) Todas las series por instancia (objeto)
  async getAllForInstance(instance, sinceMs = 15*60*1000) {
    const obj = Mem.getAllForInstance(instance, sinceMs);
    if (obj && Object.keys(obj).length) {
      const out = {};
      for (const [name, a] of Object.entries(obj)) out[name] = a.map(r => mkPoint(r.ts, r.ms));
      return out;
    }
    const dbObj = await (DB.getAllForInstance ? DB.getAllForInstance(instance, sinceMs) : Promise.resolve({}));
    const out = {};
    for (const [name, arr] of Object.entries(dbObj || {})) {
      out[name] = (arr||[]).filter(r => typeof r.responseTime === 'number').map(r => mkPoint(r.ts, r.responseTime));
    }
    return out;
  },

  debugInfo() { return Mem.debugInfo(); },
};

// Exponer para consola
try { if (typeof window !== 'undefined') window.__hist = History; } catch {}

export default History;
JS

echo "== 3) Asegurar que App.jsx llama a History.addSnapshot(monitors) en cada polling =="
# Deja tal cual si ya existe; aquí sólo informamos.
grep -n 'History.addSnapshot' "$APP" || echo "[WARN] No se encontró History.addSnapshot en $APP; revísalo."

echo "== 4) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Lista la capa en memoria (rápida) + __hist expuesto para depurar"
