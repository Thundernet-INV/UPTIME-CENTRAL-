#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
HIST="$ROOT/src/historyEngine.js"
OVL="$ROOT/src/components/OverlayChart.jsx"

ts=$(date +%Y%m%d_%H%M%S)
[ -f "$HIST" ] && cp "$HIST" "$HIST.bak_$ts" || true
[ -f "$OVL" ]  && cp "$OVL"  "$OVL.bak_$ts"  || true

echo "== 1) historyEngine.js: puntos 'array-like' (compat [x,y] y {x,y}) =="
cat > "$HIST" <<'JS'
import Mem from './historyMem';
import DB from './historyDB';

/** Devuelve un punto 'array-like':
 *   p = [ts, sec]; p.ts=ts; p.x=ts; p.y=sec; p.value=sec; p.sec=sec; p.ms=ms; p.avgMs=ms; p.xy=[ts,sec];
 *   => Compatible con charts que esperan tuplas [x,y] o props {x,y}
 */
function mkPoint(ts, ms){
  const sec = (typeof ms === 'number') ? (ms/1000) : null;
  const p = [ts, sec];
  p.ts = ts;
  p.x  = ts;
  p.y  = sec;
  p.value = sec;
  p.sec = sec;
  p.ms  = ms;
  p.avgMs = ms;
  p.xy = [ts, sec];
  return p;
}

const History = {
  addSnapshot(monitors) {
    try { Mem.addSnapshots?.(monitors); } catch {}
    try { DB.addSnapshots?.(monitors); DB.pruneOlderThanDays?.(7); } catch {}
    try { if (typeof window !== 'undefined') window.__histLastAddTs = Date.now(); } catch {}
  },

  async getSeriesForMonitor(instance, name, sinceMs = 15*60*1000) {
    try {
      const mem = Mem.getSeriesForMonitor?.(instance, name, sinceMs) || [];
      if (mem.length) {
        const out = mem.map(r => mkPoint(r.ts, r.ms));
        console.log('[HIST] getSeriesForMonitor(mem)', instance, name, '->', out.length);
        return out;
      }
      const key = `${instance}::${name||''}`;
      const rows = await (DB.getSeriesFor ? DB.getSeriesFor(key, sinceMs) : Promise.resolve([]));
      const out = (rows||[])
        .filter(r => typeof r.responseTime === 'number')
        .map(r => mkPoint(r.ts, r.responseTime));
      console.log('[HIST] getSeriesForMonitor(db)', instance, name, '->', out.length);
      return out;
    } catch (e) {
      console.error('[HIST] getSeriesForMonitor error', e);
      return [];
    }
  },

  async getAvgSeriesForMonitor(instance, name, sinceMs = 24*3600*1000, bucketMs = 60*1000) {
    try {
      const base = await this.getSeriesForMonitor(instance, name, sinceMs);
      if (!base.length) return [];
      const sum = new Map(), count = new Map();
      for (const s of base) {
        const ms = (typeof s.ms === 'number') ? s.ms : (s[1]*1000);
        const b = Math.floor(s.ts / bucketMs) * bucketMs;
        sum.set(b, (sum.get(b) || 0) + ms);
        count.set(b, (count.get(b) || 0) + 1);
      }
      const out = [];
      for (const [b, s] of sum) out.push(mkPoint(b, s / (count.get(b) || 1)));
      out.sort((a,b)=> a.ts - b.ts);
      console.log('[HIST] getAvgSeriesForMonitor', instance, name, '->', out.length);
      return out;
    } catch (e) {
      console.error('[HIST] getAvgSeriesForMonitor error', e);
      return [];
    }
  },

  async getAllForInstance(instance, sinceMs = 15*60*1000) {
    try {
      const objMem = Mem.getAllForInstance?.(instance, sinceMs);
      if (objMem && Object.keys(objMem).length) {
        const ofmt = {};
        for (const [name, arr] of Object.entries(objMem)) ofmt[name] = arr.map(r => mkPoint(r.ts, r.ms));
        const total = Object.values(ofmt).reduce((n,a)=>n+a.length,0);
        console.log('[HIST] getAllForInstance(mem)', instance, 'series:', Object.keys(ofmt).length, 'points:', total);
        return ofmt;
      }
      const objDb = await (DB.getAllForInstance ? DB.getAllForInstance(instance, sinceMs) : Promise.resolve({}));
      const ofmt = {};
      for (const [name, arr] of Object.entries(objDb || {})) {
        ofmt[name] = (arr||[])
          .filter(r => typeof r.responseTime === 'number')
          .map(r => mkPoint(r.ts, r.responseTime));
      }
      const total = Object.values(ofmt).reduce((n,a)=>n+a.length,0);
      console.log('[HIST] getAllForInstance(db)', instance, 'series:', Object.keys(ofmt).length, 'points:', total);
      return ofmt;
    } catch (e) {
      console.error('[HIST] getAllForInstance error', e);
      return {};
    }
  },

  async getAvgSeriesByInstance(instance, sinceMs = 15*60*1000, bucketMs = 60*1000) {
    try {
      const mem = Mem.getAvgSeriesByInstance?.(instance, sinceMs, bucketMs) || [];
      if (mem.length) {
        const out = mem.map(p => mkPoint(p.ts, p.avgMs));
        console.log('[HIST] getAvgSeriesByInstance(mem)', instance, '->', out.length);
        return out;
      }
      const arr = await (DB.getAvgSeriesByInstance ? DB.getAvgSeriesByInstance(instance, sinceMs, bucketMs) : Promise.resolve([]));
      const out = (arr||[]).map(p => mkPoint(p.ts, p.avgMs));
      console.log('[HIST] getAvgSeriesByInstance(db)', instance, '->', out.length);
      return out;
    } catch (e) {
      console.error('[HIST] getAvgSeriesByInstance error', e);
      return [];
    }
  },

  debugInfo() {
    try { return Mem.debugInfo?.(); } catch { return {}; }
  },
};

