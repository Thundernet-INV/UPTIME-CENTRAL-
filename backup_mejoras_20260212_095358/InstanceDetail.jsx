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
  
  // Estado
  const [focus, setFocus] = useState(null); // null = promedio de sede
  const [instanceData, setInstanceData] = useState({});
  const [monitorSeries, setMonitorSeries] = useState({});
  const [loading, setLoading] = useState(true);

  // Monitores de esta sede
  const instanceMonitors = useMemo(() => {
    return monitorsAll.filter(m => m.instance === instanceName);
  }, [monitorsAll, instanceName]);

  // MEJORA 3: Cargar promedio de sede SIEMPRE al entrar
  useEffect(() => {
    let isMounted = true;
    
    const fetchInstanceData = async () => {
      setLoading(true);
      console.log(`🏢 Cargando promedio de sede: ${instanceName} (${selectedRange.label})`);
      
      try {
        const data = await History.getAllForInstance(
          instanceName,
          selectedRange.value
        );
        
        if (isMounted) {
          setInstanceData(data || {});
          console.log(`✅ Promedio de ${instanceName} cargado`);
        }
      } catch (error) {
        console.error(`Error cargando ${instanceName}:`, error);
        if (isMounted) {
          setInstanceData({});
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };
    
    fetchInstanceData();
    
    // Escuchar cambios en el rango de tiempo
    const handleRangeChange = (e) => {
      console.log(`📊 InstanceDetail (${instanceName}) - Rango cambiado, recargando...`);
      fetchInstanceData();
      
      // Si hay un monitor seleccionado, recargar también
      if (focus) {
        const fetchMonitorData = async () => {
          try {
            const data = await History.getSeriesForMonitor(
              instanceName,
              focus,
              e.detail.value
            );
            if (isMounted) {
              setMonitorSeries(prev => ({
                ...prev,
                [focus]: Array.isArray(data) ? data : []
              }));
            }
          } catch (error) {
            console.error(`Error recargando monitor ${focus}:`, error);
          }
        };
        fetchMonitorData();
      }
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => {
      isMounted = false;
      window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    };
  }, [instanceName, selectedRange.value, focus]);

  // Cargar serie de un monitor específico cuando se selecciona
  useEffect(() => {
    if (!focus) return;
    
    let isMounted = true;
    
    const fetchMonitorData = async () => {
      console.log(`🔍 Cargando monitor: ${focus} en ${instanceName} (${selectedRange.label})`);
      
      try {
        const data = await History.getSeriesForMonitor(
          instanceName,
          focus,
          selectedRange.value
        );
        
        if (isMounted) {
          setMonitorSeries(prev => ({
            ...prev,
            [focus]: Array.isArray(data) ? data : []
          }));
          console.log(`✅ Monitor ${focus} cargado`);
        }
      } catch (error) {
        console.error(`Error cargando monitor ${focus}:`, error);
      }
    };
    
    fetchMonitorData();
    
    return () => {
      isMounted = false;
    };
  }, [instanceName, focus, selectedRange.value]);

  return (
    <div className="instance-detail-page">
      {/* Header */}
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
      </div>

      {/* Chip de contexto */}
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
              <span>📊 <strong>Promedio de la sede</strong></span>
              <span style={{ 
                fontSize: '0.75rem', 
                background: '#e5e7eb', 
                padding: '2px 8px', 
                borderRadius: '12px',
                color: '#4b5563'
              }}>
                {selectedRange.label}
              </span>
            </span>
          </div>
        )}
      </div>

      {/* Grid */}
      <section className="instance-detail-grid">
        {/* Gráfica */}
        <div className="instance-detail-chart">
          {loading && !focus && (
            <div style={{ 
              height: '300px', 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'center',
              background: '#f9fafb',
              borderRadius: '8px'
            }}>
              <p style={{ color: '#6b7280' }}>Cargando promedio de {instanceName}...</p>
            </div>
          )}
          
          {!loading && !focus && (
            <HistoryChart 
              mode="instance" 
              series={instanceData} 
            />
          )}
          
          {focus && (
            <HistoryChart
              mode="monitor"
              seriesMon={monitorSeries[focus] || []}
              title={focus}
            />
          )}

          {/* Acciones */}
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

        {/* Cards de servicios */}
        {instanceMonitors.map((monitor) => {
          const name = monitor.info?.monitor_name || "";
          const isSelected = focus === name;
          
          return (
            <div
              key={name}
              className={`instance-detail-service-card ${isSelected ? 'selected' : ''}`}
              onClick={() => setFocus(name)}
              style={{
                cursor: 'pointer',
                border: isSelected ? '2px solid #3b82f6' : '1px solid transparent',
                transform: isSelected ? 'scale(1.02)' : 'scale(1)',
                transition: 'all 0.2s ease'
              }}
            >
              <ServiceCard 
                service={monitor} 
                series={monitorSeries[name] || []} 
              />
            </div>
          );
        })}
      </section>
    </div>
  );
}
