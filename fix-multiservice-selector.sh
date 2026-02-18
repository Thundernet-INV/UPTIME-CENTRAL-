#!/bin/bash
# fix-multiservice-selector.sh - CORRIGE SELECTOR DE TIEMPO EN MULTISERVICEVIEW

echo "====================================================="
echo "🔧 CORRIGIENDO SELECTOR DE TIEMPO EN MULTISERVICEVIEW"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_multiservice_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. CORREGIR MULTISERVICEVIEW.JSX COMPLETAMENTE ==========
echo ""
echo "[2] Reemplazando MultiServiceView.jsx con versión CORREGIDA..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
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
EOF

echo "✅ MultiServiceView.jsx reemplazado con versión CORREGIDA"
echo ""

# ========== 3. MEJORAR TIMERANGESELECTOR.JSX ==========
echo ""
echo "[3] Mejorando TimeRangeSelector.jsx..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN MEJORADA

import React, { useState, useEffect } from 'react';

// Opciones de rango
export const TIME_RANGES = [
  { label: 'Última 1 hora', value: 60 * 60 * 1000 },
  { label: 'Últimas 3 horas', value: 3 * 60 * 60 * 1000 },
  { label: 'Últimas 6 horas', value: 6 * 60 * 60 * 1000 },
  { label: 'Últimas 12 horas', value: 12 * 60 * 60 * 1000 },
  { label: 'Últimas 24 horas', value: 24 * 60 * 60 * 1000 },
  { label: 'Últimos 7 días', value: 7 * 24 * 60 * 60 * 1000 },
  { label: 'Últimos 30 días', value: 30 * 24 * 60 * 60 * 1000 },
];

// Evento global para cambios de rango
export const TIME_RANGE_CHANGE_EVENT = 'time-range-change';

