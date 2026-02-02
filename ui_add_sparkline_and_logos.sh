#!/bin/sh
# Uptime Central – Logos + Sparkline por servicio + Tabla en InstanceDetail + Card clicable + Solo DOWN
set -eu
TS=$(date +%Y%m%d%H%M%S)

need() { [ -f "$1" ] || { echo "[ERROR] Falta $1" >&2; exit 1; }; }

echo "== Validando proyecto =="
need package.json
mkdir -p src/components src/lib public/logos

echo "== Asegurando dependencias de gráficos =="
npm i chart.js react-chartjs-2 --save >/dev/null 2>&1 || true

###############################################################################
# 1) historyEngine.js – añade series por monitor (para sparkline por servicio)
###############################################################################
[ -f src/historyEngine.js ] && cp src/historyEngine.js src/historyEngine.js.bak.$TS
cat > src/historyEngine.js <<'JS'
// Simple history engine (localStorage) – snapshots de monitores
const KEY = "kuma_history_snapshots_v1";
const MAX = 500;          // ~41' si se hace polling cada 5s
const SPARK_POINTS = 120; // para sparkline (suave)

function load() { try { return JSON.parse(localStorage.getItem(KEY) || "[]"); } catch { return []; } }
function save(arr){ try { localStorage.setItem(KEY, JSON.stringify(arr)); } catch {} }
function now(){ return Date.now(); }

// Aux
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
  // match por nombre de monitor; si no, intenta por hostname
  const direct = monitors.find(m => m.instance===instance && (m.info?.monitor_name===name));
  if (direct) return direct;
  const wanted = (name||'').toLowerCase().trim();
  return monitors.find(m => m.instance===instance && (m.info?.monitor_name||'').toLowerCase().trim()===wanted);
}

const History = {
  addSnapshot(monitors) {
    const s = load(); s.push({ t: now(), monitors });
    while (s.length > MAX) s.shift();
    save(s);
  },
  // Serie de promedio de latencia por sede
  getAvgSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s){ xs.push(snap.t); ys.push(avgLatencyForInstance(snap.monitors, instance)); }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  // Serie de downs por sede
  getDownsSeriesByInstance(instance, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s){ xs.push(snap.t); ys.push(downCountForInstance(snap.monitors, instance)); }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  // Serie por monitor (para sparkline de cada servicio en detalle)
  getSeriesForMonitor(instance, monitorName, maxPoints = SPARK_POINTS) {
    const s = load(), xs=[], ys=[];
    for (const snap of s) {
      const m = findMonitor(snap.monitors, instance, monitorName);
      xs.push(snap.t);
      ys.push(typeof m?.latest?.responseTime === "number" ? m.latest.responseTime : null);
    }
    const start=Math.max(0,xs.length-maxPoints); return { t: xs.slice(start), v: ys.slice(start) };
  },
  // Datos completos para gráfica grande en sede (promedio + downs)
  getAllForInstance(instance, maxPoints = MAX) {
    const lat = this.getAvgSeriesByInstance(instance, maxPoints);
    const dwn = this.getDownsSeriesByInstance(instance, maxPoints);
    return { lat, dwn };
  }
};
export default History;
JS
echo "✔ src/historyEngine.js listo"

###############################################################################
# 2) logos util – fuente de logos por servicio (mapping + clearbit + google favicon)
###############################################################################
cat > src/lib/logoUtil.js <<'JS'
export function hostFromUrl(u){
  try { return new URL(u).hostname.replace(/^www\./,''); } catch { return ''; }
}
export function norm(s=''){ return s.toLowerCase().replace(/\s+/g,'').trim(); }

const MAP = {
  whatsapp: '/logos/whatsapp.svg',
  facebook: '/logos/facebook.svg',
  instagram: '/logos/instagram.svg',
  tiktok: '/logos/tiktok.svg',
  youtube: '/logos/youtube.svg',
  google: '/logos/google.svg',
  microsoft: '/logos/microsoft.svg',
  netflix: '/logos/netflix.svg',
  telegram: '/logos/telegram.svg',
  apple: '/logos/apple.svg',
};

