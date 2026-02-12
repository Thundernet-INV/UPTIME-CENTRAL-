import React, { useEffect, useMemo, useState, useRef } from "react";
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
  const [loading, setLoading] = useState(true);
  const loadedRef = useRef(false);

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // 🚀 CARGA INMEDIATA - Sin esperar nada
  useEffect(() => {
    if (loadedRef.current) return;
    loadedRef.current = true;
    
    let isMounted = true;
    
    const loadAll = async () => {
      setLoading(true);
      console.log(`🚀 Cargando ${instanceName}...`);
      
      try {
        // 1. Cargar promedio PRIMERO (rápido)
        const avg = await History.getAvgSeriesByInstance(instanceName, 3600000);
        if (isMounted) {
          setAvgSeries(avg || []);
          console.log(`✅ Promedio de ${instanceName}: ${avg?.length || 0} puntos`);
        }
        
        // 2. Cargar monitores DESPUÉS (en paralelo)
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const series = await History.getSeriesForMonitor(
              instanceName,
              name,
              3600000
            );
            return [name, series || []];
          })
        );
        
        if (isMounted) {
          setSeriesMonMap(new Map(entries));
          setLoading(false);
          console.log(`✅ ${entries.length} monitores cargados`);
        }
      } catch (error) {
        console.error(`Error cargando ${instanceName}:`, error);
        if (isMounted) setLoading(false);
      }
    };
    
    loadAll();
    
    return () => { isMounted = false; };
  }, [instanceName, group]); // SIN tick - no recargar cada 30 segundos

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
              Ver promedio
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
          {loading && !focus && avgSeries.length === 0 ? (
            <div style={{
              height: '300px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: 'var(--bg-secondary, #f9fafb)',
              borderRadius: '8px'
            }}>
              <p style={{ color: 'var(--text-secondary, #6b7280)' }}>
                Cargando {instanceName}...
              </p>
            </div>
          ) : (
            <HistoryChart
              mode={focus ? "monitor" : "instance"}
              seriesMon={chartData}
              title={focus || `${instanceName} (promedio)`}
            />
          )}

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
