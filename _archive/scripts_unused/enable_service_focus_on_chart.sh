#!/bin/sh
# Hacer que la gráfica de la sede muestre el servicio clickeado (focus),
# con "Ver sede" para volver. Logos siguen siendo clickeables al sitio.
set -eu
TS=$(date +%Y%m%d%H%M%S)

need(){ [ -f "$1" ] || { echo "[ERROR] Falta $1"; exit 1; }; }

echo "== Validando =="
need package.json
need src/components/HistoryChart.jsx
need src/components/InstanceDetail.jsx
need src/components/MonitorCard.jsx
[ -f src/styles.css ] || touch src/styles.css

echo "== Backups =="
cp src/components/HistoryChart.jsx src/components/HistoryChart.jsx.bak.$TS
cp src/components/InstanceDetail.jsx src/components/InstanceDetail.jsx.bak.$TS
cp src/components/MonitorCard.jsx src/components/MonitorCard.jsx.bak.$TS
cp src/styles.css src/styles.css.bak.$TS

###############################################################################
# 1) HistoryChart.jsx: soportar modo "monitor" (serie única de latencia)
###############################################################################
cat > src/components/HistoryChart.jsx <<'JSX'
import React, { useMemo } from "react";
import { Line } from "react-chartjs-2";
import {
  Chart as ChartJS,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Tooltip,
  Legend,
  Filler,
} from "chart.js";
import 'chartjs-adapter-date-fns';
import { es } from 'date-fns/locale';
ChartJS.register(LineElement, PointElement, LinearScale, TimeScale, Tooltip, Legend, Filler);

/**
 * Props:
 * - mode: "instance" | "monitor"
 * - series: { lat:{t:number[], v:(number|null)[]}, dwn:{t:number[], v:(number|null)[]} }  (para instance)
 * - seriesMon: { t:number[], v:(number|null)[] }  (para monitor)
 * - title (opcional): texto a mostrar en leyenda/tooltip para monitor
 * - h: altura
 */
export default function HistoryChart({ mode="instance", series, seriesMon, title="Latencia (ms)", h=260 }) {
  const labels = useMemo(() => {
    if (mode === "monitor") return seriesMon?.t ?? [];
    return series?.lat?.t ?? [];
  }, [mode, series, seriesMon]);

  const data = useMemo(() => {
    if (mode === "monitor") {
      const latVals = seriesMon?.v ?? [];
      return {
        labels,
        datasets: [{
          label: title,
          data: latVals,
          yAxisID: "y",
          borderColor: "#3b82f6",
          backgroundColor: "#3b82f622",
          tension: .35, pointRadius: 0, fill: true, spanGaps: true,
        }]
      };
    }
    // modo instancia (promedio + downs)
    const latVals = series?.lat?.v ?? [];
    const dwnVals = series?.dwn?.v ?? [];
    return {
      labels,
      datasets: [
        {
          label: "Prom (ms)",
          data: latVals,
          yAxisID: "y",
          borderColor: "#3b82f6",
          backgroundColor: "#3b82f622",
          tension: .35, pointRadius: 0, fill: true, spanGaps: true,
        },
        {
          label: "Downs",
          data: dwnVals,
          yAxisID: "y1",
          borderColor: "#ef4444",
          backgroundColor: "#ef444422",
          tension: .2, pointRadius: 0, fill: true, spanGaps: true,
        }
      ]
    };
  }, [mode, labels, series, seriesMon, title]);

  const options = {
    responsive: true, maintainAspectRatio: false,
    scales: {
      x: {
        type: 'time',
        time: {
          unit: 'minute',
          displayFormats: { minute: 'HH:mm', second: 'HH:mm:ss' },
          tooltipFormat: 'HH:mm:ss',
        },
        ticks: { autoSkip: true, maxTicksLimit: 8 },
        adapters: { date: { locale: es } },
        grid: { color: '#e5e7eb' },
      },
      y:  { position: "left",  grid: { color: "#e5e7eb" } },
      y1: { position: "right", grid: { drawOnChartArea: false } }
    },
    plugins: { legend: { position: "bottom" }, tooltip: { enabled: true } }
  };

  return <div style={{height:h}}><Line data={data} options={options}/></div>;
}
JSX

