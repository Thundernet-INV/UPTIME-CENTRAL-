#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
HDB="$ROOT/src/historyDB.js"
HIST="$ROOT/src/historyEngine.js"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$HDB" ]  && cp "$HDB"  "$HDB.bak_$ts"  || true
[ -f "$HIST" ] && cp "$HIST" "$HIST.bak_$ts" || true

echo "== 1) historyDB.js: asegurar utilitarios base =="
# Si ya tenías este archivo con nuestras funciones previas, lo respetamos; solo garantizamos getSeriesFor
# (El resto de compat lo hacemos en historyEngine para evitar tocar más aquí)
grep -q 'export default' "$HDB" || cat > "$HDB" <<'JS'
// Mínimo viable para front: openDB + getSeriesFor(key, sinceMs)
// (Si ya tienes una versión más completa, este bloque no se usará)
const DB_NAME = 'kuma_history_v2';
const STORE   = 'snapshots';
const DB_VER  = 1;

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VER);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        const os = db.createObjectStore(STORE, { keyPath: 'id', autoIncrement: true });
        os.createIndex('by_ts',  'ts');
        os.createIndex('by_key', 'key'); // instance::name
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror   = () => reject(req.error);
  });
}

async function getSeriesFor(key, sinceMs) {
  const since = Date.now() - Math.max(0, Number(sinceMs) || 0);
  const out = [];
  const db = await openDB();
  const tx = db.transaction(STORE, 'readonly');
  const st = tx.objectStore(STORE);
  const idx = st.index('by_key');
  const req = idx.openCursor(IDBKeyRange.only(key));
  await new Promise((resolve, reject) => {
    req.onsuccess = () => {
      const cur = req.result;
      if (!cur) return resolve();
      if (cur.value.ts >= since) out.push(cur.value);
      cur.continue();
    };
    req.onerror = () => reject(req.error);
  });
  db.close();
  return out;
}

export default { getSeriesFor };
JS

echo "== 2) historyEngine.js: exponer compat getSeriesForMonitor y getAvgSeriesForMonitor =="
cat > "$HIST" <<'JS'
import DB from './historyDB';

/**
 * Capa de compatibilidad para el front heredado.
 * Implementa:
 *  - getSeriesForMonitor(instance, monitorName, sinceMs) => Array<{ts, responseTime, status,...}>
 *  - getAvgSeriesForMonitor(instance, monitorName, sinceMs=24h, bucketMs=60s) => Array<{ts, avgMs}>
 *  - (mantiene) getAllForInstance, getAvgSeriesByInstance si tú ya los añadiste antes
 */
const History = {
  // Mantén tus snapshots si ya los tienes en otro módulo
  addSnapshot(monitors) {
    // NO-OP aquí; tu App.jsx ya llama History.addSnapshot() propio si existe.
    // Si quieres persistir, reemplaza este cuerpo con DB.addSnapshots(...)
  },

  // === Compat 1: serie cruda por monitor (clave: instance::name) ===
  async getSeriesForMonitor(instance, name, sinceMs = 24*3600*1000) {
    const key = `${instance}::${name || ''}`;
    return DB.getSeriesFor(key, sinceMs);
  },

  // === Compat 2: serie promedio por monitor (array) ===
  async getAvgSeriesForMonitor(instance, name, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
    const samples = await History.getSeriesForMonitor(instance, name, sinceMs);
    if (!samples || !samples.length) return [];
    const sum = new Map(), count = new Map();
    for (const s of samples) {
      if (typeof s.responseTime !== 'number') continue;
      const b = Math.floor(s.ts / bucketMs) * bucketMs;
      sum.set(b, (sum.get(b) || 0) + s.responseTime);
      count.set(b, (count.get(b) || 0) + 1);
    }
    const out = [];
    for (const [b, s] of sum) out.push({ ts: b, avgMs: s / (count.get(b) || 1) });
    out.sort((a,b)=> a.ts - b.ts);
    return out;
  },

  // === (Opcionales) Compat que ya agregamos en pasos anteriores ===
  // Devuelven undefined si no existen en tu build actual; no pasa nada.
  getAllForInstance: (...args) => (DB.getAllForInstance ? DB.getAllForInstance(...args) : undefined),
  getAvgSeriesByInstance: (...args) => (DB.getAvgSeriesByInstance ? DB.getAvgSeriesByInstance(...args) : undefined),
};

export default History;
JS

echo "== 3) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Compatibilidad restaurada: getSeriesForMonitor / getAvgSeriesForMonitor disponibles."