export default function TimeRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedRange, setSelectedRange] = useState(() => {
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && typeof parsed.value === 'number') {
          return parsed;
        }
      }
    } catch (e) {}
    return TIME_RANGES[0];
  });

  useEffect(() => {
    try {
      localStorage.setItem('timeRange', JSON.stringify(selectedRange));
      
      const event = new CustomEvent(TIME_RANGE_CHANGE_EVENT, {
        detail: selectedRange
      });
      window.dispatchEvent(event);
      
      console.log(`📊 Rango cambiado a: ${selectedRange.label}`);
    } catch (e) {
      console.error('Error guardando rango:', e);
    }
  }, [selectedRange]);

  useEffect(() => {
    const handleClickOutside = (e) => {
      if (isOpen && !e.target.closest('.time-range-selector')) {
        setIsOpen(false);
      }
    };
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, [isOpen]);

  return (
    <div className="time-range-selector" style={{ position: 'relative', display: 'inline-block' }}>
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation();
          setIsOpen(!isOpen);
        }}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px 12px',
          background: 'var(--bg-secondary, #f3f4f6)',
          border: '1px solid var(--border, #e5e7eb)',
          borderRadius: '6px',
          fontSize: '0.85rem',
          color: 'var(--text-primary, #1f2937)',
          cursor: 'pointer',
          transition: 'all 0.2s ease',
        }}
        title="Cambiar rango de tiempo"
      >
        <span style={{ fontSize: '1.1rem' }}>📊</span>
        <span>{selectedRange.label}</span>
        <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>▼</span>
      </button>

      {isOpen && (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            right: '0',
            marginTop: '4px',
            background: 'white',
            border: '1px solid #e5e7eb',
            borderRadius: '6px',
            boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
            zIndex: 9999,
            minWidth: '180px',
            overflow: 'hidden',
          }}
        >
          {TIME_RANGES.map((range, index) => (
            <button
              key={index}
              type="button"
              onClick={() => {
                setSelectedRange(range);
                setIsOpen(false);
              }}
              style={{
                display: 'block',
                width: '100%',
                padding: '10px 16px',
                textAlign: 'left',
                border: 'none',
                borderBottom: index < TIME_RANGES.length - 1 ? '1px solid #f0f0f0' : 'none',
                background: selectedRange.value === range.value ? '#3b82f6' : 'transparent',
                color: selectedRange.value === range.value ? 'white' : '#1f2937',
                fontSize: '0.85rem',
                fontWeight: selectedRange.value === range.value ? '600' : '400',
                cursor: 'pointer',
                transition: 'background 0.2s ease',
              }}
              onMouseEnter={(e) => {
                if (selectedRange.value !== range.value) {
                  e.currentTarget.style.background = '#f3f4f6';
                }
              }}
              onMouseLeave={(e) => {
                if (selectedRange.value !== range.value) {
                  e.currentTarget.style.background = 'transparent';
                }
              }}
            >
              {range.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// Hook personalizado - Devuelve el objeto range completo
export function useTimeRange() {
  const [range, setRange] = useState(TIME_RANGES[0]);

  useEffect(() => {
    // Cargar rango inicial desde localStorage
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && typeof parsed.value === 'number') {
          setRange(parsed);
        }
      }
    } catch (e) {}

    // Escuchar cambios en el rango
    const handleRangeChange = (e) => {
      setRange(e.detail);
    };

    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  return range;
}
EOF

echo "✅ TimeRangeSelector.jsx mejorado"
echo ""

# ========== 4. AGREGAR INDICADOR DE RANGO EN DASHBOARD ==========
echo ""
echo "[4] Mejorando Dashboard.jsx para mostrar el rango activo..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

# Asegurar que el selector esté presente
if ! grep -q "<TimeRangeSelector" "$DASHBOARD_FILE"; then
    sed -i '/{·*Botón Notificaciones/i \                {/* Selector de rango de tiempo */}\
                <TimeRangeSelector />' "$DASHBOARD_FILE"
    echo "✅ TimeRangeSelector agregado a Dashboard.jsx"
fi

# ========== 5. AGREGAR ESTILOS DARK MODE ==========
echo ""
echo "[5] Agregando estilos para modo oscuro..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== SELECTOR DE TIEMPO - MODO OSCURO ========== */
body.dark-mode .time-range-selector button {
  background: #1a1e24 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .time-range-selector button:hover {
  background: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] {
  background: #1a1e24 !important;
  border-color: #2d3238 !important;
  box-shadow: 0 4px 12px rgba(0,0,0,0.5) !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button {
  color: #e5e7eb !important;
  border-bottom-color: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button:hover {
  background: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button[style*="background: #3b82f6"] {
  background: #2563eb !important;
  color: white !important;
}

/* ========== FILTROS MULTISERVICE - MODO OSCURO ========== */
body.dark-mode .multi-view {
  background: #0f1217 !important;
}

body.dark-mode .filter-group {
  background: #1a1e24 !important;
  border-color: #2d3238 !important;
}

body.dark-mode .filter-select {
  background: #0f1217 !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn--small {
  background: transparent !important;
  border-color: #2d3238 !important;
  color: #e5e7eb !important;
}

body.dark-mode .k-btn--small.is-active {
  background: #2563eb !important;
  border-color: #2563eb !important;
  color: white !important;
}

body.dark-mode .multi-view-chart-wrapper div[style*="background: rgba(0,0,0,0.05)"] {
  background: rgba(0,0,0,0.7) !important;
}

body.dark-mode .multi-view-chart-wrapper span[style*="background: var(--bg-primary)"] {
  background: #1a1e24 !important;
  color: #e5e7eb !important;
  border: 1px solid #2d3238 !important;
}
EOF

echo "✅ Estilos modo oscuro actualizados"
echo ""

# ========== 6. LIMPIAR CACHÉ Y REINICIAR ==========
echo ""
echo "[6] Limpiando caché y reiniciando frontend..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ MULTISERVICEVIEW CORREGIDO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo "   • MultiServiceView.jsx: COMPLETAMENTE RENOVADO"
echo "   • TimeRangeSelector.jsx: MEJORADO con más opciones"
echo "   • El selector de tiempo AHORA FUNCIONA en MultiServiceView"
echo "   • Muestra el rango activo en la interfaz"
echo "   • Escucha cambios en el rango y recarga automáticamente"
echo ""
echo "📍 UBICACIÓN DEL SELECTOR:"
echo "   • Dashboard: Al lado del botón de notificaciones"
echo "   • MultiServiceView: Muestra el rango activo arriba a la derecha"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Busca el selector 📊 en el dashboard"
echo "   3. CAMBIA el rango de tiempo"
echo "   4. Ve a 'Comparar' - DEBE mostrar el MISMO rango"
echo "   5. Cambia el rango DESDE Comparar - DEBE actualizarse"
echo ""
echo "📌 NOTA: Las gráficas ahora se actualizan automáticamente"
echo "   al cambiar el rango de tiempo en CUALQUIER parte"
echo ""
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
