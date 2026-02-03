#!/bin/sh
# Reaplica UI/funcionalidades + build + deploy con backup previo
set -eu
TS=$(date +%Y%m%d_%H%M%S)

APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DOCROOT="/var/www/uptime8081/dist"
SITE_CONF="/etc/nginx/sites-available/uptime8081.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/uptime8081.conf"
SERVER_IP="10.10.31.31"
PORT="8081"

cd "$APP_DIR"
mkdir -p src/components src/lib public/logos
[ -f src/styles.css ] || touch src/styles.css

echo "== 1) Reaplicando/asegurando componentes y utilidades =="
# --- History engine (snapshots + series por sede/monitor) ---
cat > src/historyEngine.js <<'JS'
// Simple history engine (localStorage) – snapshots de monitores
const KEY = "kuma_history_snapshots_v1";
const MAX = 500;          // ~41' si se hace polling cada 5s
const SPARK_POINTS = 120; // sparkline suave

function load(){ try { return JSON.parse(localStorage.getItem(KEY) || "[]"); } catch { return []; } }
function save(a){ try { localStorage.setItem(KEY, JSON.stringify(a)); } catch {} }
function now(){ return Date.now(); }

function avgLatencyForInstance(monitors, instance) {
  const arr = monitors.filter(m => m.instance === instance)
                      .map(m => m.latest?.responseTime)
                      .filter(v => typeof v === "number" && isFinite(v));
  if (!arr.length) return null;
  return Math.round(arr.reduce((a,b)=>a+b,0)/arr.length);
}
function downCountForInstance(monitors, instance) {
  return monitors.filter(m => m.instance === instance && m.latest?.status === 0).length;
}
function findMonitor(monitors, instance, name) {
  const n = (name||'').toLowerCase().trim();
  return monitors.find(m => m.instance===instance && (m.info?.monitor_name||'').toLowerCase().trim()===n);
}

const History = {
  addSnapshot(monitors) {
    const s = load(); s.push({ t: now(), monitors });
    while (s.length > MAX) s.shift();
    save(s);
  },
  getAvgSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s){ xs.push(snap.t); ys.push(avgLatencyForInstance(snap.monitors, instance)); }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  getDownsSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s){ xs.push(snap.t); ys.push(downCountForInstance(snap.monitors, instance)); }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  getSeriesForMonitor(instance, monitorName, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s) {
      const m = findMonitor(snap.monitors, instance, monitorName);
      xs.push(snap.t);
      ys.push(typeof m?.latest?.responseTime === "number" ? m.latest.responseTime : null);
    }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  getAllForInstance(instance, maxPoints = MAX) {
    const lat = this.getAvgSeriesByInstance(instance, maxPoints);
    const dwn = this.getDownsSeriesByInstance(instance, maxPoints);
    return { lat, dwn };
  }
};
export default History;
JS

# --- Logo util (mapping + clearbit + favicon + iniciales) ---
cat > src/lib/logoUtil.js <<'JS'
export function hostFromUrl(u){ try { return new URL(u).hostname.replace(/^www\./,''); } catch { return ''; } }
export function norm(s=''){ return s.toLowerCase().replace(/\s+/g,'').trim(); }

const MAP = {
  whatsapp:'/logos/whatsapp.svg',
  facebook:'/logos/facebook.svg',
  instagram:'/logos/instagram.svg',
  youtube:'/logos/youtube.svg',
  tiktok:'/logos/tiktok.svg',
  google:'/logos/google.svg',
  microsoft:'/logos/microsoft.svg',
  netflix:'/logos/netflix.svg',
  telegram:'/logos/telegram.svg',
  apple:'/logos/apple.svg',
  iptv:'/logos/iptv.svg',
};