export function getLogoSrc(m){
  const name = norm(m?.info?.monitor_name || '');
  const host = hostFromUrl(m?.info?.monitor_url || '');
  // 1) mapping por nombre u host
  for (const k of Object.keys(MAP)){
    if (name.includes(k) || host.includes(k)) return MAP[k];
  }
  // 2) clearbit (logo grande) – si host existe
  if (host) return `https://logo.clearbit.com/${host}`;
  // 3) google favicon como reserva
  if (host) return `https://www.google.com/s2/favicons?domain=${host}&sz=64`;
  // 4) sin logo
  return null;
}

export function initialsFor(m){
  const n = (m?.info?.monitor_name || '').trim();
  if (!n) return '?';
  const parts = n.split(/\s+/);
  const ini = (parts[0][0]||'').toUpperCase() + (parts[1]?.[0]||'').toUpperCase();
  return ini || n[0].toUpperCase();
}
JS
echo "✔ src/lib/logoUtil.js listo"
mkdir -p public/logos  # aquí puedes copiar tus SVGs para marcas conocidas

###############################################################################
# 3) Sparkline.jsx – si no existe, crearlo (B1 ya sin adapter de fecha)
###############################################################################
if [ ! -f src/components/Sparkline.jsx ]; then
cat > src/components/Sparkline.jsx <<'JSX'
import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS, LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Filler
} from "chart.js";
ChartJS.register(LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Filler);

export default function Sparkline({ points, color="#2563eb", height=42 }) {
  const labels = useMemo(() => (points?.t ?? []).map((_, i) => i), [points]);
  const data = useMemo(() => ({
    labels,
    datasets: [{
      data: points?.v ?? [],
      borderColor: color,
      backgroundColor: (ctx)=>{
        const chart = ctx.chart;
        if (!chart?.chartArea) return color + "22";
        const { ctx: c, chartArea } = chart;
        const g = c.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
        g.addColorStop(0, color + "40");
        g.addColorStop(1, color + "00");
        return g;
      },
      tension: 0.35, borderWidth: 2, pointRadius: 0, fill: true, spanGaps: true
    }]
  }), [labels, points, color]);
  const options = { responsive:true, maintainAspectRatio:false, scales:{x:{display:false}, y:{display:false}}, plugins:{legend:{display:false}, tooltip:{enabled:false}} };
  return (<div style={{height}}><Line data={data} options={options}/></div>);
}
JSX
echo "✔ src/components/Sparkline.jsx creado"
fi

###############################################################################
# 4) InstanceDetail.jsx – TABLA con logo + sparkline por servicio
###############################################################################
[ -f src/components/InstanceDetail.jsx ] && cp src/components/InstanceDetail.jsx src/components/InstanceDetail.jsx.bak.$TS
cat > src/components/InstanceDetail.jsx <<'JSX'
import React, { useMemo } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx";
import { getLogoSrc, hostFromUrl, initialsFor } from "../lib/logoUtil.js";

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
            const logo = getLogoSrc(m);
            const host = hostFromUrl(m.info?.monitor_url || '');
            const seriesMon = History.getSeriesForMonitor(instanceName, m.info?.monitor_name);
            return (
              <tr key={i}>
                <td className="k-cell-service">
                  {logo ? (
                    <img className="k-logo" src={logo} alt="" onError={(e)=>{e.currentTarget.style.display='none'}}/>
                  ) : (
                    <div className="k-logo k-logo--fallback">{initialsFor(m)}</div>
                  )}
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
echo "✔ InstanceDetail.jsx con tabla + logos + sparkline por servicio"

###############################################################################
# 5) ServiceCard.jsx – card completa clicable (sin botón Abrir) + stopPropagation en acciones
###############################################################################
[ -f src/components/ServiceCard.jsx ] && cp src/components/ServiceCard.jsx src/components/ServiceCard.jsx.bak.$TS
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

      {spark ? <div style={{ marginBottom: 8 }}>
        <Sparkline points={spark} color={hasIncidents ? "#ef4444" : "#16a34a"} />
      </div> : null}

      <div className="k-stats">
        <div><span className="k-label">UP:</span> <span className="k-val">{up}</span></div>
        <div><span className="k-label">DOWN:</span> <span className="k-val">{down}</span></div>
        <div><span className="k-label">Total:</span> <span className="k-val">{total}</span></div>
        <div><span className="k-label">Prom:</span> <span className="k-val">{avg != null ? `${avg} ms` : "—"}</span></div>
      </div>

      <div className="k-actions" onClick={stop}>
        <button className="k-btn k-btn--danger" onClick={()=>onHideAll?.(sede)}>Ocultar todos</button>
        <button className="k-btn k-btn--ghost" onClick={()=>onUnhideAll?.(sede)}>Mostrar todos</button>
      </div>
    </div>
  );
}
JSX
echo "✔ ServiceCard.jsx card clicable"

