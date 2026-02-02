#!/bin/sh
# Restaura TODO el front (componentes, estilos, logos, historia, alertas),
# instala deps, compila y despliega en producción (NGINX: 10.10.31.31:8081)
# con proxy /api hacia BACKEND (por defecto http://10.10.31.31:80).

set -eu
TS=$(date +%Y%m%d_%H%M%S)

APP_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
DOCROOT="/var/www/uptime8081/dist"
SITE_CONF="/etc/nginx/sites-available/uptime8081.conf"
SITE_ENABLED="/etc/nginx/sites-enabled/uptime8081.conf"
SERVER_IP="10.10.31.31"
PORT="8081"
BACKEND="${BACKEND:-http://10.10.31.31:80}"

cd "$APP_DIR"
mkdir -p src/components src/lib public/logos
[ -f src/styles.css ] || touch src/styles.css

echo "== (1/8) Frontend: utilidades y motor histórico =="

# historyEngine.js (snapshots + series por sede/monitor)
cat > src/historyEngine.js <<'JS'
// Simple history engine (localStorage) – snapshots de monitores
const KEY = "kuma_history_snapshots_v1";
const MAX = 500;          // ~41' si polling=5s
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

# logoUtil.js (map + clearbit + favicon + iniciales)
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
  if (brand) list.push(MAP[brand]);                          // local SVG
  if (host)  list.push(`https://logo.clearbit.com/${host}`); // clearbit
  if (host)  list.push(`https://www.google.com/s2/favicons?domain=${host}&sz=64`); // favicon
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

echo "== (2/8) Componentes base (Logo, Sparkline, HistoryChart, Alerts) =="

# Logo (clic abre href, fallback a iniciales)
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

# Sparkline (CategoryScale — sin adapter)
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
  const options={responsive:true, maintainAspectRatio:false, scales:{x:{display:false}, y:{display:false}}, plugins:{legend:{display:false}, tooltip:{enabled:false}}};
  return (<div style={{height}}><Line data={data} options={options}/></div>);
}
JSX

# HistoryChart (tiempo + sede/monitor)
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
  const options={responsive:true,maintainAspectRatio:false,
    scales:{ x:{type:'time',time:{unit:'minute',displayFormats:{minute:'HH:mm',second:'HH:mm:ss'},tooltipFormat:'HH:mm:ss'},ticks:{autoSkip:true,maxTicksLimit:8},adapters:{date:{locale:es}},grid:{color:'#e5e7eb'}},
             y:{position:'left',grid:{color:'#e5e7eb'}}, y1:{position:'right',grid:{drawOnChartArea:false}} },
    plugins:{ legend:{position:'bottom'}, tooltip:{enabled:true} } };
  return <div style={{height:h}}><Line data={data} options={options}/></div>;
}
JSX

# AlertsBanner (auto-limpieza por tiempo y por retorno a UP)
cat > src/components/AlertsBanner.jsx <<'JSX'
import React, { useEffect } from "react";
export default function AlertsBanner({ alerts, onClose, autoCloseMs = 10000 }) {
  useEffect(() => {
    const timers = [];
    for (const a of alerts) {
      if (!a.ts) continue;
      const left = Math.max(0, autoCloseMs - (Date.now() - a.ts));
      timers.push(setTimeout(() => onClose?.(a.id), left));
    }
    return () => timers.forEach(clearTimeout);
  }, [alerts, autoCloseMs, onClose]);
  if (!alerts?.length) return null;
  return (
    <div className="k-alerts">
      {alerts.map(a => (
        <div key={a.id} className="k-alert k-alert--danger">
          <div><strong>DOWN:</strong> {a.instance} — {a.name}</div>
          <button className="k-alert__close" onClick={()=>onClose?.(a.id)}>✕</button>
        </div>
      ))}
    </div>
  );
}
JSX

echo "== (3/8) Cards de sede y servicios (clicables) =="

# MonitorCard (card de servicio) – logo clickeable + sparkline + foco
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

