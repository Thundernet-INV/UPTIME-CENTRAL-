#!/bin/sh
# Uptime Central – Full Dashboard Upgrade
# - Header (UP/DOWN/TOTAL/Prom) de MONITORES según filtros + clic para filtrar
# - UI de cards (OK/Incidencias), botones ordenados
# - Histórico en localStorage + Sparkline B1 por sede + Gráfica grande
# - Alertas por nuevos DOWN (auto-limpieza al UP o por timeout)
# Uso:
#   chmod +x ./full_dashboard_upgrade.sh
#   ./full_dashboard_upgrade.sh
#   npm run dev

set -eu
TS=$(date +%Y%m%d%H%M%S)

need() { [ -f "$1" ] || { echo "[ERROR] Falta $1" >&2; exit 1; }; }

echo "== Validando proyecto =="
need package.json
need vite.config.js
mkdir -p src/components

echo "== Instalando dependencias de gráficos (Chart.js) =="
npm i chart.js react-chartjs-2 --save

###############################################################################
# 1) historyEngine.js – histórico en localStorage (FIFO)
###############################################################################
echo "== Escribiendo src/historyEngine.js =="
cat > src/historyEngine.js <<'JS'
// Simple history engine (localStorage) – snapshots de monitores
const KEY = "kuma_history_snapshots_v1";
const MAX = 500;          // 5s*500 ≈ 41' de historial
const SPARK_POINTS = 120; // reduce puntos para sparkline (suave)

function load() {
  try { return JSON.parse(localStorage.getItem(KEY) || "[]"); }
  catch { return []; }
}
function save(arr) { try { localStorage.setItem(KEY, JSON.stringify(arr)); } catch {} }
function now() { return Date.now(); }

function avgLatencyForInstance(monitors, instance) {
  const arr = monitors.filter(m => m.instance === instance)
                      .map(m => m.latest?.responseTime)
                      .filter(v => typeof v === "number" && isFinite(v));
  if (!arr.length) return null;
  const sum = arr.reduce((a,b)=>a+b,0);
  return Math.round(sum / arr.length);
}
function downCountForInstance(monitors, instance) {
  return monitors.filter(m => m.instance === instance && m.latest?.status === 0).length;
}

const History = {
  addSnapshot(monitors) {
    const s = load(); s.push({ t: now(), monitors });
    while (s.length > MAX) s.shift();
    save(s);
  },
  getAvgSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s) { xs.push(snap.t); ys.push(avgLatencyForInstance(snap.monitors, instance)); }
    const start = Math.max(0, xs.length - maxPoints);
    return { t: xs.slice(start), v: ys.slice(start) };
  },
  getDownsSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s) { xs.push(snap.t); ys.push(downCountForInstance(snap.monitors, instance)); }
    const start = Math.max(0, xs.length - maxPoints);
    return { t: xs.slice(start), v: ys.slice(start) };
  },
  getAllForInstance(instance, maxPoints = MAX) {
    const lat = this.getAvgSeriesByInstance(instance, maxPoints);
    const dwn = this.getDownsSeriesByInstance(instance, maxPoints);
    return { lat, dwn };
  }
};
export default History;
JS

###############################################################################
# 2) Sparkline.jsx – mini gráfica por sede (línea B1, sin adapter fecha)
###############################################################################
echo "== Escribiendo src/components/Sparkline.jsx =="
cat > src/components/Sparkline.jsx <<'JSX'
import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Tooltip,
  Filler,
} from "chart.js";

ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Filler);

export default function Sparkline({ points, color = "#2563eb", height = 42 }) {
  const labels = useMemo(() => (points?.t ?? []).map((_, i) => i), [points]);

  const data = useMemo(() => ({
    labels,
    datasets: [
      {
        data: points?.v ?? [],
        borderColor: color,
        backgroundColor: (ctx) => {
          const chart = ctx.chart;
          if (!chart?.chartArea) return color + "22";
          const { ctx: c, chartArea } = chart;
          const g = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
          g.addColorStop(0, color + "40");
          g.addColorStop(1, color + "00");
          return g;
        },
        tension: 0.35,
        borderWidth: 2,
        pointRadius: 0,
        fill: true,
        spanGaps: true,
      },
    ],
  }), [labels, points, color]);

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    elements: { point: { radius: 0 } },
    scales: { x: { display: false }, y: { display: false } },
    plugins: { legend: { display: false }, tooltip: { enabled: false } },
  };

  return (
    <div style={{ height }}>
      <Line data={data} options={options} />
    </div>
  );
}
JSX

