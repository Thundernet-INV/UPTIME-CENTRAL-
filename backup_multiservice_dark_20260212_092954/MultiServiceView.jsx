import React, { useEffect, useMemo, useRef, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import { useTimeRange } from "./TimeRangeSelector.jsx";

// Color estable a partir del nombre de la sede
function getColorForInstance(name = "") {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  const hue = hash % 360;
  const saturation = 70;
  const lightness = 50;
  return `hsl(${hue}, ${saturation}%, ${lightness}%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  
  console.log("📊 MultiServiceView - Rango seleccionado:", selectedRange.label, selectedRange.value);

  // 1) Lista de servicios HTTP únicos
  const services = useMemo(() => {
    const map = new Map();
    for (const m of monitorsAll) {
      const typeRaw = m.info?.monitor_type ?? "";
      if (typeRaw.toLowerCase() !== "http") continue;

      const name = m.info?.monitor_name ?? m.name ?? "";
      if (!name) continue;

      if (!map.has(name)) {
        map.set(name, { name, type: typeRaw, count: 0 });
      }
      map.get(name).count += 1;
    }
    return Array.from(map.values()).sort((a, b) =>
      a.name.localeCompare(b.name, "es", { sensitivity: "base" })
    );
  }, [monitorsAll]);

  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState(new Map());
  const [loading, setLoading] = useState(false);
  const [autoRotate, setAutoRotate] = useState(false);
  const [rotateIntervalSec, setRotateIntervalSec] = useState(8);

  const [userTouchedInstances, setUserTouchedInstances] = useState(false);
  const servicesRef = useRef([]);

  useEffect(() => {
    servicesRef.current = services;
  }, [services]);

  // 2) Sedes que tienen ese servicio HTTP
  const instancesWithService = useMemo(() => {
    if (!selectedService) return [];
    const set = new Set();
    for (const m of monitorsAll) {
      const typeRaw = m.info?.monitor_type ?? "";
      if (typeRaw.toLowerCase() !== "http") continue;

      const name = m.info?.monitor_name ?? m.name ?? "";
      if (name === selectedService && m.instance) {
        set.add(m.instance);
      }
    }
    return Array.from(set).sort();
  }, [monitorsAll, selectedService]);

  // 3) Elegir un servicio inicial
  useEffect(() => {
    if (!selectedService && services.length > 0) {
      setSelectedService(services[0].name);
    }
  }, [services, selectedService]);

  // 4) Resetear flag al cambiar servicio
  useEffect(() => {
    setUserTouchedInstances(false);
  }, [selectedService]);

  // 5) Sincronizar sedes seleccionadas
  useEffect(() => {
    if (!instancesWithService || instancesWithService.length === 0) return;

    setSelectedInstances((prev) => {
      if (!userTouchedInstances) {
        return instancesWithService;
      }
      const intersection = prev.filter((name) =>
        instancesWithService.includes(name)
      );
      return intersection.length > 0 ? intersection : prev;
    });
  }, [instancesWithService, userTouchedInstances]);

  const toggleInstance = (name) => {
    setUserTouchedInstances(true);
    setSelectedInstances((prev) =>
      prev.includes(name) ? prev.filter((n) => n !== name) : [...prev, name]
    );
  };

  // 6) Cargar series con el rango SELECCIONADO
  useEffect(() => {
    let alive = true;

    const fetchAll = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance(new Map());
        setLoading(false);
        return;
      }

      setLoading(true);
      console.log(`📊 Cargando datos para ${selectedService} - Rango: ${selectedRange.label}`);
      
      try {
        const entries = await Promise.all(
          selectedInstances.map(async (instanceName) => {
            const arr = await History.getSeriesForMonitor(
              instanceName,
              selectedService,
              selectedRange.value // ← USA EL RANGO SELECCIONADO
            );
            return [instanceName, Array.isArray(arr) ? arr : []];
          })
        );
        if (alive) {
          setSeriesByInstance(new Map(entries));
          console.log(`✅ Datos cargados: ${entries.length} sedes`);
        }
      } catch (error) {
        console.error("Error cargando datos:", error);
      } finally {
        if (alive) setLoading(false);
      }
    };

    fetchAll();
    
    // Escuchar cambios en el rango de tiempo
    const handleRangeChange = (e) => {
      console.log("📊 Rango cambiado, recargando datos...");
      fetchAll();
    };
    
    window.addEventListener('time-range-change', handleRangeChange);
    
    return () => {
      alive = false;
      window.removeEventListener('time-range-change', handleRangeChange);
    };
  }, [selectedService, selectedInstances, selectedRange.value]); // ← DEPENDE DEL RANGO

  // 7) Auto-rotate
  useEffect(() => {
    if (!autoRotate) return;

    const intervalMs = Math.max(2, Number(rotateIntervalSec) || 8) * 1000;
    const timer = setInterval(() => {
      const list = servicesRef.current;
      if (!list || list.length === 0) return;

      setSelectedService((prev) => {
        if (!prev) return list[0].name;
        const idx = list.findIndex((s) => s.name === prev);
        const nextIdx = idx === -1 ? 0 : (idx + 1) % list.length;
        return list[nextIdx].name;
      });
    }, intervalMs);

    return () => clearInterval(timer);
  }, [autoRotate, rotateIntervalSec]);

  // 8) Preparar datos para el chart
  const chartSeries = useMemo(() => {
    return selectedInstances.map((instanceName) => {
      const points = seriesByInstance.get(instanceName) ?? [];
      return {
        id: instanceName,
        label: instanceName,
        color: getColorForInstance(instanceName),
        points,
      };
    });
  }, [selectedInstances, seriesByInstance]);

  const hasService = !!selectedService;
  const hasSeries = chartSeries.length > 0;

  return (
    <div className="multi-view">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 className="multi-view-title">Comparar servicio HTTP por sede</h2>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
          <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary, #6b7280)' }}>
            Rango: {selectedRange.label}
          </span>
        </div>
      </div>

      <section className="filters-toolbar" aria-label="Filtros de comparación">
        {/* Servicio HTTP */}
        <div className="filter-group">
          <label className="filter-label" htmlFor="service-select">
            Servicio HTTP
          </label>
          <select
            id="service-select"
            className="filter-select"
            value={selectedService}
            onChange={(e) => setSelectedService(e.target.value)}
            style={{
              padding: '8px 12px',
              borderRadius: '6px',
              border: '1px solid var(--border, #e5e7eb)',
              background: 'var(--input-bg, white)',
              color: 'var(--text-primary, #1f2937)',
            }}
          >
            <option value="">Selecciona un servicio…</option>
            {services.map((s) => (
              <option key={s.name} value={s.name}>
                {s.name} {s.type ? `(${s.type.toUpperCase()})` : ""} · {s.count} monitores
              </option>
            ))}
          </select>
        </div>

        {/* Sedes */}
        {hasService && (
          <div className="filter-group">
            <span className="filter-label">Sedes</span>
            <div className="filter-chips" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              {instancesWithService.map((name) => {
                const isActive = selectedInstances.includes(name);
                return (
                  <button
                    key={name}
                    type="button"
                    className={`k-btn k-btn--small ${isActive ? 'is-active' : ''}`}
                    onClick={() => toggleInstance(name)}
                    style={{
                      padding: '6px 12px',
                      borderRadius: '20px',
                      border: '1px solid var(--border, #e5e7eb)',
                      background: isActive ? 'var(--info, #3b82f6)' : 'transparent',
                      color: isActive ? 'white' : 'var(--text-primary, #1f2937)',
                      cursor: 'pointer',
                    }}
                  >
                    {name}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Opciones de auto-rotación */}
        <div className="filter-group">
          <span className="filter-label">Opciones</span>
          <div className="filter-chips" style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <button
              type="button"
              className={`k-btn k-btn--small ${autoRotate ? 'is-active' : ''}`}
              onClick={() => setAutoRotate((prev) => !prev)}
              style={{
                padding: '6px 12px',
                borderRadius: '20px',
                border: '1px solid var(--border, #e5e7eb)',
                background: autoRotate ? 'var(--info, #3b82f6)' : 'transparent',
                color: autoRotate ? 'white' : 'var(--text-primary, #1f2937)',
              }}
            >
              Auto: {autoRotate ? "ON" : "OFF"}
            </button>
            <span style={{ fontSize: "0.8rem", color: "var(--text-secondary, #6b7280)" }}>
              Cada
            </span>
            <input
              type="number"
              min={2}
              max={600}
              value={rotateIntervalSec}
              onChange={(e) => setRotateIntervalSec(e.target.value)}
              style={{
                width: 60,
                padding: "6px 8px",
                fontSize: "0.8rem",
                borderRadius: 6,
                border: "1px solid var(--border, #e5e7eb)",
                background: 'var(--input-bg, white)',
                color: 'var(--text-primary, #1f2937)',
                textAlign: "right",
              }}
            />
            <span style={{ fontSize: "0.8rem", color: "var(--text-secondary, #6b7280)" }}>seg</span>
          </div>
        </div>
      </section>

      <section className="multi-view-chart-section" aria-label="Gráfica comparativa">
        {!hasService && (
          <p className="muted" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary, #6b7280)' }}>
            Selecciona un servicio HTTP para ver su comportamiento en todas las sedes.
          </p>
        )}

        {hasService && !hasSeries && !loading && (
          <p className="muted" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary, #6b7280)' }}>
            No hay sedes seleccionadas o no se encontró historial para este servicio.
          </p>
        )}

        {hasService && !hasSeries && loading && (
          <p className="muted" style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary, #6b7280)' }}>
            Cargando series históricas para {selectedRange.label}...
          </p>
        )}

        {hasService && hasSeries && (
          <div className="multi-view-chart-wrapper" style={{ position: 'relative' }}>
            <HistoryChart mode="multi" seriesMulti={chartSeries} h={380} />
            {loading && (
              <div style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                background: 'rgba(0,0,0,0.05)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                borderRadius: '8px',
                backdropFilter: 'blur(2px)',
              }}>
                <span style={{
                  background: 'var(--bg-primary, white)',
                  padding: '8px 16px',
                  borderRadius: '20px',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                  color: 'var(--text-primary, #1f2937)',
                }}>
                  Actualizando datos para {selectedRange.label}...
                </span>
              </div>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
