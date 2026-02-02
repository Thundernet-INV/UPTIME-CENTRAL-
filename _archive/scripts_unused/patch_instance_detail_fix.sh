#!/bin/sh
set -eu

ROOT="/home/thunder/kuma-dashboard-clean/kuma-ui"
FILE="$ROOT/src/components/InstanceDetail.jsx"
BAK="$FILE.bak_$(date +%Y%m%d_%H%M%S)"

[ -f "$FILE" ] && cp "$FILE" "$BAK" || true

cat > "$FILE" <<'JSX'
import React, { useEffect, useMemo, useState } from "react";
import ChartFallback from "./ChartFallback.jsx";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx";
import Logo from "./Logo.jsx";
import MonitorCard from "./MonitorCard.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

/**
 * NOTAS CLAVES:
 * - History.* devuelve Promises. Aquí SIEMPRE esperamos (useEffect) y guardamos arrays en estado.
 * - ChartFallback se dibuja ENCIMA de la gráfica nativa (HistoryChart).
 * - Refrescamos series cada ~10s; la tabla/sparklines también reciben arrays (no promesas).
 */

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  const [mode, setMode] = useState("table");          // table | grid
  const [focus, setFocus] = useState(null);           // monitor_name | null

  // Grupo de monitores de la sede
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // --- Estado de series (listas reales, no promesas)
  const [seriesInstance, setSeriesInstance] = useState([]);         // promedio sede
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());      // nombre -> puntos
  const [lastTick, setLastTick] = useState(0);                      // p/ forzar refresh periódico

  // Timer de refresco (cada 10s)
  useEffect(() => {
    const t = setInterval(() => setLastTick(Date.now()), 10000);
    return () => clearInterval(t);
  }, []);

  // Cargar promedio de sede (15 min)
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const arr = await History.getAvgSeriesByInstance(instanceName, 15 * 60 * 1000);
        if (!alive) return;
        setSeriesInstance(Array.isArray(arr) ? arr : []);
      } catch {
        if (!alive) return;
        setSeriesInstance([]);
      }
    })();
    return () => { alive = false; };
  }, [instanceName, lastTick]);

  // Cargar series por monitor de esta sede (15 min)
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name || "";
            const arr = await History.getSeriesForMonitor(instanceName, name, 15 * 60 * 1000);
            return [name, Array.isArray(arr) ? arr : []];
          })
        );
        if (!alive) return;
        setSeriesMonMap(new Map(entries));
      } catch {
        if (!alive) return;
        setSeriesMonMap(new Map());
      }
    })();
    return () => { alive = false; };
  }, [instanceName, group.length, lastTick]);

  // Modo de gráfica principal
  const chartMode = focus ? "monitor" : "instance";
  const chartSeries = focus
    ? (seriesMonMap.get(focus) || [])
    : seriesInstance;

  return (
    <div>
      {/* Header sede */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
        <button className="k-btn k-btn--primary" onClick={() => window.history.back()}>
          ← Volver
        </button>
        <h2 style={{ margin: 0 }}>{instanceName}</h2>
        <div style={{ marginLeft: "auto", display: "flex", gap: 6 }}>
          <button
            type="button"
            className={`btn tab ${mode === "table" ? "active" : ""}`}
            aria-pressed={mode === "table"}
            onClick={() => setMode("table")}
          >
            Tabla
          </button>
          <button
            type="button"
            className={`btn tab ${mode === "grid" ? "active" : ""}`}
            aria-pressed={mode === "grid"}
            onClick={() => setMode("grid")}
          >
            Grilla
          </button>
        </div>
      </div>

      {/* Chip modo */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>{" "}
            <button
              className="k-btn k-btn--ghost"
              style={{ marginLeft: 8 }}
              onClick={() => setFocus(null)}
            >
              Ver sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            Mostrando: <strong>Promedio de la sede</strong>
          </div>
        )}
      </div>

      {/* Fallback ENCIMA de la gráfica nativa */}
      {!focus && (
        <ChartFallback instance={instanceName} minutes={15} height={200} />
      )}

      {/* Gráfica nativa con ARRAYS reales */}
      {chartMode === "monitor" ? (
        <HistoryChart mode="monitor" seriesMon={chartSeries} title={focus || "Latencia (ms)"} />
      ) : (
        <HistoryChart mode="instance" series={chartSeries} />
      )}

      {/* Acciones ocultar/mostrar */}
      <div style={{ marginTop: 12 }}>
        <button
          className="k-btn k-btn--danger"
          onClick={() => onHideAll?.(instanceName)}
          style={{ marginRight: 8 }}
        >
          Ocultar todos
        </button>
        <button className="k-btn k-btn--ghost" onClick={() => onUnhideAll?.(instanceName)}>
          Mostrar todos
        </button>
      </div>

      {/* Listado de servicios */}
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
                const lat =
                  typeof m.latest?.responseTime === "number"
                    ? `${m.latest.responseTime} ms`
                    : "—";
                const host = hostFromUrl(m.info?.monitor_url || "");
                const name = m.info?.monitor_name || "";
                const seriesMon = seriesMonMap.get(name) || []; // ARRAY real
                return (
                  <tr key={i}>
                    <td
                      className="k-cell-service"
                      onClick={() => setFocus(m.info?.monitor_name)}
                      style={{ cursor: "pointer" }}
                    >
                      <Logo monitor={m} size={18} href={m.info?.monitor_url || ""} />
                      <div className="k-service-text">
                        <div className="k-service-name">{name}</div>
                        <div className="k-service-sub">
                          {host || m.info?.monitor_url || ""}
                        </div>
                      </div>
                    </td>
                    <td style={{ fontWeight: "bold", color: st === "UP" ? "#16a34a" : "#dc2626" }}>
                      {icon} {st}
                    </td>
                    <td>{lat}</td>
                    <td style={{ minWidth: 120 }}>
                      <Sparkline points={seriesMon} color={st === "UP" ? "#16a34a" : "#dc2626"} />
                    </td>
                    <td>
                      <button
                        className="k-btn k-btn--ghost"
                        onClick={() => onHide?.(m.instance, name)}
                      >
                        Ocultar
                      </button>
                      <button
                        className="k-btn k-btn--ghost"
                        style={{ marginLeft: 6 }}
                        onClick={() => onUnhide?.(m.instance, name)}
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
              const name = m.info?.monitor_name || "";
              const seriesMon = seriesMonMap.get(name) || []; // ARRAY real
              return (
                <MonitorCard
                  key={i}
                  monitor={m}
                  series={seriesMon}
                  onHide={onHide}
                  onUnhide={onUnhide}
                  onFocus={(nm) => setFocus(nm)}
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

echo "== Compilando =="
cd "$ROOT"
npm run build

echo "== Desplegando =="
rsync -av --delete "$ROOT/dist/" /var/www/uptime8081/dist/
nginx -t && systemctl reload nginx

echo "✓ InstanceDetail.jsx corregido: datos asíncronos esperados + fallback arriba del chart nativo."
