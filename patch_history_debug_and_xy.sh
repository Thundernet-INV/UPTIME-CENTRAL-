#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
HIST="$ROOT/src/historyEngine.js"
ts=$(date +%Y%m%d_%H%M%S)
[ -f "$HIST" ] && cp "$HIST" "$HIST.bak_$ts" || true

cat > "$HIST" <<'JS'
import DB from './historyDB';

/** Convierte una muestra a un objeto con TODOS los alias habituales */
function mkPoint(ts, ms){
  const sec = (typeof ms === 'number') ? (ms/1000) : null;
  return {
    ts,                         // timestamp (ms)
    x: ts,                      // muchas libs esperan x
    y: (sec != null ? sec : null),  // y en segundos (algunas usan s)
    value: (sec != null ? sec : null),
    sec,                        // segundos
    ms, avgMs: ms,              // milisegundos
    xy: [ts, (sec != null ? sec : null)], // tupla [x,y] en seg
  };
}

const History = {
  /** Persiste snapshot + poda a 7 días */
  addSnapshot(monitors) {
    DB.addSnapshots(monitors).catch(()=>{});
    DB.pruneOlderThanDays(7).catch(()=>{});
  },

  /** Serie cruda por monitor (última ventana) */
  async getSeriesForMonitor(instance, name, sinceMs = 24*3600*1000) {
    const key = `${instance}::${name || ''}`;
    const rows = await (DB.getSeriesFor ? DB.getSeriesFor(key, sinceMs) : Promise.resolve([]));
    return rows
      .filter(r => typeof r.responseTime === 'number')
      .map(r => mkPoint(r.ts, r.responseTime));
  },

  /** Serie promedio por monitor (buckets temporales) */
  async getAvgSeriesForMonitor(instance, name, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
    const samples = await History.getSeriesForMonitor(instance, name, sinceMs);
    if (!samples.length) return [];
    const sum = new Map(), count = new Map();
    for (const s of samples) {
      const ms = (typeof s.ms === 'number') ? s.ms : (s.sec * 1000);
      const b = Math.floor(s.ts / bucketMs) * bucketMs;
      sum.set(b, (sum.get(b) || 0) + ms);
      count.set(b, (count.get(b) || 0) + 1);
    }
    const out = [];
    for (const [b, s] of sum) out.push(mkPoint(b, s / (count.get(b) || 1)));
    out.sort((a,b)=> a.ts - b.ts);
    return out;
  },

  /** Obj { nombreMonitor: muestras[] } por instancia */
  async getAllForInstance(instance, sinceMs = 24*3600*1000) {
    const obj = await (DB.getAllForInstance ? DB.getAllForInstance(instance, sinceMs) : Promise.resolve({}));
    const out = {};
    for (const [name, arr] of Object.entries(obj || {})) {
      out[name] = (arr || [])
        .filter(r => typeof r.responseTime === 'number')
        .map(r => mkPoint(r.ts, r.responseTime));
    }
    return out;
  },

  /** Serie promedio por instancia (array de puntos) */
  async getAvgSeriesByInstance(instance, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
    const raw = await (DB.getAvgSeriesByInstance ? DB.getAvgSeriesByInstance(instance, sinceMs, bucketMs) : Promise.resolve([]));
    return (raw || []).map(p => mkPoint(p.ts, p.avgMs));
  },
};

/** Exponer para depuración en consola: window.__hist */
try { if (typeof window !== 'undefined') window.__hist = History; } catch {}

export default History;
JS

echo "== Build =="
cd "$ROOT"
npm run build

echo "== Deploy =="
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ History expuesto como window.__hist y puntos con {x,y,ms,sec,xy}."
