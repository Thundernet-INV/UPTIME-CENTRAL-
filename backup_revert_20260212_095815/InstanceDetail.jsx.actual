import React, { useEffect, useMemo, useState } from "react";
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
  
  // Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = (e) => {
      console.log(`📊 InstanceDetail (${instanceName}) - Rango cambiado a:`, e.detail.label);
      setRangeValue(e.detail.value);
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, [instanceName]);
  
  // 🎯 MEJORA 3: focus = null POR DEFECTO (muestra promedio de sede)
  const [focus, setFocus] = useState(null);
  const [seriesInstance, setSeriesInstance] = useState({});
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  // Refresco periódico
  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // 🎯 MEJORA 3: Promedio de sede - SIEMPRE se carga al entrar
  useEffect(() => {
    let alive = true;
    
    const fetchInstanceData = async () => {
      try {
        console.log(`🏢 Cargando promedio de sede: ${instanceName} (${selectedRange.label})`);
        const obj = await History.getAllForInstance(
          instanceName,
          rangeValue
        );
        if (!alive) return;
        setSeriesInstance(obj ?? {});
        console.log(`✅ Promedio de sede cargado: ${instanceName}`);
      } catch (error) {
        console.error(`Error cargando promedio de sede ${instanceName}:`, error);
        if (!alive) return;
        setSeriesInstance({});
      }
    };
    
    fetchInstanceData();
    
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, rangeValue, selectedRange.label]);

  // Series por monitor (cuando se selecciona un servicio específico)
  useEffect(() => {
    let alive = true;
    
    const fetchMonitorSeries = async () => {
      if (!focus) {
        // Si no hay focus, no cargar series de monitores individuales
        return;
      }
      
      try {
        console.log(`🔍 Cargando serie para monitor: ${focus} (${selectedRange.label})`);
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            if (name !== focus) return null;
            
            const arr = await History.getSeriesForMonitor(
              instanceName,
              name,
              rangeValue
            );
            return [name, Array.isArray(arr) ? arr : []];
          })
        );
        
        if (!alive) return;
        
        const validEntries = entries.filter(Boolean);
        if (validEntries.length > 0) {
          setSeriesMonMap(new Map(validEntries));
          console.log(`✅ Serie cargada para monitor: ${focus}`);
        }
      } catch (error) {
        console.error(`Error cargando serie para monitor ${focus}:`, error);
        if (!alive) return;
        setSeriesMonMap(new Map());
      }
    };
    
    fetchMonitorSeries();
    
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, rangeValue, selectedRange.label, focus]);

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

      {/* Chip contexto - MUESTRA PROMEDIO DE SEDE POR DEFECTO */}
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
              <span>📊 Mostrando: <strong>Promedio de la sede</strong></span>
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
        {/* Gráfica en columna central - SIEMPRE visible */}
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
                border: isSelected ? '2px solid #3b82f6' : 'none',
                transform: isSelected ? 'scale(1.02)' : 'scale(1)',
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
