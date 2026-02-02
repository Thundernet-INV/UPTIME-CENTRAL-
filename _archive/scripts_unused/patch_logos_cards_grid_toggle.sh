#!/bin/sh
# Uptime Central – Logos clicables en cards y grilla + toggle Tabla/Grilla en instancia
set -eu
TS=$(date +%Y%m%d%H%M%S)

mkdir -p src/components src/lib public/logos

echo "== Backups si existen =="
[ -f src/components/Logo.jsx ] && cp src/components/Logo.jsx src/components/Logo.jsx.bak.$TS
[ -f src/components/InstanceDetail.jsx ] && cp src/components/InstanceDetail.jsx src/components/InstanceDetail.jsx.bak.$TS
[ -f src/components/MonitorCard.jsx ] && cp src/components/MonitorCard.jsx src/components/MonitorCard.jsx.bak.$TS
[ -f src/styles.css ] && cp src/styles.css src/styles.css.bak.$TS || touch src/styles.css

###############################################################################
# 1) Logo.jsx – ahora soporta href (clicable) y fallback seguro a iniciales
###############################################################################
cat > src/components/Logo.jsx <<'JSX'
import React, { useMemo, useState } from "react";
import { getLogoCandidates, initialsFor } from "../lib/logoUtil.js";

export default function Logo({ monitor, size=20, className="k-logo", href }) {
  const candidates = useMemo(()=>getLogoCandidates(monitor), [monitor]);
  const [idx, setIdx] = useState(0);

  const Img = (
    <img
      className={className}
      style={{ width: size, height: size }}
      src={candidates[idx] || ""}
      alt=""
      onError={()=> setIdx(i => i+1)}
    />
  );

  const Fallback = (
    <div className={className + " k-logo--fallback"} style={{ width: size, height: size }}>
      {initialsFor(monitor)}
    </div>
  );

  const content = (idx < candidates.length) ? Img : Fallback;

  if (href) {
    return (
      <a href={href} target="_blank" rel="noopener noreferrer" onClick={(e)=>e.stopPropagation()}>
        {content}
      </a>
    );
  }
  return content;
}
JSX

###############################################################################
# 2) MonitorCard.jsx – card para un servicio (logo clicable, estado, latencia)
###############################################################################
cat > src/components/MonitorCard.jsx <<'JSX'
import React from "react";
import Logo from "./Logo.jsx";
import Sparkline from "./Sparkline.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

export default function MonitorCard({ monitor, onHide, onUnhide, series, onClick }) {
  const stUp = monitor?.latest?.status === 1;
  const statusText = stUp ? "UP" : "DOWN";
  const color = stUp ? "#16a34a" : "#dc2626";
  const host = hostFromUrl(monitor?.info?.monitor_url || "");
  const latency = (typeof monitor?.latest?.responseTime === "number") ? `${monitor.latest.responseTime} ms` : "—";
  const href = monitor?.info?.monitor_url || "";

  function stop(e){ e.stopPropagation(); }

  return (
    <div className="svc-card" onClick={onClick}>
      <div className="svc-head">
        <Logo monitor={monitor} href={href} size={22} />
        <div className="svc-titles">
          <div className="svc-name">{monitor?.info?.monitor_name}</div>
          <div className="svc-sub">{host || (monitor?.info?.monitor_url || "")}</div>
        </div>
        <span className="svc-badge" style={{ background: color }}>{statusText}</span>
      </div>

      <div className="svc-body">
        <div className="svc-lat">
          <span className="svc-lab">Latencia:</span> <strong>{latency}</strong>
        </div>
        <div className="svc-spark">
          <Sparkline points={series} color={color} height={42} />
        </div>
      </div>

      <div className="svc-actions" onClick={stop}>
        <button className="k-btn k-btn--danger" onClick={()=>onHide?.(monitor.instance, monitor.info?.monitor_name)}>
          Ocultar
        </button>
        <button className="k-btn k-btn--ghost" onClick={()=>onUnhide?.(monitor.instance, monitor.info?.monitor_name)}>
          Mostrar
        </button>
      </div>
    </div>
  );
}
JSX