// Exponer para consola
try { if (typeof window !== 'undefined') window.__hist = History; } catch {}

export default History;
JS

echo "== 2) OverlayChart.jsx: mantener visible salvo que el usuario lo oculte (y recordar en localStorage) =="
cat > "$OVL" <<'JSX'
import React, { useEffect, useState } from "react";

export default function OverlayChart({ instance, minutes=15, height=180 }) {
  const [pts, setPts] = useState([]);
  const [hidden, setHidden] = useState(false);

  useEffect(() => {
    try { setHidden(localStorage.getItem('overlay_hidden') === '1'); } catch {}
  }, []);

  useEffect(() => {
    let alive = true;
    async function load() {
      try {
        if (!window.__hist) return;
        const arr = await window.__hist.getAvgSeriesByInstance(instance, minutes*60*1000);
        const map = (arr||[]).map(p => {
          // p es array-like: [x, y] y además tiene .ms
          const x  = p.x ?? p.ts ?? p[0];
          const ms = (typeof p.ms === 'number') ? p.ms :
                     (typeof p.avgMs === 'number') ? p.avgMs :
                     (typeof p[1] === 'number') ? p[1]*1000 :
                     (typeof p.y === 'number') ? p.y*1000 :
                     (typeof p.sec === 'number') ? p.sec*1000 : null;
          return (x && ms!=null) ? { x, ms } : null;
        }).filter(Boolean);
        if (alive) setPts(map);
      } catch {}
    }
    load();
    const t = setInterval(load, 5000);
    return () => { alive = false; clearInterval(t); };
  }, [instance, minutes]);

  if (hidden || pts.length < 2) return null;

  // Escala
  const W = Math.min(Math.max(520, window.innerWidth - 260), 1200);
  const H = height;
  const pad = { l: 48, r: 10, t: 10, b: 24 };
  const w = W - pad.l - pad.r;
  const h = H - pad.t - pad.b;

  const xs = pts.map(p => p.x);
  const ys = pts.map(p => p.ms);
  const minX = Math.min(...xs), maxX = Math.max(...xs);
  const minY = 0, maxY = Math.max(...ys, 1000);
  const sx = (x) => pad.l + (w * (x - minX)) / Math.max(1, maxX - minX);
  const sy = (y) => pad.t + (h * (1 - (y - minY) / Math.max(1, maxY - minY)));
  const pathD = pts.slice().sort((a,b)=>a.x-b.x).map((p,i)=> (i===0?`M ${sx(p.x)} ${sy(p.ms)}`:`L ${sx(p.x)} ${sy(p.ms)}`)).join(" ");

  const ticks = [0,250,500,1000,1500,2000,3000].filter(t=>t<=Math.max(maxY,3000));

  return (
    <div style={{ position:"relative", margin:"8px 0 12px 0", border:"1px solid #e5e7eb", borderRadius:8, background:"#fff", padding:8 }}>
      <div style={{ position:"absolute", right:10, top:8, zIndex:2, fontSize:12, color:"#6b7280", display:"flex", gap:8, alignItems:"center" }}>
        <span>Fallback chart (ms): {pts.length} pts</span>
        <button onClick={()=>{ setHidden(true); try{localStorage.setItem('overlay_hidden','1')}catch{}}}
                style={{ border:"1px solid #e5e7eb", borderRadius:6, padding:"2px 6px", background:"#fff", cursor:"pointer" }}>
          Ocultar
        </button>
      </div>
      <svg width={W} height={H} role="img" aria-label="overlay-chart">
        <line x1={pad.l} y1={H-pad.b} x2={W-pad.r} y2={H-pad.b} stroke="#dadde1"/>
        <line x1={pad.l} y1={pad.t} x2={pad.l} y2={H-pad.b} stroke="#dadde1"/>
        {ticks.map((t,i)=>(<g key={i}><line x1={pad.l-4} y1={sy(t)} x2={pad.l} y2={sy(t)} stroke="#9ca3af"/><text x={pad.l-8} y={sy(t)+4} fontSize="10" textAnchor="end" fill="#6b7280">{t} ms</text></g>))}
        <path d={pathD} fill="none" stroke="#3b82f6" strokeWidth="2"/>
      </svg>
    </div>
  );
}
JSX

echo "== 3) Build & Deploy =="
cd "$ROOT"
npm run build
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ Chart shape compatible ([x,y] y {x,y}) y fallback persistente listo."