function matchBrand(name, host){
  const n = norm(name), h = norm(host);
  for (const k of Object.keys(MAP)){
    if (n.includes(k) || h.includes(k)) return k;
  }
  return null;
}
export function getLogoCandidates(m){
  const host = hostFromUrl(m?.info?.monitor_url || '');
  const brand = matchBrand(m?.info?.monitor_name||'', host);
  const list = [];
  if (brand) list.push(MAP[brand]);
  if (host)  list.push(`https://logo.clearbit.com/${host}`);
  if (host)  list.push(`https://www.google.com/s2/favicons?domain=${host}&sz=64`);
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

# --- Logo component (clic en logo abre URL; fallback a iniciales) ---
cat > src/components/Logo.jsx <<'JSX'
import React, { useMemo, useState } from "react";
import { getLogoCandidates, initialsFor } from "../lib/logoUtil.js";

export default function Logo({ monitor, size=20, className="k-logo", href }) {
  const candidates = useMemo(()=>getLogoCandidates(monitor), [monitor]);
  const [idx, setIdx] = useState(0);
  const Img = (
    <img className={className} style={{width:size,height:size}}
         src={candidates[idx] || ""} alt=""
         onError={()=> setIdx(i => i+1)} />
  );
  const Fallback = (
    <div className={className+" k-logo--fallback"} style={{width:size,height:size}}>
      {initialsFor(monitor)}
    </div>
  );
  const content = (idx < candidates.length) ? Img : Fallback;
  if (href) return <a href={href} target="_blank" rel="noopener noreferrer" onClick={(e)=>e.stopPropagation()}>{content}</a>;
  return content;
}
JSX

# --- Sparkline (Chart.js sin adapter) ---
cat > src/components/Sparkline.jsx <<'JSX'
import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import { Chart as ChartJS, LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Filler } from "chart.js";
ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Filler);

export default function Sparkline({ points, color="#2563eb", height=42 }) {
  const labels = useMemo(() => (points?.t ?? []).map((_,i)=>i), [points]);
  const data = useMemo(()=>({
    labels,
    datasets:[{
      data: points?.v ?? [],
      borderColor: color,
      backgroundColor: (ctx)=>{
        const chart = ctx.chart; if (!chart?.chartArea) return color+"22";
        const { ctx: c, chartArea } = chart;
        const g = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
        g.addColorStop(0, color+"40"); g.addColorStop(1, color+"00"); return g;
      },
      tension:.35, borderWidth:2, pointRadius:0, fill:true, spanGaps:true
    }]
  }), [labels, points, color]);
  const options={responsive:true,maintainAspectRatio:false,scales:{x:{display:false},y:{display:false}},plugins:{legend:{display:false},tooltip:{enabled:false}}};
  return (<div style={{height}}><Line data={data} options={options}/></div>);
}
JSX

# --- HistoryChart (eje temporal + modo monitor o sede) ---
cat > src/components/HistoryChart.jsx <<'JSX'
import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import { Chart as ChartJS, LineElement, PointElement, LinearScale, TimeScale, Tooltip, Legend, Filler } from "chart.js";
import 'chartjs-adapter-date-fns'; import { es } from 'date-fns/locale';
ChartJS.register(LineElement, PointElement, LinearScale, TimeScale, Tooltip, Legend, Filler);

export default function HistoryChart({ mode="instance", series, seriesMon, title="Latencia (ms)", h=260 }) {
  const labels = useMemo(()=> mode==="monitor" ? (seriesMon?.t ?? []) : (series?.lat?.t ?? []), [mode, series, seriesMon]);
  const data = useMemo(()=> {
    if (mode==="monitor"){
      return { labels, datasets:[{ label:title, data:seriesMon?.v ?? [], yAxisID:"y",
        borderColor:"#3b82f6", backgroundColor:"#3b82f622", tension:.35, pointRadius:0, fill:true, spanGaps:true }]};
    }
    return { labels, datasets:[
      { label:"Prom (ms)", data:series?.lat?.v ?? [], yAxisID:"y", borderColor:"#3b82f6", backgroundColor:"#3b82f622", tension:.35, pointRadius:0, fill:true, spanGaps:true },
      { label:"Downs", data:series?.dwn?.v ?? [], yAxisID:"y1", borderColor:"#ef4444", backgroundColor:"#ef444422", tension:.2, pointRadius:0, fill:true, spanGaps:true }
    ]};
  }, [mode, labels, series, seriesMon, title]);

  const options = {
    responsive:true, maintainAspectRatio:false,
    scales:{
      x:{ type:'time', time:{ unit:'minute', displayFormats:{minute:'HH:mm',second:'HH:mm:ss'}, tooltipFormat:'HH:mm:ss' },
          ticks:{ autoSkip:true, maxTicksLimit:8 }, adapters:{ date:{ locale: es } }, grid:{ color:'#e5e7eb' } },
      y:{ position:'left', grid:{ color:'#e5e7eb' } },
      y1:{ position:'right', grid:{ drawOnChartArea:false } }
    }, plugins:{ legend:{ position:'bottom' }, tooltip:{ enabled:true } }
  };
  return <div style={{height:h}}><Line data={data} options={options}/></div>;
}
JSX