###############################################################################
# 3) InstanceDetail.jsx – toggle Tabla/Grilla + usa MonitorCard en grilla
###############################################################################
cat > src/components/InstanceDetail.jsx <<'JSX'
import React, { useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx";
import Logo from "./Logo.jsx";
import MonitorCard from "./MonitorCard.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide, onUnhide, onHideAll, onUnhideAll
}) {
  const [mode, setMode] = useState("table"); // "table" | "grid"

  const group = useMemo(
    () => monitorsAll.filter(m => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  const seriesAll = useMemo(
    () => History.getAllForInstance(instanceName),
    [instanceName, monitorsAll.length]
  );

  return (
    <div>
      <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:8}}>
        <button className="k-btn k-btn--primary" onClick={() => window.history.back()}>← Volver</button>
        <h2 style={{margin:0}}>{instanceName}</h2>

        <div style={{ marginLeft: "auto", display:"flex", gap:6 }}>
          <button className={`btn tab ${mode==="table"?"active":""}`} onClick={()=>setMode("table")}>Tabla</button>
          <button className={`btn tab ${mode==="grid"?"active":""}`} onClick={()=>setMode("grid")}>Grilla</button>
        </div>
      </div>

      <HistoryChart series={seriesAll} />

      <div style={{ marginTop: 12 }}>
        <button className="k-btn k-btn--danger" onClick={() => onHideAll?.(instanceName)} style={{ marginRight: 8 }}>
          Ocultar todos
        </button>
        <button className="k-btn k-btn--ghost" onClick={() => onUnhideAll?.(instanceName)}>
          Mostrar todos
        </button>
      </div>

      {mode === "table" ? (
        <>
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
                      <Logo monitor={m} size={18} href={m.info?.monitor_url || ""} />
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
        </>
      ) : (
        <>
          <h3 style={{ marginTop: 20 }}>Servicios</h3>
          <div className="k-grid-services">
            {group.map((m, i) => {
              const seriesMon = History.getSeriesForMonitor(instanceName, m.info?.monitor_name);
              const open = () => {
                const url = m.info?.monitor_url;
                if (url) window.open(url, "_blank", "noreferrer");
              };
              return (
                <MonitorCard
                  key={i}
                  monitor={m}
                  series={seriesMon}
                  onHide={onHide}
                  onUnhide={onUnhide}
                  onClick={open}
                />
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
JSX

###############################################################################
# 4) styles.css – estilos para grilla de servicios y cards con logo
###############################################################################
cat >> src/styles.css <<'CSS'

/* ====== Grilla de servicios en instancia ====== */
.k-grid-services {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px,1fr));
  gap: 12px;
  margin-top: 10px;
}

/* Card de servicio */
.svc-card {
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  background: #fff;
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  cursor: pointer;
}
.svc-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,.08); }

/* Cabecera */
.svc-head {
  display: grid;
  grid-template-columns: 22px 1fr auto;
  gap: 10px;
  align-items: center;
}
.svc-titles { display: flex; flex-direction: column; }
.svc-name { font-weight: 700; }
.svc-sub { font-size: 12px; color: #6b7280; }
.svc-badge {
  color: #fff; font-size: 12px; font-weight: 600;
  padding: 3px 8px; border-radius: 999px;
}

/* Cuerpo */
.svc-body { display: grid; grid-template-columns: 1fr 1fr; align-items: center; gap: 6px; }
.svc-lab { color: #6b7280; font-size: 12px; }
.svc-spark { min-width: 120px; }

/* Acciones */
.svc-actions { display:flex; gap:8px; margin-top:4px; }

/* Logo */
.k-logo { width: 18px; height: 18px; border-radius: 4px; border: 1px solid #e5e7eb; background: #fff; object-fit: contain; }
.k-logo--fallback { display:flex; align-items:center; justify-content:center; font-size:10px; background:#e5e7eb; color:#374151; }

/* Tabla ya estaba estilizada arriba; se mantiene */
CSS

echo
echo "✅ Patch aplicado. Ejecuta: npm run dev"
echo "• Verás logos en las cards de la grilla (dentro de cada instancia) y en la tabla."
echo "• El logo es clicable (abre el monitor_url en nueva pestaña)."
echo "• En cada instancia puedes alternar Tabla/Grilla."