###############################################################################
# 3) HistoryChart.jsx – gráfica grande por sede (latencia y downs)
###############################################################################
echo "== Escribiendo src/components/HistoryChart.jsx =="
cat > src/components/HistoryChart.jsx <<'JSX'
import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Tooltip,
  Legend,
  Filler,
} from "chart.js";
ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Legend, Filler);

export default function HistoryChart({ series, h=220 }) {
  const labels = useMemo(() => (series?.lat?.t ?? []).map((_,i)=>i), [series]);
  const latVals = series?.lat?.v ?? [];
  const dwnVals = series?.dwn?.v ?? [];

  const data = useMemo(()=>({
    labels,
    datasets: [
      {
        label: "Prom (ms)",
        data: latVals,
        yAxisID: "y",
        borderColor: "#3b82f6",
        backgroundColor: "#3b82f622",
        tension: .35, pointRadius: 0, fill: true,
      },
      {
        label: "Downs",
        data: dwnVals,
        yAxisID: "y1",
        borderColor: "#ef4444",
        backgroundColor: "#ef444422",
        tension: .2, pointRadius: 0, fill: true,
      }
    ]
  }), [labels, latVals, dwnVals]);

  const options = {
    responsive: true, maintainAspectRatio: false,
    scales: {
      x: { display: false },
      y: { position: "left", grid: { color: "#e5e7eb" } },
      y1:{ position: "right", grid: { drawOnChartArea: false } }
    },
    plugins: { legend: { position: "bottom" }, tooltip: { enabled: true } }
  };

  return <div style={{height:h}}><Line data={data} options={options}/></div>;
}
JSX

###############################################################################
# 4) AlertsBanner.jsx – banner superior de alertas DOWN (auto-limpieza)
###############################################################################
echo "== Escribiendo src/components/AlertsBanner.jsx =="
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
          <div>
            <strong>DOWN:</strong> {a.instance} — {a.name}
          </div>
          <button className="k-alert__close" onClick={()=>onClose?.(a.id)}>✕</button>
        </div>
      ))}
    </div>
  );
}
JSX

###############################################################################
# 5) Cards.jsx – header interactivo (UP/DOWN/TOTAL/Prom)
###############################################################################
echo "== Escribiendo src/components/Cards.jsx =="
[ -f src/components/Cards.jsx ] && cp src/components/Cards.jsx src/components/Cards.jsx.bak.$TS
cat > src/components/Cards.jsx <<'JSX'
import React from "react";

export default function Cards({ counts, status, onSetStatus }) {
  const { up = 0, down = 0, total = 0, avgMs = null } = counts ?? {};
  const Box = ({ title, value, color, active, onClick, subtitle }) => (
    <button
      type="button"
      className={`k-card k-card--summary is-clickable ${active ? "is-active" : ""}`}
      style={{ borderLeftColor: color }}
      onClick={onClick}
    >
      <div className="k-card__title">{title}</div>
      <div className="k-card__content">
        <span className="k-metric">{value}</span>
        {subtitle ? <span className="k-label" style={{marginLeft:8}}>{subtitle}</span> : null}
      </div>
    </button>
  );
  return (
    <div className="k-cards">
      <Box title="UP" value={up} color="#16a34a"
           active={status==="up"} onClick={()=>onSetStatus(status==="up"?"all":"up")} subtitle="monitores"/>
      <Box title="DOWN" value={down} color="#dc2626"
           active={status==="down"} onClick={()=>onSetStatus(status==="down"?"all":"down")} subtitle="monitores"/>
      <Box title="Total" value={total} color="#3b82f6"
           active={status==="all"} onClick={()=>onSetStatus("all")} subtitle="monitores"/>
      <div className="k-card k-card--summary" style={{ borderLeftColor: "#6366f1" }}>
        <div className="k-card__title">Prom (ms)</div>
        <div className="k-card__content"><span className="k-metric">{avgMs ?? "—"}</span></div>
      </div>
    </div>
  );
}
JSX

