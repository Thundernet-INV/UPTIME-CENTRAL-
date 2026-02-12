import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  // Refresco periódico
  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  // Monitores de la sede actual (desde props)
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // ✅ PROMEDIO DE SEDE - Usa getAvgSeriesByInstance
  useEffect(() => {
    let alive = true;
    
    const fetchAvg = async () => {
      try {
        console.log(`🏢 Cargando promedio de ${instanceName}`);
        const series = await History.getAvgSeriesByInstance(instanceName, 60 * 60 * 1000);
        if (alive) {
          setAvgSeries(series || []);
          console.log(`✅ Promedio de ${instanceName}: ${series.length} puntos`);
        }
      } catch (error) {
        console.error(`Error cargando promedio de ${instanceName}:`, error);
        if (alive) setAvgSeries([]);
      }
    };
    
    fetchAvg();
    
    return () => { alive = false; };
  }, [instanceName, tick]);

  // ✅ MONITORES INDIVIDUALES
  useEffect(() => {
    let alive = true;
    
    const fetchMonitors = async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const series = await History.getSeriesForMonitor(
              instanceName,
              name,
              60 * 60 * 1000
            );
            return [name, series || []];
          })
        );
        
        if (alive) {
          setSeriesMonMap(new Map(entries));
        }
      } catch (error) {
        console.error(`Error cargando monitores de ${instanceName}:`, error);
        if (alive) setSeriesMonMap(new Map());
      }
    };
    
    fetchMonitors();
    
    return () => { alive = false; };
  }, [instanceName, group.length, tick]);

  // Datos para la gráfica
  const chartData = focus 
    ? seriesMonMap.get(focus) || [] 
    : avgSeries;

  return (
    <div className="instance-detail-page">
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
      </div>

      <div className="instance-detail-chip-row">
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>
            <button
              className="k-btn k-btn--ghost k-chip-action"
              onClick={() => setFocus(null)}
            >
              Ver promedio de sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            <span>📊 <strong>Promedio de {instanceName}</strong></span>
          </div>
        )}
      </div>

      <section className="instance-detail-grid">
        <div className="instance-detail-chart">
          <HistoryChart
            mode={focus ? "monitor" : "instance"}
            seriesMon={chartData}
            title={focus || "Promedio de sede"}
          />

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

        {group.map((m, i) => {
          const name = m.info?.monitor_name ?? "";
          const seriesMon = seriesMonMap.get(name) ?? [];
          const isSelected = focus === name;
          
          return (
            <div
              key={name || i}
              className={`instance-detail-service-card ${isSelected ? 'selected' : ''}`}
              onClick={() => setFocus(name)}
              style={{ cursor: 'pointer' }}
            >
              <ServiceCard service={m} series={seriesMon} />
            </div>
          );
        })}
      </section>
    </div>
  );
}
