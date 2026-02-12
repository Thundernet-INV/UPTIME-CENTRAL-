import React, { useEffect, useMemo, useState, useCallback } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";
import { useTimeRange, TIME_RANGE_CHANGE_EVENT } from "./TimeRangeSelector.jsx";

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
  const [rangeValue, setRangeValue] = useState(selectedRange.value);
  
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [loading, setLoading] = useState(true);
  const [loadingMonitors, setLoadingMonitors] = useState(false);

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = (e) => {
      console.log(`📊 InstanceDetail (${instanceName}) - Rango cambiado a: ${e.detail.label}`);
      setRangeValue(e.detail.value);
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, [instanceName]);

  // 🟢 CARGAR PROMEDIO DE SEDE - SE ACTUALIZA CUANDO CAMBIA EL RANGO
  useEffect(() => {
    let isMounted = true;
    
    const fetchAvg = async () => {
      if (!instanceName) return;
      
      setLoading(true);
      console.log(`🏢 Cargando promedio de ${instanceName} (${selectedRange.label})...`);
      
      try {
        // Usar getAvgSeriesByInstance que consulta monitorId = "Instancia_avg"
        const series = await History.getAvgSeriesByInstance(
          instanceName, 
          rangeValue, 
          60000
        );
        
        if (isMounted) {
          setAvgSeries(series || []);
          console.log(`✅ Promedio de ${instanceName}: ${series?.length || 0} puntos (${selectedRange.label})`);
        }
      } catch (error) {
        console.error(`Error cargando promedio de ${instanceName}:`, error);
        if (isMounted) setAvgSeries([]);
      } finally {
        if (isMounted) setLoading(false);
      }
    };
    
    fetchAvg();
    
    return () => { isMounted = false; };
  }, [instanceName, rangeValue, selectedRange.label]);

  // 🟢 CARGAR MONITORES INDIVIDUALES - SOLO CUANDO SE SELECCIONA UNO
  useEffect(() => {
    if (!focus) return;
    
    let isMounted = true;
    
    const fetchMonitor = async () => {
      setLoadingMonitors(true);
      console.log(`🔍 Cargando monitor ${focus} en ${instanceName} (${selectedRange.label})...`);
      
      try {
        const series = await History.getSeriesForMonitor(
          instanceName,
          focus,
          rangeValue
        );
        
        if (isMounted) {
          setSeriesMonMap(prev => new Map(prev).set(focus, series || []));
          console.log(`✅ Monitor ${focus}: ${series?.length || 0} puntos`);
        }
      } catch (error) {
        console.error(`Error cargando monitor ${focus}:`, error);
      } finally {
        if (isMounted) setLoadingMonitors(false);
      }
    };
    
    fetchMonitor();
    
    return () => { isMounted = false; };
  }, [instanceName, focus, rangeValue, selectedRange.label]);

  // Limpiar selección al cambiar de sede
  useEffect(() => {
    setFocus(null);
    setAvgSeries([]);
    setSeriesMonMap(new Map());
  }, [instanceName]);

  // Datos para la gráfica
  const chartData = focus 
    ? seriesMonMap.get(focus) || [] 
    : avgSeries;

  const chartTitle = focus 
    ? `${focus} - ${instanceName}` 
    : `Promedio de ${instanceName}`;

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
        {/* Mostrar rango actual */}
        <span style={{
          marginLeft: '12px',
          padding: '4px 12px',
          background: 'var(--bg-tertiary, #f3f4f6)',
          borderRadius: '16px',
          fontSize: '0.75rem',
          color: 'var(--text-secondary, #6b7280)'
        }}>
          📊 {selectedRange.label}
        </span>
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
          ) : (
            <HistoryChart
              mode="instance"
              seriesMon={chartData}
              title={chartTitle}
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