# ServiceCard (sede) – click en toda la card abre sede, botones no propagan
cat > src/components/ServiceCard.jsx <<'JSX'
import React from "react";
import Sparkline from "./Sparkline.jsx";
export default function ServiceCard({ sede, data, onHideAll, onUnhideAll, onOpen, spark }) {
  const { up = 0, down = 0, total = 0, avg = null } = data ?? {};
  const hasIncidents = down > 0;
  function clickCard(){ onOpen?.(sede); }
  function stop(e){ e.stopPropagation(); }
  return (
    <div className="k-card k-card--site clickable" onClick={clickCard}>
      <div className="k-card__head">
        <h3 className="k-card__title">{sede}</h3>
        <span className={`k-badge ${hasIncidents ? "k-badge--danger" : "k-badge--ok"}`}>
          {hasIncidents ? "Incidencias" : "OK"}
        </span>
      </div>
      {spark ? <div style={{ marginBottom: 8 }}><Sparkline points={spark} color={hasIncidents ? "#ef4444" : "#16a34a"} /></div> : null}
      <div className="k-stats">
        <div><span className="k-label">UP:</span> <span className="k-val">{up}</span></div>
        <div><span className="k-label">DOWN:</span> <span className="k-val">{down}</span></div>
        <div><span className="k-label">Total:</span> <span className="k-val">{total}</span></div>
        <div><span className="k-label">Prom:</span> <span className="k-val">{avg != null ? `${avg} ms` : "—"}</span></div>
      </div>
      <div className="k-actions" onClick={stop}>
        <button className="k-btn k-btn--danger" onClick={()=>onHideAll?.(sede)}>Ocultar todos</button>
        <button className="k-btn k-btn--ghost"  onClick={()=>onUnhideAll?.(sede)}>Mostrar todos</button>
      </div>
    </div>
  );
}
JSX

# ServiceGrid (agrupa por sede + spark series sede)
cat > src/components/ServiceGrid.jsx <<'JSX'
import React, { useMemo } from "react";
import ServiceCard from "./ServiceCard.jsx";
import History from "../historyEngine.js";
function groupByInstance(list=[]){ const map=new Map(); for (const m of list){ const g=map.get(m.instance)||[]; g.push(m); map.set(m.instance,g);} return map; }
function metricsFor(g=[]){ const up=g.filter(m=>m.latest?.status===1).length; const down=g.filter(m=>m.latest?.status===0).length; const total=g.length;
  const rts=g.map(m=>m.latest?.responseTime).filter(v=>v!=null); const avg=rts.length?Math.round(rts.reduce((a,b)=>a+b,0)/rts.length):null; return {up,down,total,avg}; }
export default function ServiceGrid({ monitorsAll=[], hiddenSet=new Set(), onHideAll, onUnhideAll, onOpen }) {
  const groups = useMemo(()=>groupByInstance(monitorsAll), [monitorsAll]);
  const items=[]; for (const [instance, arr] of groups.entries()) items.push({ instance, data: metricsFor(arr) });
  items.sort((a,b)=>a.instance.localeCompare(b.instance));
  return (
    <div className="grid">
      {items.map(({instance, data})=>{
        const spark = History.getAvgSeriesByInstance(instance);
        return <ServiceCard key={instance} sede={instance} data={data} spark={spark}
                 onOpen={()=>onOpen?.(instance)}
                 onHideAll={()=>onHideAll?.(instance)}
                 onUnhideAll={()=>onUnhideAll?.(instance)} />;
      })}
    </div>
  );
}
JSX