###############################################################################
# 6) Filters.jsx – “Solo DOWN” conectado a status
###############################################################################
[ -f src/components/Filters.jsx ] && cp src/components/Filters.jsx src/components/Filters.jsx.bak.$TS
cat > src/components/Filters.jsx <<'JSX'
import React from "react";

export default function Filters({ monitors, value, onChange }) {
  function set(k, v) { onChange({ ...value, [k]: v }); }
  function toggleDown(e){ set("status", e.target.checked ? "down" : "all"); }

  return (
    <div className="filters">
      <select value={value.instance} onChange={(e)=>set("instance", e.target.value)}>
        <option value="">Todas las sedes</option>
        {[...new Set(monitors.map(m=>m.instance))].sort().map(n=>(
          <option key={n} value={n}>{n}</option>
        ))}
      </select>

      <select value={value.type} onChange={(e)=>set("type", e.target.value)}>
        <option value="">Todos los tipos</option>
        {[...new Set(monitors.map(m=>m.info?.monitor_type))].sort().map(t=>(
          <option key={t} value={t}>{t}</option>
        ))}
      </select>

      <input type="text" placeholder="Buscar..." value={value.q} onChange={(e)=>set("q", e.target.value)} />

      <label style={{ marginLeft: 12 }}>
        <input type="checkbox" checked={value.status==="down"} onChange={toggleDown} />
        {" "}Solo DOWN
      </label>
    </div>
  );
}
JSX
echo "✔ Filters.jsx Solo DOWN enlazado"

###############################################################################
# 7) CSS – logos en tabla + cell servicio + hover en cards
###############################################################################
[ -f src/styles.css ] && cp src/styles.css src/styles.css.bak.$TS || touch src/styles.css
cat >> src/styles.css <<'CSS'

/* ====== Tabla de servicios en detalle ====== */
.k-table { width:100%; border-collapse: collapse; margin-top: 12px; }
.k-table th { text-align:left; padding:8px; background:#f3f4f6; border-bottom:2px solid #e5e7eb; font-size:14px; }
.k-table td { padding:8px; border-bottom:1px solid #e5e7eb; font-size:14px; vertical-align: middle; }

.k-cell-service { display:flex; align-items:center; gap:10px; }
.k-logo { width:18px; height:18px; border-radius:4px; border:1px solid #e5e7eb; background:#fff; object-fit:contain; }
.k-logo--fallback { width:18px; height:18px; display:flex; align-items:center; justify-content:center; font-size:10px; border-radius:4px; background:#e5e7eb; color:#374151; }
.k-service-text { display:flex; flex-direction:column; }
.k-service-name { font-weight:600; }
.k-service-sub { font-size:12px; color:#6b7280; }

/* Cards clicables */
.k-card--site.clickable { cursor:pointer; }
.k-card--site.clickable:hover { box-shadow:0 4px 12px rgba(0,0,0,.08); }
CSS

echo
echo "✅ Listo. Ejecuta: npm run dev"
echo "• InstanceDetail ahora es TABLA con logos + sparkline por servicio."
echo "• Tarjetas de sede: clic en cualquier parte abre el detalle (botones no disparan apertura)."
echo "• 'Solo DOWN' filtrando correctamente."
echo "• Opcional: coloca tus SVG en public/logos/ (whatsapp.svg, facebook.svg, netflix.svg, etc.)."