###############################################################################
# 6) ServiceCard.jsx – card de sede con badge OK/Incidencias + sparkline
###############################################################################
echo "== Escribiendo src/components/ServiceCard.jsx =="
cat > src/components/ServiceCard.jsx <<'JSX'
import React from "react";
import Sparkline from "./Sparkline.jsx";

export default function ServiceCard({ sede, data, onHideAll, onUnhideAll, onOpen, spark }) {
  const { up = 0, down = 0, total = 0, avg = null } = data ?? {};
  const hasIncidents = down > 0;
  return (
    <div className="k-card k-card--site">
      <div className="k-card__head">
        <h3 className="k-card__title">{sede}</h3>
        <span className={`k-badge ${hasIncidents ? "k-badge--danger" : "k-badge--ok"}`}>
          {hasIncidents ? "Incidencias" : "OK"}
        </span>
      </div>

      {spark ? <Sparkline points={spark} color={hasIncidents ? "#ef4444" : "#16a34a"} /> : null}

      <div className="k-stats">
        <div><span className="k-label">UP:</span> <span className="k-val">{up}</span></div>
        <div><span className="k-label">DOWN:</span> <span className="k-val">{down}</span></div>
        <div><span className="k-label">Total:</span> <span className="k-val">{total}</span></div>
        <div><span className="k-label">Prom:</span> <span className="k-val">{avg != null ? `${avg} ms` : "—"}</span></div>
      </div>

      <div className="k-actions">
        <button className="k-btn k-btn--primary" onClick={onOpen}>Abrir</button>
        <button className="k-btn k-btn--danger" onClick={onHideAll}>Ocultar todos</button>
        <button className="k-btn k-btn--ghost" onClick={onUnhideAll}>Mostrar todos</button>
      </div>
    </div>
  );
}
JSX

###############################################################################
# 7) ServiceGrid.jsx – agrupa por sede, calcula métricas + sparkline
###############################################################################
if [ -f src/components/ServiceGrid.jsx ]; then
  cp src/components/ServiceGrid.jsx src/components/ServiceGrid.jsx.bak.$TS
fi
echo "== Escribiendo src/components/ServiceGrid.jsx =="
cat > src/components/ServiceGrid.jsx <<'JSX'
import React, { useMemo } from "react";
import ServiceCard from "./ServiceCard.jsx";
import History from "../historyEngine.js";

function groupByInstance(list=[]) {
  const map = new Map();
  for (const m of list) {
    const g = map.get(m.instance) || [];
    g.push(m);
    map.set(m.instance, g);
  }
  return map;
}
function metricsFor(group=[]) {
  const up   = group.filter(m => m.latest?.status === 1).length;
  const down = group.filter(m => m.latest?.status === 0).length;
  const total = group.length;
  const rts = group.map(m=>m.latest?.responseTime).filter(v=>v!=null);
  const avg = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0)/rts.length) : null;
  return { up, down, total, avg };
}

export default function ServiceGrid({
  monitorsAll = [],
  hiddenSet = new Set(),
  onHideAll, onUnhideAll, onOpen
}) {
  const groups = useMemo(()=>groupByInstance(monitorsAll), [monitorsAll]);
  const items = [];
  for (const [instance, arr] of groups.entries()) {
    items.push({ instance, data: metricsFor(arr) });
  }
  items.sort((a,b)=>a.instance.localeCompare(b.instance));

  return (
    <div className="grid">
      {items.map(({instance, data}) => {
        const spark = History.getAvgSeriesByInstance(instance);
        return (
          <ServiceCard
            key={instance}
            sede={instance}
            data={data}
            spark={spark}
            onOpen={()=>onOpen?.(instance)}
            onHideAll={()=>onHideAll?.(instance)}
            onUnhideAll={()=>onUnhideAll?.(instance)}
          />
        );
      })}
    </div>
  );
}
JSX

