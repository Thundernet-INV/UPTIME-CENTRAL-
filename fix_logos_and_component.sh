#!/bin/sh
set -eu
TS=$(date +%Y%m%d%H%M%S)

mkdir -p public/logos src/components src/lib

echo "== Backup de archivos a modificar (si existen) =="
[ -f src/lib/logoUtil.js ] && cp src/lib/logoUtil.js src/lib/logoUtil.js.bak.$TS
[ -f src/components/Logo.jsx ] && cp src/components/Logo.jsx src/components/Logo.jsx.bak.$TS
[ -f src/components/InstanceDetail.jsx ] && cp src/components/InstanceDetail.jsx src/components/InstanceDetail.jsx.bak.$TS

echo "== Reescribiendo SVGs con xmlns correcto =="
# instagram
cat > public/logos/instagram.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="g" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#F58529"/>
      <stop offset="50%" stop-color="#DD2A7B"/>
      <stop offset="100%" stop-color="#8134AF"/>
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="56" fill="url(#g)"/>
  <circle cx="128" cy="128" r="50" fill="none" stroke="#FFF" stroke-width="20"/>
  <circle cx="185" cy="71" r="20" fill="#FFF"/>
</svg>
SVG

# microsoft
cat > public/logos/microsoft.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256">
  <rect width="256" height="256" fill="#fff"/>
  <rect x="20"  y="20"  width="100" height="100" fill="#F25022"/>
  <rect x="136" y="20"  width="100" height="100" fill="#7FBA00"/>
  <rect x="20"  y="136" width="100" height="100" fill="#00A4EF"/>
  <rect x="136" y="136" width="100" height="100" fill="#FFB900"/>
</svg>
SVG

# telegram
cat > public/logos/telegram.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="56" fill="#0088CC"/>
  <path fill="#fff" d="M203 67L40 121c-6 2-7 10-1 13l36 17 14 45c2 6 10 8 14 3l21-20 36 26c5 4 12 1 14-5l33-118c2-7-4-12-11-10z"/>
</svg>
SVG

# netflix
cat > public/logos/netflix.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256">
  <rect width="256" height="256" fill="#000"/>
  <path fill="#E50914" d="M96 40v176l64-40V0z"/>
</svg>
SVG

echo "== logoUtil.js con cadena de candidatas (local -> clearbit -> favicon) =="
cat > src/lib/logoUtil.js <<'JS'
export function hostFromUrl(u){
  try { return new URL(u).hostname.replace(/^www\./,''); } catch { return ''; }
}
export function norm(s=''){ return s.toLowerCase().replace(/\s+/g,'').trim(); }

const MAP = {
  whatsapp: '/logos/whatsapp.svg',
  facebook: '/logos/facebook.svg',
  instagram: '/logos/instagram.svg',
  youtube: '/logos/youtube.svg',
  tiktok: '/logos/tiktok.svg',
  google: '/logos/google.svg',
  microsoft: '/logos/microsoft.svg',
  netflix: '/logos/netflix.svg',
  telegram: '/logos/telegram.svg',
  apple: '/logos/apple.svg',
  iptv: '/logos/iptv.svg',
};

function matchBrand(name, host){
  const n = norm(name), h = norm(host);
  for (const key of Object.keys(MAP)){
    if (n.includes(key) || h.includes(key)) return key;
  }
  return null;
}

export function getLogoCandidates(m){
  const name = m?.info?.monitor_name || '';
  const host = hostFromUrl(m?.info?.monitor_url || '');
  const list = [];
  const brand = matchBrand(name, host);
  if (brand) list.push(MAP[brand]); // 1) local svg
  if (host)  list.push(`https://logo.clearbit.com/${host}`); // 2) clearbit
  if (host)  list.push(`https://www.google.com/s2/favicons?domain=${host}&sz=64`); // 3) favicon google
  // dedup
  return list.filter((v,i,a)=>v && a.indexOf(v)===i);
}

export function initialsFor(m){
  const n = (m?.info?.monitor_name || '').trim();
  if (!n) return '?';
  const parts = n.split(/\s+/);
  const ini = (parts[0][0]||'').toUpperCase() + (parts[1]?.[0]||'').toUpperCase();
  return ini || n[0].toUpperCase();
}
JS

