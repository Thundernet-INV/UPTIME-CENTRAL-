#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
HDB="$ROOT/src/historyDB.js"
HIST="$ROOT/src/historyEngine.js"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$HDB" ]  && cp "$HDB"  "$HDB.bak_$ts"  || true
[ -f "$HIST" ] && cp "$HIST" "$HIST.bak_$ts" || true

echo "== 1) historyDB.js: IndexedDB + compat: getAllForInstance + getAvgSeriesByInstance =="
cat > "$HDB" <<'JS'
// historyDB.js: snapshots en IndexedDB con funciones de compatibilidad
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

async function addSnapshots(monitors, nowTs = Date.now()) {
  if (!Array.isArray(monitors) || !monitors.length) return;
  const db = await openDB();
  const tx = db.transaction(STORE, 'readwrite');
  const st = tx.objectStore(STORE);
  for (const m of monitors) {
    const rec = {
      ts: nowTs,
      instance: m.instance,
      name: m.info?.monitor_name || '',
      status: (m.latest?.status ?? null),
      responseTime: (m.latest?.responseTime ?? null),
      key: `${m.instance}::${m.info?.monitor_name || ''}`
    };
    st.add(rec);
  }
  await new Promise((res, rej) => { tx.oncomplete=res; tx.onerror=()=>rej(tx.error); });
  db.close();
}

async function pruneOlderThanDays(days=7) {
  const cutoff = Date.now() - days*24*3600*1000;
  const db = await openDB();
  const tx = db.transaction(STORE, 'readwrite');
  const st = tx.objectStore(STORE);
  const idx = st.index('by_ts');
  const req = idx.openCursor(); // recorremos todo y paramos cuando superamos cutoff
  await new Promise((resolve, reject) => {
    req.onsuccess = () => {
      const cur = req.result;
      if (!cur) return resolve();
      if (cur.value.ts < cutoff) {
        st.delete(cur.primaryKey);
        cur.continue();
      } else {
        resolve();
      }
    };
    req.onerror = () => reject(req.error);
  });
  await new Promise((res, rej) => { tx.oncomplete=res; tx.onerror=()=>rej(tx.error); });
  db.close();
}

// Serie por monitor (clave instance::name) en ventana (ms)
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

/**
 * COMPAT 1: getAllForInstance(instance, sinceMs)
 * Devuelve un objeto { [monitor_name]: Array<sample> } con todos los monitores
 * de esa instancia en la ventana dada (por defecto 24h).
 */
async function getAllForInstance(instance, sinceMs = 24*3600*1000) {
  const since = Date.now() - Math.max(0, Number(sinceMs) || 0);
  const outMap = new Map(); // name -> array
  const db = await openDB();
  const tx = db.transaction(STORE, 'readonly');
  const st = tx.objectStore(STORE);
  const idx = st.index('by_ts');
  const req = idx.openCursor(IDBKeyRange.lowerBound(since));
  await new Promise((resolve, reject) => {
    req.onsuccess = () => {
      const cur = req.result;
      if (!cur) return resolve();
      const v = cur.value;
      if (v.instance === instance && v.ts >= since) {
        const arr = outMap.get(v.name) || [];
        arr.push(v);
        outMap.set(v.name, arr);
      }
      cur.continue();
    };
    req.onerror = () => reject(req.error);
  });
  db.close();
  const outObj = {};
  for (const [name, arr] of outMap) outObj[name] = arr;
  return outObj;
}

/**
 * COMPAT 2: getAvgSeriesByInstance(instance, sinceMs, bucketMs?)
 * Devuelve un ARRAY ordenado por ts con promedios de responseTime
 * agregados por "bucket" temporal (por defecto 60s).
 * Formato: [ { ts: <inicio_bucket>, avgMs: <promedio> }, ... ]
 * Esto es lo que suelen consumir las gráficas con .map(...)
 */
async function getAvgSeriesByInstance(instance, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
  const since = Date.now() - Math.max(0, Number(sinceMs) || 0);
  const sum = new Map();   // bucketTs -> suma
  const count = new Map(); // bucketTs -> cantidad
  const db = await openDB();
  const tx = db.transaction(STORE, 'readonly');
  const st = tx.objectStore(STORE);
  const idx = st.index('by_ts');
  const req = idx.openCursor(IDBKeyRange.lowerBound(since));
  await new Promise((resolve, reject) => {
    req.onsuccess = () => {
      const cur = req.result;
      if (!cur) return resolve();
      const v = cur.value;
      if (v.instance === instance && v.ts >= since && typeof v.responseTime === 'number') {
        const bucket = Math.floor(v.ts / bucketMs) * bucketMs;
        sum.set(bucket, (sum.get(bucket) || 0) + v.responseTime);
        count.set(bucket, (count.get(bucket) || 0) + 1);
      }
      cur.continue();
    };
    req.onerror = () => reject(req.error);
  });
  db.close();
  const out = [];
  for (const [bucketTs, s] of sum) {
    const c = count.get(bucketTs) || 1;
    out.push({ ts: bucketTs, avgMs: s / c });
  }
  out.sort((a,b)=> a.ts - b.ts);
  return out;
}

export default {
  addSnapshots,
  pruneOlderThanDays,
  getSeriesFor,
  getAllForInstance,       // compat
  getAvgSeriesByInstance,  // compat
};
JS

echo "== 2) historyEngine.js: expone compat hacia el front =="
cat > "$HIST" <<'JS'
import DB from './historyDB';

const History = {
  addSnapshot(monitors) {
    DB.addSnapshots(monitors).catch(()=>{});
    DB.pruneOlderThanDays(7).catch(()=>{});
  },

  // Serie por monitor (ventana en ms)
  getSeriesFor(instance, name, sinceMs) {
    const key = `${instance}::${name||''}`;
    return DB.getSeriesFor(key, sinceMs);
  },

  // COMPAT: todos los monitores de una instancia (objeto agrupado por nombre)
  getAllForInstance(instance, sinceMs = 24*3600*1000) {
    return DB.getAllForInstance(instance, sinceMs);
  },

  // COMPAT: serie de promedios por instancia (array con {ts, avgMs})
  getAvgSeriesByInstance(instance, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
    return DB.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
  },
};

export default History;
JS

echo "== 3) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Compatibilidad restaurada: getAvgSeriesByInstance disponible como array."
