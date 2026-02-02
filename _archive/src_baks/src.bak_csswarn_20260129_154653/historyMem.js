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
