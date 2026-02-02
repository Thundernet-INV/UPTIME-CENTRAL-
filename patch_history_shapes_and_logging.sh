#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
HDB="$ROOT/src/historyDB.js"
HIST="$ROOT/src/historyEngine.js"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$HDB" ]  && cp "$HDB"  "$HDB.bak_$ts"  || true
[ -f "$HIST" ] && cp "$HIST" "$HIST.bak_$ts" || true

echo "== 1) historyDB.js: motor IndexedDB =="
cat > "$HDB" <<'JS'
// historyDB.js — Snapshots en IndexedDB (retención 7 días) y utilitarios
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
  const req = idx.openCursor();
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

async function getAvgSeriesByInstance(instance, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
  const since = Date.now() - Math.max(0, Number(sinceMs) || 0);
  const sum = new Map(); const count = new Map();
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
        const b = Math.floor(v.ts / bucketMs) * bucketMs;
        sum.set(b, (sum.get(b) || 0) + v.responseTime);
        count.set(b, (count.get(b) || 0) + 1);
      }
      cur.continue();
    };
    req.onerror = () => reject(req.error);
  });
  db.close();
  const out = [];
  for (const [b, s] of sum) out.push({ ts: b, avgMs: s / (count.get(b) || 1) });
  out.sort((a,b)=> a.ts - b.ts);
  return out;
}

export default {
  addSnapshots,
  pruneOlderThanDays,
  getSeriesFor,
  getAllForInstance,
  getAvgSeriesByInstance,
};
JS

echo "== 2) historyEngine.js: formas compatibles (ms + sec + {x,y} + [ts,val]) =="
cat > "$HIST" <<'JS'
import DB from './historyDB';

// Helper: normaliza un punto con múltiples alias (ms y segundos)
function mkPoint(ts, ms){
  const sec = (typeof ms === 'number') ? (ms/1000) : null;
  return {
    ts,
    // valores en segundos (lo que suelen graficar)
    y: sec, value: sec, sec,
    // valores en ms (por si algún lugar lo usa)
    ms, avgMs: ms,
    // par para libs que aceptan tuple
    xy: [ts, sec],
  };
}

const History = {
  // Persistencia + poda (7d)
  addSnapshot(monitors) {
    DB.addSnapshots(monitors).catch(()=>{});
    DB.pruneOlderThanDays(7).catch(()=>{});
  },

  // Serie cruda por monitor
  async getSeriesForMonitor(instance, name, sinceMs = 24*3600*1000) {
    const key = `${instance}::${name || ''}`;
    const rows = await DB.getSeriesFor(key, sinceMs);
    return rows
      .filter(r => typeof r.responseTime === 'number')
      .map(r => mkPoint(r.ts, r.responseTime));
  },

  // Serie promedio por monitor (buckets)
  async getAvgSeriesForMonitor(instance, name, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
    const samples = await History.getSeriesForMonitor(instance, name, sinceMs);
    if (!samples.length) return [];
    const sum = new Map(), count = new Map();
    for (const s of samples) {
      const b = Math.floor(s.ts / bucketMs) * bucketMs;
      const ms = s.ms ?? (s.sec*1000);
      sum.set(b, (sum.get(b) || 0) + ms);
      count.set(b, (count.get(b) || 0) + 1);
    }
    const out = [];
    for (const [b, s] of sum) {
      const avgMs = s / (count.get(b) || 1);
      out.push(mkPoint(b, avgMs));
    }
    out.sort((a,b)=> a.ts - b.ts);
    return out;
  },

  // Objeto { nombreMonitor: muestras[] } para una instancia
  async getAllForInstance(instance, sinceMs = 24*3600*1000) {
    const obj = await DB.getAllForInstance(instance, sinceMs);
    const out = {};
    for (const [name, arr] of Object.entries(obj || {})) {
      out[name] = (arr || [])
        .filter(r => typeof r.responseTime === 'number')
        .map(r => mkPoint(r.ts, r.responseTime));
    }
    return out;
  },

  // Serie promedio por instancia (array)
  async getAvgSeriesByInstance(instance, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
    const arr = await DB.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
    // mapear a forma compatible
    return (arr || []).map(p => mkPoint(p.ts, p.avgMs));
  },
};

export default History;
JS

echo "== 3) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ History compat OK: alias {y,value,sec,ms,avgMs,xy} + persistencia activa."