# --- MonitorCard (card de servicio con logo clickeable + foco) ---
cat > src/components/MonitorCard.jsx <<'JSX'
import React from "react";
import Logo from "./Logo.jsx";
import Sparkline from "./Sparkline.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

export default function MonitorCard({ monitor, onHide, onUnhide, series, onFocus }) {
  const stUp = monitor?.latest?.status === 1;
  const color = stUp ? "#16a34a" : "#dc2626";
  const statusText = stUp ? "UP" : "DOWN";
  const host = hostFromUrl(monitor?.info?.monitor_url || "");
  const latency = (typeof monitor?.latest?.responseTime === "number") ? `${monitor.latest.responseTime} ms` : "—";
  const href = monitor?.info?.monitor_url || "";
  function stop(e){ e.stopPropagation(); }
  return (
    <div className="svc-card" onClick={()=>onFocus?.(monitor?.info?.monitor_name)}>
      <div className="svc-head">
        <Logo monitor={monitor} href={href} size={22} />
        <div className="svc-titles">
          <div className="svc-name">{monitor?.info?.monitor_name}</div>
          <div className="svc-sub">{host || (monitor?.info?.monitor_url || "")}</div>
        </div>
        <span className="svc-badge" style={{ background: color }}>{statusText}</span>
      </div>
      <div className="svc-body">
        <div className="svc-lat"><span className="svc-lab">Latencia:</span> <strong>{latency}</strong></div>
        <div className="svc-spark"><Sparkline points={series} color={color} height={42} /></div>
      </div>
      <div className="svc-actions" onClick={stop}>
        <button className="k-btn k-btn--danger" onClick={()=>onHide?.(monitor.instance, monitor.info?.monitor_name)}>Ocultar</button>
        <button className="k-btn k-btn--ghost" onClick={()=>onUnhide?.(monitor.instance, monitor.info?.monitor_name)}>Mostrar</button>
      </div>
    </div>
  );
}
JSX

