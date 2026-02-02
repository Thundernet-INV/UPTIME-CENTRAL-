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
