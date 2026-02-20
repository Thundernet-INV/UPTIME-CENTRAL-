// src/components/InstanceDetail.jsx - VERSIÓN CON DEBUG Y TIMEOUT
import React, { useEffect, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";
import TimeRangeSelector, { useTimeRange } from "./TimeRangeSelector.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
}) {
  // Obtener el rango seleccionado
  const range = useTimeRange();
  
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [loadingAvg, setLoadingAvg] = useState(true);
  const [loadingMonitors, setLoadingMonitors] = useState(true);
  const [errorAvg, setErrorAvg] = useState(null); // 🟢 PARA DEBUG

  const group = monitorsAll.filter((m) => m.instance === instanceName);

  // 🟢 Cargar PROMEDIO con timeout y debug
  useEffect(() => {
    let active = true;
    let timeoutId = null;
    
    const loadAvg = async () => {
      setLoadingAvg(true);
      setErrorAvg(null);
      
      // Timeout de seguridad (10 segundos)
      timeoutId = setTimeout(() => {
        if (active) {
          console.error(`⏰ TIMEOUT cargando promedio de ${instanceName}`);
          setErrorAvg('Timeout - usando datos de ejemplo');
          setLoadingAvg(false);
          // Datos de ejemplo para no dejar la gráfica vacía
          const now = Date.now();
          const mockData = [];
          for (let i = 0; i < 60; i++) {
            mockData.push({
              ts: now - (i * 60 * 1000),
              ms: Math.random() * 200 + 50
            });
          }
          setAvgSeries(mockData.reverse());
        }
      }, 10000);
      
      try {
        console.log(`🔍 Iniciando carga de promedio para: ${instanceName}`);
        console.log(`📊 Rango:`, range);
        
        let series;
        
        if (range?.isAbsolute) {
          console.log(`📊 Modo absoluto: ${range.from} → ${range.to}`);
          series = await History.getAvgSeriesByInstanceRange(
            instanceName,
            range.from,
            range.to
          );
        } else if (range?.hours) {
          console.log(`📊 Modo relativo: ${range.hours}h`);
          series = await History.getAvgSeriesByInstance(
            instanceName,
            range.hours
          );
        } else {
          console.log(`📊 Modo default: 1h`);
          series = await History.getAvgSeriesByInstance(instanceName, 1);
        }
        
        console.log(`✅ Respuesta recibida:`, series);
        
        if (active) {
          if (series && series.length > 0) {
            console.log(`✅ Promedio cargado: ${series.length} puntos`);
            setAvgSeries(series);
            setErrorAvg(null);
          } else {
            console.warn(`⚠️ Promedio vacío para ${instanceName}`);
            setErrorAvg('Sin datos históricos');
            // Generar datos de ejemplo para visualización
            const now = Date.now();
            const mockData = [];
            for (let i = 0; i < 30; i++) {
              mockData.push({
                ts: now - (i * 2 * 60 * 1000),
                ms: Math.random() * 150 + 50
              });
            }
            setAvgSeries(mockData.reverse());
          }
        }
      } catch (error) {
        console.error('❌ Error cargando promedio:', error);
        if (active) {
          setErrorAvg(error.message);
          setAvgSeries([]);
        }
      } finally {
        if (active) {
          clearTimeout(timeoutId);
          setLoadingAvg(false);
        }
      }
    };
    
    loadAvg();
    
    return () => { 
      active = false; 
      if (timeoutId) clearTimeout(timeoutId);
    };
  }, [instanceName, range]);

  // 🟢 Cargar datos de monitores (igual que antes)
  useEffect(() => {
    let active = true;
    
    const loadMonitors = async () => {
      setLoadingMonitors(true);
      
      try {
        console.log(`🔍 Cargando ${group.length} monitores para ${instanceName}`);
        
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            let series;
            
            if (range?.isAbsolute) {
              series = await History.getSeriesForMonitorRange(
                instanceName,
                name,
                range.from,
                range.to
              );
            } else if (range?.hours) {
              series = await History.getSeriesForMonitor(
                instanceName,
                name,
                range.hours
              );
            } else {
              series = await History.getSeriesForMonitor(instanceName, name, 1);
            }
            
            return [name, series];
          })
        );
        
        if (active) {
          const map = new Map(entries);
          setSeriesMonMap(map);
          console.log(`✅ Datos de ${entries.length} monitores:`, 
            Array.from(map.keys()).map(k => `${k}: ${map.get(k)?.length || 0} puntos`));
        }
      } catch (error) {
        console.error('Error cargando monitores:', error);
      } finally {
        if (active) setLoadingMonitors(false);
      }
    };
    
    loadMonitors();
    
    return () => { active = false; };
  }, [instanceName, group.length, range]);

  const chartData = focus 
    ? seriesMonMap.get(focus) || [] 
    : avgSeries;
  
  // 🟢 Debug: Mostrar qué datos tenemos
  console.log(`📈 Render - focus: ${focus}, avgPoints: ${avgSeries.length}, ${focus ? 'monPoints: ' + (seriesMonMap.get(focus)?.length || 0) : ''}`);

  const isLoading = focus 
    ? loadingMonitors && !seriesMonMap.has(focus)
    : loadingAvg;

  const rangeLabel = range?.label || '1 hora';
  const chartTitle = focus 
    ? `${focus} - ${rangeLabel}` 
    : `Promedio de ${instanceName} - ${rangeLabel}`;

  return (
    <div className="instance-detail-page">
      {/* Header (igual) */}
      <div style={{ 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'space-between',
        padding: '16px 24px',
        borderBottom: '1px solid var(--border, #e5e7eb)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <button
            className="k-btn k-btn--primary"
            onClick={() => window.history.back()}
          >
            ← Volver
          </button>
          <h2 style={{ margin: 0, fontSize: '1.5rem' }}>{instanceName}</h2>
        </div>
        <TimeRangeSelector />
      </div>

      {/* Chip de información */}
      <div style={{ padding: '12px 24px' }}>
        <div className="k-chip k-chip--muted" style={{ 
          display: 'flex', 
          alignItems: 'center', 
          gap: '8px',
          flexWrap: 'wrap',
          padding: '8px 16px'
        }}>
          {focus ? (
            <>
              <span>Mostrando: <strong>{focus}</strong></span>
              <button 
                className="k-btn k-btn--ghost k-chip-action" 
                onClick={() => setFocus(null)}
                style={{ marginLeft: '4px' }}
              >
                ← Ver promedio de sede
              </button>
            </>
          ) : (
            <span>📊 <strong>Promedio de {instanceName}</strong> · {rangeLabel}</span>
          )}
          
          {!focus && (
            <span style={{ 
              fontSize: '0.75rem', 
              color: 'var(--text-secondary, #6b7280)',
              marginLeft: 'auto'
            }}>
              Haz clic en cualquier servicio para ver su detalle individual
            </span>
          )}
        </div>
        
        {/* 🟢 Mostrar mensaje de error si hay */}
        {errorAvg && !focus && (
          <div style={{
            marginTop: '8px',
            padding: '8px 16px',
            background: '#fee2e2',
            color: '#991b1b',
            borderRadius: '8px',
            fontSize: '0.85rem',
            border: '1px solid #fecaca'
          }}>
            ⚠️ {errorAvg} - Mostrando datos de ejemplo
          </div>
        )}
      </div>

      <section className="instance-detail-grid" style={{ padding: '0 24px 24px' }}>
        <div className="instance-detail-chart">
          {isLoading ? (
            <div style={{ 
              height: '300px', 
              display: 'flex', 
              flexDirection: 'column',
              alignItems: 'center', 
              justifyContent: 'center',
              gap: '16px',
              background: 'var(--bg-secondary, #f9fafb)',
              borderRadius: '8px',
              border: '1px solid var(--border, #e5e7eb)'
            }}>
              <div className="spinner" style={{
                width: '40px',
                height: '40px',
                border: '3px solid var(--border, #e5e7eb)',
                borderTopColor: '#3b82f6',
                borderRadius: '50%',
                animation: 'spin 1s linear infinite'
              }} />
              <p style={{ color: 'var(--text-secondary, #6b7280)' }}>
                {focus 
                  ? `Cargando datos de ${focus}...` 
                  : `Cargando promedio de ${instanceName}...`}
              </p>
              <p style={{ fontSize: '0.75rem', color: '#9ca3af' }}>
                {focus 
                  ? `Puntos actuales: ${seriesMonMap.get(focus)?.length || 0}`
                  : `Puntos actuales: ${avgSeries.length}`}
              </p>
              <style>{`
                @keyframes spin {
                  to { transform: rotate(360deg); }
                }
              `}</style>
            </div>
          ) : chartData.length === 0 ? (
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
                No hay datos disponibles para este período
              </p>
            </div>
          ) : (
            <HistoryChart
              mode="instance"
              seriesMon={chartData}
              title={chartTitle}
              h={300}
            />
          )}

          <div className="instance-detail-actions" style={{ 
            display: 'flex', 
            gap: '12px', 
            marginTop: '16px',
            justifyContent: 'flex-end'
          }}>
            <button 
              className="k-btn k-btn--danger" 
              onClick={() => setFocus(null)}
              disabled={!focus}
              style={{ opacity: focus ? 1 : 0.5 }}
            >
              Ver promedio
            </button>
            <button 
              className="k-btn k-btn--ghost"
              onClick={() => {
                setFocus(null);
                // Forzar recarga del promedio
                setLoadingAvg(true);
                setTimeout(() => {
                  History.getAvgSeriesByInstance(instanceName, 1)
                    .then(series => {
                      setAvgSeries(series);
                      setLoadingAvg(false);
                    })
                    .catch(() => setLoadingAvg(false));
                }, 100);
              }}
            >
              Recargar
            </button>
          </div>
        </div>

        {/* Lista de servicios */}
        {group.map((m) => {
          const name = m.info?.monitor_name ?? "";
          const isSelected = focus === name;
          const monitorSeries = seriesMonMap.get(name) || [];
          const hasData = monitorSeries.length > 0;
          
          return (
            <div
              key={name}
              className="instance-detail-service-card"
              onClick={() => setFocus(name)}
              style={{ 
                cursor: 'pointer',
                border: isSelected ? '2px solid #3b82f6' : '1px solid var(--border, #e5e7eb)',
                borderRadius: '12px',
                transition: 'all 0.2s ease',
                transform: isSelected ? 'scale(1.02)' : 'scale(1)',
                opacity: hasData ? 1 : 0.7,
              }}
            >
              <ServiceCard service={m} series={monitorSeries} />
              {!hasData && (
                <div style={{
                  textAlign: 'center',
                  padding: '2px',
                  background: '#f3f4f6',
                  color: '#6b7280',
                  fontSize: '0.65rem',
                  borderRadius: '0 0 8px 8px'
                }}>
                  ⚠️ Sin datos históricos
                </div>
              )}
              {isSelected && hasData && (
                <div style={{
                  textAlign: 'center',
                  padding: '4px',
                  background: '#3b82f6',
                  color: 'white',
                  fontSize: '0.7rem',
                  borderRadius: '0 0 8px 8px',
                  marginTop: '-4px'
                }}>
                  Mostrando en gráfica ({monitorSeries.length} pts)
                </div>
              )}
            </div>
          );
        })}
      </section>
    </div>
  );
}