# --- InstanceDetail (Tabla/Grilla + foco en gráfico por servicio) ---
cat > src/components/InstanceDetail.jsx <<'JSX'
import React, { useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx";
import Logo from "./Logo.jsx";
import MonitorCard from "./MonitorCard.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

export default function InstanceDetail({
  instanceName, monitorsAll=[], hiddenSet=new Set(),
  onHide, onUnhide, onHideAll, onUnhideAll
}) {
  const [mode, setMode] = useState("table"); // table | grid
  const [focus, setFocus] = useState(null);  // monitor_name | null
  const group = useMemo(()=>monitorsAll.filter(m=>m.instance===instanceName), [monitorsAll, instanceName]);
  const seriesInstance = useMemo(()=>History.getAllForInstance(instanceName), [instanceName, monitorsAll.length]);
  const chartMode = focus ? "monitor" : "instance";
  const chartSeries = focus ? History.getSeriesForMonitor(instanceName, focus) : seriesInstance;

  return (
    <div>
      <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:8}}>
        <button className="k-btn k-btn--primary" onClick={()=>window.history.back()}>← Volver</button>
        <h2 style={{margin:0}}>{instanceName}</h2>
        <div style={{ marginLeft:'auto', display:'flex', gap:6 }}>
          <button type="button" className={`btn tab ${mode==="table"?"active":""}`} aria-pressed={mode==="table"} onClick={()=>setMode("table")}>Tabla</button>
          <button type="button" className={`btn tab ${mode==="grid"?"active":""}`}  aria-pressed={mode==="grid"}  onClick={()=>setMode("grid")}>Grilla</button>
        </div>
      </div>

      <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:6}}>
        {focus
          ? <div className="k-chip">Mostrando: <strong>{focus}</strong> <button className="k-btn k-btn--ghost" style={{marginLeft:8}} onClick={()=>setFocus(null)}>Ver sede</button></div>
          : <div className="k-chip k-chip--muted">Mostrando: <strong>Promedio de la sede</strong></div>
        }
      </div>

      {chartMode==="monitor"
        ? <HistoryChart mode="monitor" seriesMon={chartSeries} title={focus||"Latencia (ms)"} />
        : <HistoryChart mode="instance" series={chartSeries} />
      }

      <div style={{ marginTop: 12 }}>
        <button className="k-btn k-btn--danger" onClick={()=>onHideAll?.(instanceName)} style={{ marginRight: 8 }}>Ocultar todos</button>
        <button className="k-btn k-btn--ghost"  onClick={()=>onUnhideAll?.(instanceName)}>Mostrar todos</button>
      </div>

      {mode==="table" ? (
        <>
          <h3 style={{ marginTop: 20 }}>Servicios</h3>
          <table className="k-table">
            <thead><tr><th>Servicio</th><th>Estado</th><th>Latencia</th><th>Tendencia</th><th>Acciones</th></tr></thead>
            <tbody>
              {group.map((m,i)=>{
                const st = m.latest?.status === 1 ? "UP" : "DOWN";
                const icon = st==="UP" ? "🟢" : "🔴";
                const lat = (typeof m.latest?.responseTime === 'number') ? `${m.latest.responseTime} ms` : "—";
                const host = hostFromUrl(m.info?.monitor_url || '');
                const seriesMon = History.getSeriesForMonitor(instanceName, m.info?.monitor_name);
                return (
                  <tr key={i}>
                    <td className="k-cell-service" onClick={()=>setFocus(m.info?.monitor_name)} style={{cursor:'pointer'}}>
                      <Logo monitor={m} size={18} href={m.info?.monitor_url || ""} />
                      <div className="k-service-text">
                        <div className="k-service-name">{m.info?.monitor_name}</div>
                        <div className="k-service-sub">{host || (m.info?.monitor_url||'')}</div>
                      </div>
                    </td>
                    <td style={{ fontWeight:'bold', color: st==="UP" ? "#16a34a" : "#dc2626" }}>{icon} {st}</td>
                    <td>{lat}</td>
                    <td style={{minWidth:120}}><Sparkline points={seriesMon} color={st==="UP" ? "#16a34a" : "#dc2626"} /></td>
                    <td>
                      <button className="k-btn k-btn--ghost" onClick={()=>onHide?.(m.instance, m.info?.monitor_name)}>Ocultar</button>
                      <button className="k-btn k-btn--ghost" style={{marginLeft:6}} onClick={()=>onUnhide?.(m.instance, m.info?.monitor_name)}>Mostrar</button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </>
      ) : (
        <>
          <h3 style={{ marginTop: 20 }}>Servicios</h3>
          <div className="k-grid-services">
            {group.map((m,i)=>{
              const seriesMon = History.getSeriesForMonitor(instanceName, m.info?.monitor_name);
              return <MonitorCard key={i} monitor={m} series={seriesMon} onHide={onHide} onUnhide={onUnhide} onFocus={(name)=>setFocus(name)} />;
            })}
          </div>
        </>
      )}
    </div>
  );
}
JSX

# --- Filters: “Solo DOWN” conectado a status ---
cat > src/components/Filters.jsx <<'JSX'
import React from "react";
export default function Filters({ monitors, value, onChange }) {
  function set(k,v){ onChange({ ...value, [k]: v }); }
  function toggleDown(e){ set("status", e.target.checked ? "down" : "all"); }
  return (
    <div className="filters">
      <select value={value.instance} onChange={(e)=>set("instance", e.target.value)}>
        <option value="">Todas las sedes</option>
        {[...new Set(monitors.map(m=>m.instance))].sort().map(n=><option key={n} value={n}>{n}</option>)}
      </select>
      <select value={value.type} onChange={(e)=>set("type", e.target.value)}>
        <option value="">Todos los tipos</option>
        {[...new Set(monitors.map(m=>m.info?.monitor_type))].sort().map(t=><option key={t} value={t}>{t}</option>)}
      </select>
      <input type="text" placeholder="Buscar..." value={value.q} onChange={(e)=>set("q", e.target.value)} />
      <label style={{ marginLeft: 12 }}>
        <input type="checkbox" checked={value.status==="down"} onChange={toggleDown} />{" "}Solo DOWN
      </label>
    </div>
  );
}
JSX

# --- Estilos clave (si no estaban) ---
grep -q "k-grid-services" src/styles.css || cat >> src/styles.css <<'CSS'

/* Indicador de foco sobre la gráfica */
.k-chip{display:inline-flex;align-items:center;gap:6px;background:#eef2ff;color:#1f2937;border:1px solid #c7d2fe;padding:4px 8px;border-radius:999px;font-size:12px;}
.k-chip--muted{background:#f3f4f6;border-color:#e5e7eb;}

/* Grilla de servicios */
.k-grid-services{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px;margin-top:10px;}
.svc-card{border:1px solid #e5e7eb;border-radius:12px;background:#fff;padding:12px;display:flex;flex-direction:column;gap:8px;cursor:pointer;}
.svc-card:hover{box-shadow:0 4px 12px rgba(0,0,0,.08);}
.svc-head{display:grid;grid-template-columns:22px 1fr auto;gap:10px;align-items:center;}
.svc-titles{display:flex;flex-direction:column;}
.svc-name{font-weight:700;}
.svc-sub{font-size:12px;color:#6b7280;}
.svc-badge{color:#fff;font-size:12px;font-weight:600;padding:3px 8px;border-radius:999px;}
.svc-body{display:grid;grid-template-columns:1fr 1fr;align-items:center;gap:6px;}
.svc-lab{color:#6b7280;font-size:12px;}
.svc-spark{min-width:120px;}
.svc-actions{display:flex;gap:8px;margin-top:4px;}
.k-logo{width:18px;height:18px;border-radius:4px;border:1px solid #e5e7eb;background:#fff;object-fit:contain;}
.k-logo--fallback{display:flex;align-items:center;justify-content:center;font-size:10px;background:#e5e7eb;color:#374151;}
.k-table{width:100%;border-collapse:collapse;margin-top:12px;}
.k-table th{text-align:left;padding:8px;background:#f3f4f6;border-bottom:2px solid #e5e7eb;font-size:14px;}
.k-table td{padding:8px;border-bottom:1px solid #e5e7eb;font-size:14px;vertical-align:middle;}
.k-cell-service{display:flex;align-items:center;gap:10px;}
CSS

echo "== 2) Dependencias de gráficos =="
npm i chart.js react-chartjs-2 chartjs-adapter-date-fns --save >/dev/null 2>&1 || true

echo "== 3) Build de producción =="
npm run build

echo "== 4) BACKUP de destino =="
if [ -d "$DOCROOT" ]; then
  sudo tar -czf "/var/www/uptime8081/dist.backup_${TS}.tgz" -C "/var/www/uptime8081" "dist" || true
  echo "Backup guardado en /var/www/uptime8081/dist.backup_${TS}.tgz"
fi

echo "== 5) Deploy con --delete =="
sudo mkdir -p "$DOCROOT"
sudo rsync -av --delete "$APP_DIR/dist/" "$DOCROOT/"

echo "== 6) Nginx 8081 (SPA + caché correcta) =="
sudo tee "$SITE_CONF" >/dev/null <<NGX
server {
  listen $PORT;
  server_name $SERVER_IP;

  root $DOCROOT;
  index index.html;

  # HTML sin caché (siempre fresco)
  location = /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    expires -1;
    try_files \$uri =404;
  }
  # SPA routing
  location / {
    try_files \$uri \$uri/ /index.html;
  }
  # Assets con hash: cache largo e inmutable
  location /assets/ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
    try_files \$uri =404;
  }
}
NGX
sudo ln -sf "$SITE_CONF" "$SITE_ENABLED"
sudo nginx -t && sudo systemctl reload nginx

echo "=================================================="
echo "✔ Producción lista en: http://$SERVER_IP:$PORT/"
echo "   (si no ves cambios, prueba Ctrl+F5 o incógnito)"
echo "   Backup del destino: /var/www/uptime8081/dist.backup_${TS}.tgz"
echo "=================================================="