echo "== (4/8) InstanceDetail con Tabla/Grilla + foco en gráfico =="
cat > src/components/InstanceDetail.jsx <<'JSX'
import React, { useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx";
import Logo from "./Logo.jsx";
import MonitorCard from "./MonitorCard.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";
export default function InstanceDetail({ instanceName, monitorsAll=[], hiddenSet=new Set(), onHide, onUnhide, onHideAll, onUnhideAll }) {
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
          : <div className="k-chip k-chip--muted">Mostrando: <strong>Promedio de la sede</strong></div>}
      </div>
      {chartMode==="monitor" ? <HistoryChart mode="monitor" seriesMon={chartSeries} title={focus||"Latencia (ms)"} />
                              : <HistoryChart mode="instance" series={chartSeries} />}
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

echo "== (5/8) Header y filtros =="

# Cards (header interactivo por monitores)
cat > src/components/Cards.jsx <<'JSX'
import React from "react";
export default function Cards({ counts, status, onSetStatus }) {
  const { up=0, down=0, total=0, avgMs=null } = counts ?? {};
  const Box = ({ title, value, color, active, onClick, subtitle }) => (
    <button type="button" className={`k-card k-card--summary is-clickable ${active ? "is-active" : ""}`}
            style={{ borderLeftColor: color }} onClick={onClick}>
      <div className="k-card__title">{title}</div>
      <div className="k-card__content"><span className="k-metric">{value}</span>{subtitle ? <span className="k-label" style={{marginLeft:8}}>{subtitle}</span> : null}</div>
    </button>
  );
  return (
    <div className="k-cards">
      <Box title="UP"    value={up}   color="#16a34a" active={status==="up"}   onClick={()=>onSetStatus(status==="up"?"all":"up")} subtitle="monitores" />
      <Box title="DOWN"  value={down} color="#dc2626" active={status==="down"} onClick={()=>onSetStatus(status==="down"?"all":"down")} subtitle="monitores" />
      <Box title="Total" value={total} color="#3b82f6" active={status==="all"} onClick={()=>onSetStatus("all")} subtitle="monitores" />
      <div className="k-card k-card--summary" style={{ borderLeftColor: "#6366f1" }}>
        <div className="k-card__title">Prom (ms)</div>
        <div className="k-card__content"><span className="k-metric">{avgMs ?? "—"}</span></div>
      </div>
    </div>
  );
}
JSX

# Filters (Solo DOWN vinculado a status)
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

echo "== (6/8) App.jsx (polling, alerts, header y grid/table global) =="

cat > src/App.jsx <<'JSX'
import { useEffect, useMemo, useState, useRef } from "react";
import Cards from "./components/Cards.jsx";
import Filters from "./components/Filters.jsx";
import ServiceGrid from "./components/ServiceGrid.jsx";
import MonitorsTable from "./components/MonitorsTable.jsx";
import InstanceDetail from "./components/InstanceDetail.jsx";
import SLAAlerts from "./components/SLAAlerts.jsx";
import AlertsBanner from "./components/AlertsBanner.jsx";
import { fetchAll, getBlocklist, saveBlocklist } from "./api.js";
import History from "./historyEngine.js";

const SLA_CONFIG = { uptimeTarget: 99.9, maxLatencyMs: 800 };
const ALERT_AUTOCLOSE_MS = 10000;

function getRoute() {
  const parts = (window.location.hash || "").slice(1).split("/").filter(Boolean);
  if (parts[0] === "sede" && parts[1]) return { name: "sede", instance: decodeURIComponent(parts[1]) };
  return { name: "home" };
}
const keyFor = (instance, name="") => JSON.stringify({i:instance,n:name});
const fromKey = (k) => { try { return JSON.parse(k); } catch { return {i:"",n:""} } };

export default function App() {
  const [monitors, setMonitors]   = useState([]);
  const [instances, setInstances] = useState([]);
  const [filters, setFilters]     = useState({ instance:"", type:"", q:"", status:"all" });
  const [hidden, setHidden]       = useState(new Set());
  const [view, setView]           = useState("grid");
  const [route, setRoute]         = useState(getRoute());
  const [alerts, setAlerts]       = useState([]);

  useEffect(() => { const onHash = () => setRoute(getRoute()); window.addEventListener("hashchange", onHash); return () => window.removeEventListener("hashchange", onHash); }, []);

  // init
  const didInit = useRef(false);
  useEffect(() => {
    if (didInit.current) return; didInit.current = true;
    (async () => {
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances); setMonitors(monitors);
        History.addSnapshot(monitors);
        const bl = await getBlocklist();
        const set = new Set((bl?.monitors ?? []).map(k => keyFor(k.instance, k.name)));
        setHidden(set);
      } catch (e) { console.error(e); }
    })();
  }, []);

  // Detectar DOWN 1->0 + snapshots 5s
  const lastStatus = useRef(new Map());
  useEffect(() => { const m = new Map(); for (const x of monitors) m.set(keyFor(x.instance, x.info?.monitor_name), x.latest?.status ?? 1); lastStatus.current = m; }, []);
  useEffect(() => {
    let stop = false;
    async function loop() {
      if (stop) return;
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances); setMonitors(monitors);
        History.addSnapshot(monitors);
        const prev = lastStatus.current, next = new Map(), newDowns=[];
        for (const m of monitors) {
          const k = keyFor(m.instance, m.info?.monitor_name), st = m.latest?.status ?? 1, was = prev.get(k);
          if (was === 1 && st === 0) newDowns.push({ id:k, instance:m.instance, name:m.info?.monitor_name, ts:Date.now() });
          next.set(k, st);
        }
        lastStatus.current = next;
        if (newDowns.length) setAlerts(prevA => {
          const ids = new Set(prevA.map(a=>a.id)); const add = newDowns.filter(a=>!ids.has(a.id)); return [...prevA, ...add];
        });
        setAlerts(prevA => prevA.filter(a => next.get(a.id) === 0));
      } catch {}
      setTimeout(loop, 5000);
    }
    loop(); return () => { stop = true; };
  }, []);

  // baseMonitors para header (sin estado)
  const baseMonitors = useMemo(() => monitors.filter(m => {
    if (filters.instance && m.instance !== filters.instance) return false;
    if (filters.type && m.info?.monitor_type !== filters.type) return false;
    if (filters.q) {
      const hay = `${m.info?.monitor_name ?? ""} ${m.info?.monitor_url ?? ""}`.toLowerCase();
      if (!hay.includes(filters.q.toLowerCase())) return false;
    }
    return true;
  }), [monitors, filters.instance, filters.type, filters.q]);

  // header counts
  const headerCounts = useMemo(() => {
    const up = baseMonitors.filter(m => m.latest?.status === 1).length;
    const down = baseMonitors.filter(m => m.latest?.status === 0).length;
    const total = baseMonitors.length;
    const rts = baseMonitors.map(m => m.latest?.responseTime).filter(v => v != null);
    const avgMs = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0)/rts.length) : null;
    return { up, down, total, avgMs };
  }, [baseMonitors]);

  // estado efectivo
  const effectiveStatus = filters.status;
  function setStatus(s){ setFilters(p => ({ ...p, status:s })); }

  // monitores visibles (con estado)
  const filteredAll = useMemo(() => baseMonitors.filter(m => {
    if (effectiveStatus === "up"   && m.latest?.status !== 1) return false;
    if (effectiveStatus === "down" && m.latest?.status !== 0) return false;
    return true;
  }), [baseMonitors, effectiveStatus]);

  const visible = filteredAll.filter(m => !hidden.has(keyFor(m.instance, m.info?.monitor_name)));

  // hidden mgmt
  async function persistHidden(next) {
    const arr = [...next].map(k => { const {i,n}=fromKey(k); return {instance:i,name:n}; });
    await saveBlocklist({ monitors: arr }); setHidden(next);
  }
  function onHide(i,n){ const s=new Set(hidden); s.add(keyFor(i,n)); persistHidden(s); }
  function onUnhide(i,n){ const s=new Set(hidden); s.delete(keyFor(i,n)); persistHidden(s); }
  function onHideAll(instance){
    const s = new Set(hidden);
    filteredAll.filter(m=>m.instance===instance).forEach(m=>s.add(keyFor(m.instance, m.info?.monitor_name)));
    persistHidden(s);
  }
  async function onUnhideAll(instance){
    const bl = await getBlocklist(); const nextArr = (bl?.monitors ?? []).filter(k => k.instance !== instance);
    await saveBlocklist({ monitors: nextArr }); setHidden(new Set(nextArr.map(k=>keyFor(k.instance,k.name))));
  }
  function openInstance(name){ window.location.hash = "/sede/" + encodeURIComponent(name); }

  return (
    <div className="container" data-route={route.name}>
      <h1>Uptime Central</h1>
      <AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))} autoCloseMs={ALERT_AUTOCLOSE_MS}/>
      <Cards counts={headerCounts} status={effectiveStatus} onSetStatus={setStatus} />
      <div className="controls">
        <Filters monitors={monitors} value={filters} onChange={setFilters} />
        {route.name!=="sede" && (
          <div className="global-toggle" style={{ display:"flex", gap:8 }}>
            <button type="button" className={`btn tab ${view==="grid"?"active":""}`}  aria-pressed={view==="grid"}  onClick={()=>setView("grid")}>Grid</button>
            <button type="button" className={`btn tab ${view==="table"?"active":""}`} aria-pressed={view==="table"} onClick={()=>setView("table")}>Tabla</button>
          </div>
        )}
      </div>
      <SLAAlerts monitors={visible} config={SLA_CONFIG} onOpenInstance={openInstance} />
      {route.name==="sede" ? (
        <div className="container">
          <InstanceDetail instanceName={route.instance} monitorsAll={filteredAll} hiddenSet={hidden}
            onHide={onHide} onUnhide={onUnhide} onHideAll={onHideAll} onUnhideAll={onUnhideAll}/>
        </div>
      ) : view==="grid" ? (
        <ServiceGrid monitorsAll={filteredAll} hiddenSet={hidden} onHideAll={onHideAll} onUnhideAll={onUnhideAll} onOpen={openInstance} />
      ) : (
        <MonitorsTable monitors={visible} hiddenSet={hidden} onHide={onHide} onUnhide={onUnhide} slaConfig={SLA_CONFIG}/>
      )}
    </div>
  );
}
JSX