echo "== Componente Logo.jsx (prueba candidatas y hace fallback a iniciales) =="
cat > src/components/Logo.jsx <<'JSX'
import React, { useMemo, useState } from "react";
import { getLogoCandidates, initialsFor } from "../lib/logoUtil.js";

export default function Logo({ monitor, size=18, className="k-logo" }){
  const candidates = useMemo(()=>getLogoCandidates(monitor), [monitor]);
  const [idx, setIdx] = useState(0);

  if (!candidates.length) {
    return <div className={className+" k-logo--fallback"} style={{width:size, height:size}}>
      {initialsFor(monitor)}
    </div>;
  }

  const src = candidates[Math.min(idx, candidates.length-1)];
  return (
    <img
      className={className}
      style={{width:size, height:size}}
      src={src}
      alt=""
      onError={()=> setIdx(i => i+1 < candidates.length ? i+1 : i+1)} // al agotar, idx>len -> cae en fallback
      onLoad={()=>{}}
    />
  );
}
JSX

echo "== Actualizando InstanceDetail.jsx para usar <Logo /> =="
cat > src/components/InstanceDetail.jsx <<'JSX'
import React, { useMemo } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx";
import Logo from "./Logo.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide, onUnhide, onHideAll, onUnhideAll
}) {
  const group = useMemo(
    () => monitorsAll.filter(m => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  const series = useMemo(
    () => History.getAllForInstance(instanceName),
    [instanceName, monitorsAll.length]
  );

  return (
    <div>
      <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:8}}>
        <button className="k-btn k-btn--primary" onClick={() => window.history.back()}>← Volver</button>
        <h2 style={{margin:0}}>{instanceName}</h2>
      </div>

      <HistoryChart series={series} />

      <div style={{ marginTop: 12 }}>
        <button className="k-btn k-btn--danger" onClick={() => onHideAll?.(instanceName)} style={{ marginRight: 8 }}>
          Ocultar todos
        </button>
        <button className="k-btn k-btn--ghost" onClick={() => onUnhideAll?.(instanceName)}>
          Mostrar todos
        </button>
      </div>

      <h3 style={{ marginTop: 20 }}>Servicios</h3>
      <table className="k-table">
        <thead>
          <tr>
            <th>Servicio</th>
            <th>Estado</th>
            <th>Latencia</th>
            <th>Tendencia</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          {group.map((m, i) => {
            const st = m.latest?.status === 1 ? "UP" : "DOWN";
            const icon = st === "UP" ? "🟢" : "🔴";
            const lat = (typeof m.latest?.responseTime === 'number') ? `${m.latest.responseTime} ms` : "—";
            const host = hostFromUrl(m.info?.monitor_url || '');
            const seriesMon = History.getSeriesForMonitor(instanceName, m.info?.monitor_name);
            return (
              <tr key={i}>
                <td className="k-cell-service">
                  <Logo monitor={m} size={18} />
                  <div className="k-service-text">
                    <div className="k-service-name">{m.info?.monitor_name}</div>
                    <div className="k-service-sub">{host || (m.info?.monitor_url||'')}</div>
                  </div>
                </td>
                <td style={{ fontWeight: "bold", color: st === "UP" ? "#16a34a" : "#dc2626" }}>
                  {icon} {st}
                </td>
                <td>{lat}</td>
                <td style={{minWidth:120}}>
                  <Sparkline points={seriesMon} color={st==="UP" ? "#16a34a" : "#dc2626"} />
                </td>
                <td>
                  <button className="k-btn k-btn--ghost" onClick={() => onHide?.(m.instance, m.info?.monitor_name)}>
                    Ocultar
                  </button>
                  <button
                    className="k-btn k-btn--ghost"
                    style={{ marginLeft: 6 }}
                    onClick={() => onUnhide?.(m.instance, m.info?.monitor_name)}
                  >
                    Mostrar
                  </button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
JSX

echo "== Listo. Si estabas con Vite, refresca con Ctrl+F5 para limpiar caché de imágenes. =="