###############################################################################
# 8) InstanceDetail.jsx – integra HistoryChart
###############################################################################
if [ -f src/components/InstanceDetail.jsx ]; then
  cp src/components/InstanceDetail.jsx src/components/InstanceDetail.jsx.bak.$TS
fi
echo "== Escribiendo src/components/InstanceDetail.jsx =="
cat > src/components/InstanceDetail.jsx <<'JSX'
import React, { useMemo } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide, onUnhide, onHideAll, onUnhideAll
}) {
  const group = useMemo(()=>monitorsAll.filter(m=>m.instance===instanceName), [monitorsAll, instanceName]);
  const series = useMemo(()=>History.getAllForInstance(instanceName), [instanceName, monitorsAll.length]);

  return (
    <div>
      <h2>{instanceName}</h2>
      <HistoryChart series={series} />
      <div style={{marginTop:12}}>
        <button className="k-btn k-btn--primary" onClick={()=>window.history.back()}>Volver</button>
        <button className="k-btn k-btn--danger" onClick={()=>onHideAll?.(instanceName)} style={{marginLeft:8}}>Ocultar sede</button>
        <button className="k-btn k-btn--ghost"  onClick={()=>onUnhideAll?.(instanceName)} style={{marginLeft:8}}>Mostrar sede</button>
      </div>

      <div style={{marginTop:16}}>
        <ul>
          {group.map((m,i)=>(
            <li key={i}>
              {m.info?.monitor_name} — {m.latest?.status===1 ? "UP" : "DOWN"} — {m.latest?.responseTime ?? "—"} ms
              <button className="k-btn k-btn--ghost" style={{marginLeft:8}}
                onClick={()=>onHide?.(m.instance, m.info?.monitor_name)}>Ocultar</button>
              <button className="k-btn k-btn--ghost" style={{marginLeft:6}}
                onClick={()=>onUnhide?.(m.instance, m.info?.monitor_name)}>Mostrar</button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
JSX

###############################################################################
# 9) App.jsx – header dinámico + polling + alerts + history snapshots
###############################################################################
echo "== Escribiendo src/App.jsx (backup y versión limpia) =="
[ -f src/App.jsx ] && cp src/App.jsx src/App.jsx.bak.$TS
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
const ALERT_AUTOCLOSE_MS = 10000; // 10s

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
  const [filters, setFilters] = useState({ instance:"", type:"", q:"", status:"all" });
  const [hidden, setHidden] = useState(new Set());
  const [view, setView] = useState("grid");
  const [route, setRoute] = useState(getRoute());
  const [alerts, setAlerts] = useState([]);

  // routing
  useEffect(() => {
    const onHash = () => setRoute(getRoute());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  // init
  const didInit = useRef(false);
  useEffect(() => {
    if (didInit.current) return;
    didInit.current = true;
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

  // Detectar transiciones a DOWN y guardar histórico cada 5s
  const lastStatus = useRef(new Map()); // k => 0/1
  useEffect(() => { // inicializa mapa con el primer lote
    const map = new Map();
    for (const m of monitors) map.set(keyFor(m.instance, m.info?.monitor_name), m.latest?.status ?? 1);
    lastStatus.current = map;
  }, []); // solo al inicio

  useEffect(() => {
    let stop = false;
    async function loop() {
      if (stop) return;
      try {
        const { instances, monitors } = await fetchAll();
        setInstances(instances); setMonitors(monitors);
        History.addSnapshot(monitors);

        // detectar nuevos DOWN (1->0)
        const prev = lastStatus.current;
        const next = new Map();
        const newDowns = [];
        for (const m of monitors) {
          const k = keyFor(m.instance, m.info?.monitor_name);
          const st = m.latest?.status ?? 1;
          const was = prev.get(k);
          if (was === 1 && st === 0) {
            newDowns.push({ id: k, instance: m.instance, name: m.info?.monitor_name, ts: Date.now() });
          }
          next.set(k, st);
        }
        lastStatus.current = next;

        if (newDowns.length) {
          setAlerts(prevA => {
            const ids = new Set(prevA.map(a=>a.id));
            const add = newDowns.filter(a=>!ids.has(a.id));
            return [...prevA, ...add];
          });
        }

        // limpieza automática al volver a UP
        setAlerts(prevA => prevA.filter(a => {
          const st = next.get(a.id); // 0/1
          return st === 0; // si volvió a 1, se elimina
        }));
      } catch {}
      setTimeout(loop, 5000);
    }
    loop();
    return () => { stop = true; };
  }, []);

  // baseMonitors (sin estado) para header
  const baseMonitors = useMemo(() => {
    return monitors.filter(m => {
      if (filters.instance && m.instance !== filters.instance) return false;
      if (filters.type && m.info?.monitor_type !== filters.type) return false;
      if (filters.q) {
        const hay = `${m.info?.monitor_name ?? ""} ${m.info?.monitor_url ?? ""}`.toLowerCase();
        if (!hay.includes(filters.q.toLowerCase())) return false;
      }
      return true;
    });
  }, [monitors, filters.instance, filters.type, filters.q]);

  // header counts (solo monitores filtrados)
  const headerCounts = useMemo(() => {
    const up    = baseMonitors.filter(m => m.latest?.status === 1).length;
    const down  = baseMonitors.filter(m => m.latest?.status === 0).length;
    const total = baseMonitors.length;
    const rts = baseMonitors.map(m => m.latest?.responseTime).filter(v=>v!=null);
    const avgMs = rts.length ? Math.round(rts.reduce((a,b)=>a+b,0)/rts.length) : null;
    return { up, down, total, avgMs };
  }, [baseMonitors]);

  // estado (UP/DOWN/ALL)
  const effectiveStatus = filters.status;
  function setStatus(status){ setFilters(p=>({ ...p, status })); }

  // monitores visibles (incluye estado)
  const filteredAll = useMemo(() => {
    return baseMonitors.filter(m => {
      if (effectiveStatus === "up"   && m.latest?.status !== 1) return false;
      if (effectiveStatus === "down" && m.latest?.status !== 0) return false;
      return true;
    });
  }, [baseMonitors, effectiveStatus]);

  const visible = filteredAll.filter(m => !hidden.has(keyFor(m.instance, m.info?.monitor_name)));

  // hidden mgmt
  async function persistHidden(next) {
    const arr = [...next].map(k => { const {i,n}=fromKey(k); return {instance:i,name:n}; });
    await saveBlocklist({ monitors: arr }); setHidden(next);
  }
  function onHide(instance, name){ const n=new Set(hidden); n.add(keyFor(instance,name)); persistHidden(n); }
  function onUnhide(instance, name){ const n=new Set(hidden); n.delete(keyFor(instance,name)); persistHidden(n); }
  function onHideAll(instance){
    const n = new Set(hidden);
    filteredAll.filter(m=>m.instance===instance)
      .forEach(m=>n.add(keyFor(m.instance, m.info?.monitor_name)));
    persistHidden(n);
  }
  async function onUnhideAll(instance){
    const bl = await getBlocklist();
    const nextArr = (bl?.monitors ?? []).filter(k => k.instance !== instance);
    await saveBlocklist({ monitors: nextArr });
    setHidden(new Set(nextArr.map(k=>keyFor(k.instance,k.name))));
  }
  function openInstance(name){ window.location.hash = "/sede/" + encodeURIComponent(name); }

  return (
    <div className="container">
      <h1>Uptime Central</h1>

      <AlertsBanner alerts={alerts} onClose={(id)=>setAlerts(a=>a.filter(x=>x.id!==id))}
        autoCloseMs={ALERT_AUTOCLOSE_MS}/>

      <Cards counts={headerCounts} status={effectiveStatus} onSetStatus={setStatus} />

      <div className="controls">
        <Filters monitors={monitors} value={filters} onChange={setFilters} />
        <div style={{ display:"flex", gap:8 }}>
          <button className={`btn tab ${view==="grid"?"active":""}`} onClick={()=>setView("grid")}>Grid</button>
          <button className={`btn tab ${view==="table"?"active":""}`} onClick={()=>setView("table")}>Tabla</button>
        </div>
      </div>

      <SLAAlerts monitors={visible} config={SLA_CONFIG} onOpenInstance={openInstance} />

      {route.name==="sede" ? (
        <div className="container">
          <InstanceDetail
            instanceName={route.instance}
            monitorsAll={filteredAll}
            hiddenSet={hidden}
            onHide={onHide} onUnhide={onUnhide}
            onHideAll={onHideAll} onUnhideAll={onUnhideAll}
          />
        </div>
      ) : view==="grid" ? (
        <ServiceGrid
          monitorsAll={filteredAll}
          hiddenSet={hidden}
          onHideAll={onHideAll}
          onUnhideAll={onUnhideAll}
          onOpen={openInstance}
        />
      ) : (
        <MonitorsTable
          monitors={visible}
          hiddenSet={hidden}
          onHide={onHide}
          onUnhide={onUnhide}
          slaConfig={SLA_CONFIG}
        />
      )}
    </div>
  );
}
JSX

###############################################################################
# 10) styles.css – estilos para header/cards/alerts/sparkline
###############################################################################
echo "== Añadiendo estilos a src/styles.css =="
[ -f src/styles.css ] && cp src/styles.css src/styles.css.bak.$TS || touch src/styles.css
cat >> src/styles.css <<'CSS'

/* === Header cards === */
.k-cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:12px; margin:8px 0 16px; }
.k-card.k-card--summary { border:1px solid #e5e7eb; border-left:6px solid #e5e7eb; border-radius:10px; background:#fff; padding:12px; }
.k-card__title { font-weight:600; margin-bottom:6px; }
.k-metric { font-size:20px; font-weight:700; margin-right:6px; }
.k-label { color:#6b7280; font-size:12px; }
.is-clickable { cursor:pointer; transition: box-shadow .15s ease; }
.is-clickable:hover { box-shadow:0 2px 10px rgba(0,0,0,.06); }
.is-active { outline:2px solid #93c5fd; background:#f0f9ff; }

/* === Alerts banner === */
.k-alerts { position:sticky; top:0; z-index: 50; display:flex; flex-direction:column; gap:8px; margin-bottom:8px; }
.k-alert { display:flex; justify-content:space-between; align-items:center; padding:10px 12px; border-radius:8px; }
.k-alert--danger { background:#fee2e2; color:#991b1b; border:1px solid #fecaca; }
.k-alert__close { background:transparent; border:0; font-size:14px; cursor:pointer; color:#991b1b; }

/* === Site cards === */
.k-card.k-card--site { border:1px solid #e5e7eb; border-radius:12px; background:#fff; padding:14px; display:flex; flex-direction:column; gap:12px; min-height:160px; overflow:hidden; }
.k-card__head { display:flex; justify-content:space-between; align-items:center; }
.k-card__title { margin:0; font-size:16px; font-weight:700; }
.k-badge { font-size:12px; font-weight:600; padding:4px 10px; border-radius:999px; color:#fff; }
.k-badge--ok { background:#16a34a; }
.k-badge--danger { background:#dc2626; }
.k-stats { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:6px; }
.k-val { font-weight:700; }
.k-actions { display:flex; gap:8px; flex-wrap:nowrap; justify-content:space-between; white-space:nowrap; }
.k-btn { font-size:12px; padding:6px 10px; border-radius:8px; cursor:pointer; border:1px solid transparent; }
.k-btn--primary { border-color:#2563eb; color:#2563eb; background:#eff6ff; }
.k-btn--danger  { border-color:#dc2626; color:#dc2626; background:#fef2f2; }
.k-btn--ghost   { border-color:#cbd5e1; color:#334155; background:#fff; }
.k-btn:hover    { filter:brightness(.97); }

/* === Grid general === */
.grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap:12px; }
CSS

echo ""
echo "✅ Upgrade aplicado. Ejecuta ahora: npm run dev"
echo "• Header muestra MONITORES (UP/DOWN/Total/Prom) según filtros y permite clic para filtrar."
echo "• Cards con badges OK/Incidencias + sparkline B1."
echo "• Polling cada 5s guarda histórico local y dispara alertas por nuevos DOWN."
echo "• Alertas se limpian al volver UP o tras ${ALERT_AUTOCLOSE_MS} ms."