echo "== (7/8) api.js (summary-only + polling y blocklist) =="

cat > src/api.js <<'JS'
// API base
const API = (typeof import.meta !== "undefined" && import.meta.env?.VITE_API_BASE) || "/";
const log = (...a) => console.log("[kuma-api]", ...a); const err = (...a) => console.error("[kuma-api]", ...a);
async function get(path){ const r = await fetch(API + path); if(!r.ok) throw new Error("HTTP "+r.status); return r.json(); }

// Lee todo de /api/summary (instances + monitors)
export async function fetchAll(){
  try{ const data = await get("api/summary"); return { instances: data.instances||[], monitors: data.monitors||[] }; }
  catch(e){ err("fetchAll()", e); return { instances:[], monitors:[] }; }
}

// Compat con UI
export async function fetchSummary(){
  const { instances } = await fetchAll();
  return { up: instances.filter(i=>i.ok).length, down: instances.filter(i=>!i.ok).length, total: instances.length };
}
export async function fetchMonitors(){ const { monitors } = await fetchAll(); return monitors; }

// NO stream: hacemos polling que llama onMessage(monitors)
export function openStream(onMessage){
  let stop=false; async function loop(){ if(stop) return; try{ const { monitors } = await fetchAll(); onMessage?.(monitors); }catch{} setTimeout(loop, 5000); }
  loop(); return ()=>{ stop=true; };
}

