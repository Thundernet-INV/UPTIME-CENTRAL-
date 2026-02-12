import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import Sparkline from "./Sparkline.jsx"; // por si quieres seguir usando la tabla en el futuro
import Logo from "./Logo.jsx";
import ServiceCard from "./ServiceCard.jsx";
import { hostFromUrl } from "../lib/logoUtil.js";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  const [focus, setFocus] = useState(null); // monitor_name

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // Series de historial
  const [seriesInstance, setSeriesInstance] = useState({});
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  // Refresco periódico (10s) para ir actualizando history
  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  // Promedio de sede (15 min)
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const obj = await History.getAllForInstance(
          instanceName,
          rangeMs
        );
        if (!alive) return;
        setSeriesInstance(obj ?? {});
      } catch {
        if (!alive) return;
        setSeriesInstance({});
      }
    })();
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick]);

  // Series por monitor (15 min)
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const arr = await History.getSeriesForMonitor(
              instanceName,
              name,
              rangeMs
            );
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
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick]);

  // Fuente del chart principal
  const chartMode = focus ? "monitor" : "instance";
  const chartSeries = focus ? seriesMonMap.get(focus) ?? [] : seriesInstance;

  return (
    <div className="instance-detail-page">
      {/* Header sede */}
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
      </div>

      {/* Chip contexto */}
      <div className="instance-detail-chip-row">
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>
            <button
              className="k-btn k-btn--ghost k-chip-action"
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

      {/* GRID: gráfica en el centro, cards alrededor */}
      <section
        className="instance-detail-grid"
        aria-label={`Historial y servicios de ${instanceName}`}
      >
        {/* Gráfica en columna central */}
        <div className="instance-detail-chart">
          {chartMode === "monitor" ? (
            <HistoryChart
              mode="monitor"
              seriesMon={chartSeries}
              title={focus ?? "Latencia (ms)"}
            />
          ) : (
            <HistoryChart mode="instance" series={chartSeries} />
          )}

          {/* Acciones globales debajo de la gráfica */}
          <div className="instance-detail-actions">
            <button
              className="k-btn k-btn--danger"
              onClick={() => onHideAll?.(instanceName)}
            >
              Ocultar todos
            </button>
            <button
              className="k-btn k-btn--ghost"
              onClick={() => onUnhideAll?.(instanceName)}
            >
              Mostrar todos
            </button>
          </div>
        </div>

        {/* Cards de servicio alrededor */}
        {group.map((m, i) => {
          const name = m.info?.monitor_name ?? "";
          const seriesMon = seriesMonMap.get(name) ?? [];
          return (
            <div
              key={name || i}
              className="instance-detail-service-card"
              onClick={() => setFocus(name)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  setFocus(name);
                }
              }}
            >
              <ServiceCard service={m} series={seriesMon} />
            </div>
          );
        })}
      </section>
    </div>
  );
}
``
