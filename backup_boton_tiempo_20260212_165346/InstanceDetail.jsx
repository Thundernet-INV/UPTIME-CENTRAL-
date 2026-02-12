import React, { useEffect, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";

// Opciones de tiempo
const TIME_OPTIONS = [
  { label: '1 hora', hours: 1 },
  { label: '3 horas', hours: 3 },
  { label: '6 horas', hours: 6 },
  { label: '12 horas', hours: 12 },
  { label: '24 horas', hours: 24 },
  { label: '7 días', hours: 168 },
];

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
}) {
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [selectedHours, setSelectedHours] = useState(1);
  const [isOpen, setIsOpen] = useState(false);

  // Monitores de la sede actual
  const group = monitorsAll.filter((m) => m.instance === instanceName);

  // Cargar promedio cuando cambia instancia o horas
  useEffect(() => {
    let active = true;
    const load = async () => {
      const series = await History.getAvgSeriesByInstance(instanceName, selectedHours);
      if (active) setAvgSeries(series);
    };
    load();
    return () => { active = false; };
  }, [instanceName, selectedHours]);

  // Cargar monitores
  useEffect(() => {
    let active = true;
    const load = async () => {
      const entries = await Promise.all(
        group.map(async (m) => {
          const name = m.info?.monitor_name ?? "";
          const series = await History.getSeriesForMonitor(instanceName, name, selectedHours);
          return [name, series];
        })
      );
      if (active) setSeriesMonMap(new Map(entries));
    };
    load();
    return () => { active = false; };
  }, [instanceName, group.length, selectedHours]);

  const chartData = focus ? seriesMonMap.get(focus) || [] : avgSeries;
  const selectedLabel = TIME_OPTIONS.find(o => o.hours === selectedHours)?.label || '1 hora';

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
        
        {/* 🟢 SELECTOR DE TIEMPO - AHORA A LA DERECHA CON FLEX Y MARGIN LEFT AUTO */}
        <div style={{ 
          display: 'flex', 
          alignItems: 'center', 
          marginLeft: 'auto',
          gap: '12px'
        }}>
          <span style={{ 
            fontSize: '0.85rem', 
            color: 'var(--text-secondary, #6b7280)'
          }}>
            Rango:
          </span>
          <div style={{ position: 'relative' }}>
            <button
              onClick={() => setIsOpen(!isOpen)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '6px 14px',
                background: 'var(--bg-tertiary, #f3f4f6)',
                border: '1px solid var(--border, #e5e7eb)',
                borderRadius: '20px',
                fontSize: '0.85rem',
                color: 'var(--text-primary, #1f2937)',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
              }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'var(--bg-hover, #e5e7eb)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'var(--bg-tertiary, #f3f4f6)'}
            >
              <span style={{ fontSize: '1rem' }}>🕒</span>
              <span style={{ fontWeight: '500' }}>{selectedLabel}</span>
              <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>▼</span>
            </button>
            
            {isOpen && (
              <div style={{
                position: 'absolute',
                top: '100%',
                right: 0,
                marginTop: '4px',
                background: 'white',
                border: '1px solid #e5e7eb',
                borderRadius: '8px',
                boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
                zIndex: 9999,
                minWidth: '140px',
                overflow: 'hidden',
              }}>
                {TIME_OPTIONS.map((opt) => (
                  <button
                    key={opt.hours}
                    onClick={() => {
                      setSelectedHours(opt.hours);
                      setIsOpen(false);
                    }}
                    style={{
                      display: 'block',
                      width: '100%',
                      padding: '10px 16px',
                      textAlign: 'left',
                      border: 'none',
                      borderBottom: opt.hours !== TIME_OPTIONS[TIME_OPTIONS.length-1].hours ? '1px solid #f0f0f0' : 'none',
                      background: selectedHours === opt.hours ? '#3b82f6' : 'transparent',
                      color: selectedHours === opt.hours ? 'white' : '#1f2937',
                      fontSize: '0.9rem',
                      cursor: 'pointer',
                      transition: 'background 0.2s ease',
                    }}
                    onMouseEnter={(e) => {
                      if (selectedHours !== opt.hours) {
                        e.currentTarget.style.background = '#f3f4f6';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (selectedHours !== opt.hours) {
                        e.currentTarget.style.background = 'transparent';
                      }
                    }}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
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
        {/* Mostrar rango actual también en el chip para referencia */}
        <span style={{
          marginLeft: '12px',
          fontSize: '0.75rem',
          color: 'var(--text-tertiary, #9ca3af)'
        }}>
          ({selectedLabel})
        </span>
      </div>

      <section className="instance-detail-grid">
        <div className="instance-detail-chart">
          <HistoryChart
            mode="instance"
            seriesMon={chartData}
            title={`${focus || instanceName} - ${selectedLabel}`}
          />

          <div className="instance-detail-actions">
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