// Blocklist con fallback local
export async function getBlocklist(){ try{ return await get("api/blocklist"); }catch{ const raw=localStorage.getItem("blocklist"); return raw?JSON.parse(raw):{monitors:[]}; } }
export async function saveBlocklist(b){ try{ await fetch(API+"api/blocklist",{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify(b)}); }catch{ localStorage.setItem("blocklist", JSON.stringify(b)); } }
JS

echo "== (8/8) Estilos y logos =="

# Estilos (añade bloques si no estaban)
grep -q "k-cards" src/styles.css || cat >> src/styles.css <<'CSS'
/* Header cards */
.k-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin:8px 0 16px;}
.k-card.k-card--summary{border:1px solid #e5e7eb;border-left:6px solid #e5e7eb;border-radius:10px;background:#fff;padding:12px;}
.k-card__title{font-weight:600;margin-bottom:6px;}
.k-metric{font-size:20px;font-weight:700;margin-right:6px;}
.k-label{color:#6b7280;font-size:12px;}
.is-clickable{cursor:pointer;transition:box-shadow .15s ease;}
.is-clickable:hover{box-shadow:0 2px 10px rgba(0,0,0,.06);}
.is-active{outline:2px solid #93c5fd;background:#f0f9ff;}

/* Alerts */
.k-alerts{position:sticky;top:0;z-index:50;display:flex;flex-direction:column;gap:8px;margin-bottom:8px;}
.k-alert{display:flex;justify-content:space-between;align-items:center;padding:10px 12px;border-radius:8px;}
.k-alert--danger{background:#fee2e2;color:#991b1b;border:1px solid #fecaca;}
.k-alert__close{background:transparent;border:0;font-size:14px;cursor:pointer;color:#991b1b;}

/* Sede cards */
.k-card.k-card--site{border:1px solid #e5e7eb;border-radius:12px;background:#fff;padding:14px;display:flex;flex-direction:column;gap:12px;min-height:160px;overflow:hidden;}
.k-card__head{display:flex;justify-content:space-between;align-items:center;}
.k-card__title{margin:0;font-size:16px;font-weight:700;}
.k-badge{font-size:12px;font-weight:600;padding:4px 10px;border-radius:999px;color:#fff;}
.k-badge--ok{background:#16a34a;}
.k-badge--danger{background:#dc2626;}
.k-stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:6px;}
.k-val{font-weight:700;}
.k-actions{display:flex;gap:8px;flex-wrap:nowrap;justify-content:space-between;white-space:nowrap;}
.k-btn{font-size:12px;padding:6px 10px;border-radius:8px;cursor:pointer;border:1px solid transparent;}
.k-btn--primary{border-color:#2563eb;color:#2563eb;background:#eff6ff;}
.k-btn--danger{border-color:#dc2626;color:#dc2626;background:#fef2f2;}
.k-btn--ghost{border-color:#cbd5e1;color:#334155;background:#fff;}
.k-btn:hover{filter:brightness(.97);}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px;}

/* Tabla detalle */
.k-table{width:100%;border-collapse:collapse;margin-top:12px;}
.k-table th{text-align:left;padding:8px;background:#f3f4f6;border-bottom:2px solid #e5e7eb;font-size:14px;}
.k-table td{padding:8px;border-bottom:1px solid #e5e7eb;font-size:14px;vertical-align:middle;}
.k-cell-service{display:flex;align-items:center;gap:10px;}
.k-logo{width:18px;height:18px;border-radius:4px;border:1px solid #e5e7eb;background:#fff;object-fit:contain;}
.k-logo--fallback{display:flex;align-items:center;justify-content:center;font-size:10px;background:#e5e7eb;color:#374151;}
/* Grilla servicios */
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
/* Oculta el toggle global en vista de sede */
[data-route="sede"] .global-toggle { display: none !important; }
CSS

# Logos básicos (SVG con xmlns correcto)
cat > public/logos/instagram.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs><linearGradient id="g" x1="0%" y1="100%" x2="100%" y2="0%"><stop offset="0%" stop-color="#F58529"/><stop offset="50%" stop-color="#DD2A7B"/><stop offset="100%" stop-color="#8134AF"/></linearGradient></defs>
  <rect width="256" height="256" rx="56" fill="url(#g)"/><circle cx="128" cy="128" r="50" fill="none" stroke="#FFF" stroke-width="20"/><circle cx="185" cy="71" r="20" fill="#FFF"/>
</svg>
SVG
cat > public/logos/microsoft.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="#fff"/><rect x="20" y="20" width="100" height="100" fill="#F25022"/><rect x="136" y="20" width="100" height="100" fill="#7FBA00"/><rect x="20" y="136" width="100" height="100" fill="#00A4EF"/><rect x="136" y="136" width="100" height="100" fill="#FFB900"/></svg>
SVG
cat > public/logos/telegram.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="256" rx="56" fill="#0088CC"/><path fill="#fff" d="M203 67L40 121c-6 2-7 10-1 13l36 17 14 45c2 6 10 8 14 3l21-20 36 26c5 4 12 1 14-5l33-118c2-7-4-12-11-10z"/></svg>
SVG
cat > public/logos/netflix.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="#000"/><path fill="#E50914" d="M96 40v176l64-40V0z"/></svg>
SVG
cat > public/logos/whatsapp.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="256" rx="56" fill="#25D366"/><path fill="#FFF" d="M129.8 54c-40.1 0-72.6 32.5-72.6 72.6 0 12.8 3.3 25.5 9.6 36.7l-10.2 37.3 38.2-10c10.8 5.7 22.9 8.7 35 8.7 40.1 0 72.6-32.5 72.6-72.6S169.9 54 129.8 54zm41.3 94.3c-1.8 5.1-10.3 10-14.4 10.6-3.6.5-8.1.7-13.1-1.5-3-1.2-6.7-2.2-11.5-4.3-20.1-8.8-33.1-29.3-34.1-30.7-.9-1.2-8.1-10.7-8.1-20.5 0-9.8 5.1-14.6 6.9-16.7 1.8-2 4-2.5 5.3-2.5 1.4 0 2.7.1 3.8.1 1.2.1 2.9-.5 4.5 3.4 1.8 4.4 6.1 15 6.7 16.1.5 1.1.9 2.3.2 3.6-.7 1.2-1.1 1.8-2.1 2.9-.9 1-1.8 2.2-2.5 3-.8.8-1.6 1.7-.7 3.3.9 1.6 3.9 6.4 8.3 10.4 5.7 5.1 10.5 6.7 12.1 7.5 1.6.7 2.5.6 3.4-.4.9-1 3.9-4.5 4.9-6.1 1.1-1.6 2.1-1.3 3.4-.8 1.3.5 8.4 3.9 9.9 4.6 1.5.7 2.5 1.1 2.9 1.7.4.6.4 5.1-1.4 10.2z"/></svg>
SVG
cat > public/logos/youtube.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="256" rx="40" fill="#FF0000"/><polygon fill="#FFFFFF" points="105,168 105,88 175,128"/></svg>
SVG
cat > public/logos/tiktok.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="256" fill="#000"/><path fill="#69C9D0" d="M164 64c12 12 26 20 42 22v32c-15-1-29-7-42-17v60c0 57-68 84-105 42 30 11 59-10 59-42V64h46z"/><path fill="#EE1D52" d="M161 64h-46v97c0 32-29 53-59 42 16 19 44 27 71 16 23-10 38-32 38-58V64z"/></svg>
SVG
cat > public/logos/google.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="#fff"/><path fill="#4285F4" d="M231 130c0-8-1-16-3-23H129v43h58c-2 11-8 20-17 27v23h28c17-16 33-42 33-70z"/><path fill="#34A853" d="M129 232c23 0 43-8 57-21l-28-23c-8 5-19 8-29 8-22 0-41-15-48-35H52v22c14 29 45 49 77 49z"/><path fill="#FBBC04" d="M81 161c-4-11-5-23 0-35v-22H52c-15 30-15 66 0 96l29-22z"/><path fill="#EA4335" d="M129 72c13 0 25 4 34 12l26-25c-17-16-39-25-60-25-32 0-63 20-77 49l29 22c7-20 26-35 48-35z"/></svg>
SVG
cat > public/logos/apple.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><path fill="#000" d="M176 135c1-23 19-34 20-35-11-16-28-18-34-18-15-1-30 8-38 8s-20-8-33-7c-17 1-32 10-41 26-18 31-5 77 12 102 8 12 18 25 31 24 12-1 16-8 31-8 15 0 18 8 32 8 13-1 22-12 30-24 9-13 12-25 13-26-1 0-25-10-23-42z"/><path fill="#000" d="M158 56c6-8 10-19 9-30-9 1-21 7-27 15-6 7-11 18-9 29 10 1 21-6 27-14z"/></svg>
SVG
cat > public/logos/iptv.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><rect width="256" height="170" y="30" rx="20" fill="#1E293B"/><rect x="80" y="210" width="96" height="16" rx="8" fill="#475569"/><polygon fill="#38BDF8" points="110,90 110,150 160,120"/></svg>
SVG

echo "== Instalando dependencias de gráficos =="
npm i chart.js react-chartjs-2 chartjs-adapter-date-fns --save >/dev/null 2>&1 || true

echo "== Compilando build de producción =="
npm run build

echo "== BACKUP del dist de producción (si existe) =="
if [ -d "$DOCROOT" ]; then
  sudo tar -czf "/var/www/uptime8081/dist.backup_${TS}.tgz" -C "/var/www/uptime8081" "dist" || true
  echo "Backup: /var/www/uptime8081/dist.backup_${TS}.tgz"
fi

echo "== Desplegando dist/ -> $DOCROOT (rsync --delete) =="
sudo mkdir -p "$DOCROOT"
sudo rsync -av --delete "$APP_DIR/dist/" "$DOCROOT/"

echo "== Escribiendo Nginx 8081 (SPA + cache + proxy /api -> $BACKEND) =="
sudo tee "$SITE_CONF" >/dev/null <<NGX
server {
  listen $PORT;
  server_name $SERVER_IP;

  root $DOCROOT;
  index index.html;

  location = /index.html {
    add_header Cache-Control "no-cache, no-store, must-revalidate";
    expires -1;
    try_files \$uri =404;
  }
  location / { try_files \$uri \$uri/ /index.html; }
  location /assets/ {
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
    try_files \$uri =404;
  }
  location /api/ {
    proxy_pass $BACKEND/api/;
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    add_header Cache-Control "no-store";
    expires off;
  }
}
NGX
sudo ln -sf "$SITE_CONF" "$SITE_ENABLED"
sudo nginx -t && sudo systemctl reload nginx

echo "== Verificación rápida /api/summary por 8081 =="
set +e
curl -sS "http://$SERVER_IP:$PORT/api/summary" | head -c 400; echo
set -e

echo "=============================================================="
echo "✔ Front + Back (proxy /api) restaurados en producción 8081"
echo "   URL: http://$SERVER_IP:$PORT/   (Ctrl+F5 o incógnito)"
echo "   Si tu backend escucha en otro puerto, ejecuta:"
echo "     BACKEND=http://10.10.31.31:8080 ./restore_full_stack_8081.sh"
echo "=============================================================="