###############################################################################
# 2) MonitorCard.jsx: click en card -> enfocar servicio en la gráfica (no abrir URL).
#    Logo (imagen) sigue abriendo el sitio en pestaña nueva.
###############################################################################
cat > src/components/MonitorCard.jsx <<'JSX'
import React from "react";
import Logo from "./Logo.jsx";
import Sparkline from "./Sparkline.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

/**
 * Props:
 * - monitor, series
 * - onHide(instance,name), onUnhide(instance,name)
 * - onFocus(name): enfoca este monitor en la gráfica superior
 */
export default function MonitorCard({ monitor, onHide, onUnhide, series, onFocus }) {
  const stUp = monitor?.latest?.status === 1;
  const statusText = stUp ? "UP" : "DOWN";
  const color = stUp ? "#16a34a" : "#dc2626";
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
# 3) InstanceDetail.jsx: estado "focus" + pasar series a HistoryChart (monitor/instancia)
#    - En Tabla: clic en la celda de servicio enfoca.
#    - En Grilla: clic en la card enfoca.
#    - Botón "Ver sede" limpia el foco.
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
  const [focus, setFocus] = useState(null);  // monitor_name o null

  const group = useMemo(
    () => monitorsAll.filter(m => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  const seriesInstance = useMemo(
    () => History.getAllForInstance(instanceName),
    [instanceName, monitorsAll.length]
  );

  const chartMode   = focus ? "monitor"  : "instance";
  const chartSeries = focus ? History.getSeriesForMonitor(instanceName, focus) : seriesInstance;

  return (
    <div>
      <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:8}}>
        <button className="k-btn k-btn--primary" onClick={() => window.history.back()}>← Volver</button>
        <h2 style={{margin:0}}>{instanceName}</h2>

        <div style={{ marginLeft: "auto", display:"flex", gap:6 }}>
          <button type="button" className={`btn tab ${mode==="table"?"active":""}`} aria-pressed={mode==="table"} onClick={()=>setMode("table")}>Tabla</button>
          <button type="button" className={`btn tab ${mode==="grid"?"active":""}`} aria-pressed={mode==="grid"} onClick={()=>setMode("grid")}>Grilla</button>
        </div>
      </div>

      {/* Indicador de foco y botón limpiar */}
      <div style={{display:'flex', alignItems:'center', gap:8, marginBottom:6}}>
        {focus
          ? <div className="k-chip">Mostrando: <strong>{focus}</strong> <button className="k-btn k-btn--ghost" style={{marginLeft:8}} onClick={()=>setFocus(null)}>Ver sede</button></div>
          : <div className="k-chip k-chip--muted">Mostrando: <strong>Promedio de la sede</strong></div>
        }
      </div>

      {/* Gráfica */}
      {chartMode === "monitor"
        ? <HistoryChart mode="monitor" seriesMon={chartSeries} title={focus || "Latencia (ms)"} />
        : <HistoryChart mode="instance" series={chartSeries} />
      }

      {/* Acciones generales */}
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
                    <td className="k-cell-service" onClick={()=>setFocus(m.info?.monitor_name)} style={{cursor:'pointer'}}>
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
              return (
                <MonitorCard
                  key={i}
                  monitor={m}
                  series={seriesMon}
                  onHide={onHide}
                  onUnhide={onUnhide}
                  onFocus={(name)=>setFocus(name)}
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
# 4) Estilos mínimos para el chip de foco
###############################################################################
cat >> src/styles.css <<'CSS'

/* Indicador de foco sobre la gráfica */
.k-chip {
  display:inline-flex; align-items:center; gap:6px;
  background:#eef2ff; color:#1f2937; border:1px solid #c7d2fe;
  padding:4px 8px; border-radius:999px; font-size:12px;
}
.k-chip--muted {
  background:#f3f4f6; border-color:#e5e7eb;
}
CSS

echo
echo "✅ Listo. Ejecuta: npm run dev"
echo "• Clic en un servicio (en la tabla o grilla) enfoca su serie en la gráfica."
echo "• Botón 'Ver sede' vuelve al promedio de la sede."
echo "• Logo mantiene comportamiento: abre el sitio en nueva pestaña."
