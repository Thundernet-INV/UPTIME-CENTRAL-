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
  const [loading, setLoading] = useState(true);

  const group = monitorsAll.filter((m) => m.instance === instanceName);

  // Cargar datos según el tipo de rango
  useEffect(() => {
    let active = true;
    
    const loadData = async () => {
      setLoading(true);
      
      try {
        let series;
        
        if (range?.isAbsolute) {
          // Rango absoluto con fechas específicas
          console.log(`📊 Rango absoluto: ${range.from} → ${range.to}`);
          series = await History.getAvgSeriesByInstanceRange(
            instanceName,
            range.from,
            range.to
          );
        } else if (range?.hours) {
          // Rango relativo por horas
          console.log(`📊 Rango relativo: ${range.hours}h`);
          series = await History.getAvgSeriesByInstance(
            instanceName,
            range.hours
          );
        } else {
          // Fallback a 1 hora
          series = await History.getAvgSeriesByInstance(instanceName, 1);
        }
        
        if (active) {
          setAvgSeries(series);
          console.log(`✅ Datos cargados: ${series.length} puntos`);
        }
      } catch (error) {
        console.error('Error cargando promedio:', error);
      } finally {
        if (active) setLoading(false);
      }
    };
    
    loadData();
    
    return () => { active = false; };
  }, [instanceName, range]);

  // Cargar monitores
  useEffect(() => {
    let active = true;
    
    const loadMonitors = async () => {
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
        setSeriesMonMap(new Map(entries));
      }
    };
    
    loadMonitors();
    
    return () => { active = false; };
  }, [instanceName, group.length, range]);

  const chartData = focus ? seriesMonMap.get(focus) || [] : avgSeries;
  
  // Formatear label para mostrar
  let rangeLabel = '1 hora';
  if (range?.isAbsolute) {
    rangeLabel = `${range.from} → ${range.to}`;
  } else if (range?.label) {
    rangeLabel = range.label;
  }

  return (
    <div className="instance-detail-page">
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

      <div style={{ padding: '12px 24px' }}>
        <div className="k-chip k-chip--muted">
          {focus ? (
            <span>Mostrando: <strong>{focus}</strong></span>
          ) : (
            <span>📊 <strong>Promedio de {instanceName}</strong> · {rangeLabel}</span>
          )}
          {focus && (
            <button 
              className="k-btn k-btn--ghost k-chip-action" 
              onClick={() => setFocus(null)}
              style={{ marginLeft: '8px' }}
            >
              Ver promedio
            </button>
          )}
        </div>
      </div>

      <section className="instance-detail-grid" style={{ padding: '0 24px 24px' }}>
        <div className="instance-detail-chart">
          {loading ? (
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
                Cargando datos para {rangeLabel}...
              </p>
            </div>
          ) : (
            <HistoryChart
              mode="instance"
              seriesMon={chartData}
              title={`${focus || instanceName} - ${rangeLabel}`}
            />
          )}

          <div className="instance-detail-actions" style={{ 
            display: 'flex', 
            gap: '12px', 
            marginTop: '16px',
            justifyContent: 'flex-end'
          }}>
            <button className="k-btn k-btn--danger">Ocultar todos</button>
            <button className="k-btn k-btn--ghost">Mostrar todos</button>
          </div>
        </div>

        {group.map((m) => {
          const name = m.info?.monitor_name ?? "";
          return (
            <div
              key={name}
              className="instance-detail-service-card"
              onClick={() => setFocus(name)}
              style={{ cursor: 'pointer' }}
            >
              <ServiceCard service={m} series={seriesMonMap.get(name) || []} />
            </div>
          );
        })}
      </section>
    </div>
  );
}
