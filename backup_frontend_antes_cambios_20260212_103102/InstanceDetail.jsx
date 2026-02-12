import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";
import { useTimeRange } from "./TimeRangeSelector.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  
  const [focus, setFocus] = useState(null); // null = promedio de sede
  const [instanceSeries, setInstanceSeries] = useState([]); // 🟢 AHORA ES ARRAY, no objeto
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [loading, setLoading] = useState(true);

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // 🟢 CARGAR PROMEDIO DE SEDE - INMEDIATAMENTE
  useEffect(() => {
    let isMounted = true;
    
    const fetchInstanceAverage = async () => {
      setLoading(true);
      console.log(`🏢 Solicitando promedio de ${instanceName} (${selectedRange.label})`);
      
      try {
        // USAR EL NUEVO ENDPOINT DE PROMEDIOS
        const series = await History.getInstanceAverageSeries(
          instanceName,
          selectedRange.value
        );
        
        if (isMounted) {
          setInstanceSeries(series || []);
          console.log(`✅ Promedio de ${instanceName}: ${series.length} puntos`);
        }
      } catch (error) {
        console.error(`Error cargando promedio de ${instanceName}:`, error);
        if (isMounted) setInstanceSeries([]);
      } finally {
        if (isMounted) setLoading(false);
      }
    };
    
    fetchInstanceAverage();
    
    // Escuchar cambios en el rango de tiempo
    const handleRangeChange = () => {
      fetchInstanceAverage();
    };
    
    window.addEventListener('time-range-change', handleRangeChange);
    return () => {
      isMounted = false;
      window.removeEventListener('time-range-change', handleRangeChange);
    };
  }, [instanceName, selectedRange.value, selectedRange.label]);

  // Cargar series de monitores individuales (cuando se selecciona uno)
  useEffect(() => {
    if (!focus) return;
    
    let isMounted = true;
    
    const fetchMonitorSeries = async () => {
      try {
        const series = await History.getSeriesForMonitor(
          instanceName,
          focus,
          selectedRange.value
        );
        
        if (isMounted) {
          setSeriesMonMap(prev => new Map(prev).set(focus, series || []));
        }
      } catch (error) {
        console.error(`Error cargando monitor ${focus}:`, error);
      }
    };
    
    fetchMonitorSeries();
    
    return () => {
      isMounted = false;
    };
  }, [instanceName, focus, selectedRange.value]);

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
              Ver promedio de sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span>📊 <strong>Promedio de {instanceName}</strong></span>
              <span style={{ 
                fontSize: '0.75rem', 
                background: 'var(--bg-tertiary, #f3f4f6)', 
                padding: '2px 8px', 
                borderRadius: '12px',
                color: 'var(--text-secondary, #6b7280)'
              }}>
                {selectedRange.label}
              </span>
            </span>
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
          {loading && !focus ? (
            <div style={{
              height: '300px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: 'var(--bg-secondary, #f9fafb)',
              borderRadius: '8px',
              border: '1px solid var(--border, #e5e7eb)'
            }}>
              <p style={{ color: 'var(--text-secondary, #6b7280)' }}>
                Cargando promedio de {instanceName}...
              </p>
            </div>
          ) : focus ? (
            <HistoryChart
              mode="monitor"
              seriesMon={seriesMonMap.get(focus) || []}
              title={focus}
            />
          ) : (
            <HistoryChart
              mode="instance"
              series={{ [instanceName]: instanceSeries }} // Formato compatible
            />
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
          const isSelected = focus === name;
          
          return (
            <div
              key={name || i}
              className={`instance-detail-service-card ${isSelected ? 'selected' : ''}`}
              onClick={() => setFocus(name)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  setFocus(name);
                }
              }}
              style={{
                cursor: 'pointer',
                border: isSelected ? '2px solid #3b82f6' : '1px solid transparent',
                transition: 'all 0.2s ease'
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
