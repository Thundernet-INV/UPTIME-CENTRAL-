#!/bin/bash
# fix-multiview-botones.sh - RESTAURAR BOTONES DE SEDES Y SELECTOR DE TIEMPO

echo "====================================================="
echo "🔧 RESTAURANDO BOTONES DE MULTISERVICEVIEW"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_multiview_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CREAR TIMERANGESELECTOR.JSX ==========
echo "[2] Creando TimeRangeSelector.jsx - SELECTOR DE RANGO DE TIEMPO..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN COMPLETA

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
          e.preventDefault();
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

// Hook para usar el rango de tiempo
export function useTimeRange() {
  const [range, setRange] = useState(TIME_RANGES[0]);

  useEffect(() => {
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed && typeof parsed.value === 'number') {
          setRange(parsed);
        }
      }
    } catch (e) {}

    const handleRangeChange = (e) => {
      setRange(e.detail);
    };

    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  return range;
}
EOF

echo "✅ TimeRangeSelector.jsx creado"
echo ""

# ========== 3. REEMPLAZAR MULTISERVICEVIEW.JSX CON BOTONES ==========
echo "[3] Reemplazando MultiServiceView.jsx con versión COMPLETA..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import { useTimeRange, TIME_RANGE_CHANGE_EVENT } from "./TimeRangeSelector.jsx";

// Color estable a partir del nombre de la sede
function getColorForInstance(name = "") {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  const hue = hash % 360;
  return `hsl(${hue}, 70%, 50%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  const [rangeValue, setRangeValue] = useState(selectedRange.value);

  // Estado para servicios y sedes seleccionadas
  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState({});
  const [loading, setLoading] = useState(false);

  // Estado para controlar si el usuario ha tocado las sedes
  const [userTouchedInstances, setUserTouchedInstances] = useState(false);

  // Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = (e) => {
      console.log(`📊 MultiServiceView - Rango cambiado a: ${e.detail.label}`);
      setRangeValue(e.detail.value);
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  // 1) Lista de servicios HTTP únicos
  const services = useMemo(() => {
    const serviceMap = new Map();
    
    monitorsAll.forEach(monitor => {
      const type = monitor.info?.monitor_type || "";
      if (type.toLowerCase() !== "http") return;
      
      const name = monitor.info?.monitor_name || monitor.name || "";
      if (!name) return;
      
      const instance = monitor.instance;
      if (!instance) return;
      
      if (!serviceMap.has(name)) {
        serviceMap.set(name, {
          name,
          type,
          instances: new Set(),
          count: 0
        });
      }
      
      const service = serviceMap.get(name);
      service.instances.add(instance);
      service.count = service.instances.size;
    });
    
    return Array.from(serviceMap.values()).sort((a, b) => 
      a.name.localeCompare(b.name)
    );
  }, [monitorsAll]);

  // 2) Auto-seleccionar el primer servicio
  useEffect(() => {
    if (services.length > 0 && !selectedService) {
      const primerServicio = services[0].name;
      console.log("🎯 Auto-seleccionando primer servicio:", primerServicio);
      setSelectedService(primerServicio);
    }
  }, [services, selectedService]);

  // 3) Obtener sedes que tienen el servicio seleccionado
  const instancesWithService = useMemo(() => {
    if (!selectedService) return [];
    const service = services.find(s => s.name === selectedService);
    return service ? Array.from(service.instances).sort() : [];
  }, [services, selectedService]);

  // 4) Resetear selección de sedes cuando cambia el servicio
  useEffect(() => {
    setUserTouchedInstances(false);
    // Cuando cambia el servicio, seleccionamos TODAS las sedes automáticamente
    if (instancesWithService.length > 0) {
      setSelectedInstances(instancesWithService);
    }
  }, [selectedService, instancesWithService]);

  // 5) Función para toggle de sedes (BOTONES)
  const toggleInstance = (name) => {
    setUserTouchedInstances(true);
    setSelectedInstances(prev => 
      prev.includes(name)
        ? prev.filter(n => n !== name)
        : [...prev, name]
    );
  };

  // 6) Cargar datos cuando cambia el servicio, las sedes o el rango
  useEffect(() => {
    let isMounted = true;
    
    const fetchData = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance({});
        return;
      }
      
      setLoading(true);
      console.log(`📊 Cargando datos para ${selectedService} - ${selectedInstances.length} sedes (${selectedRange.label})`);
      
      try {
        const seriesData = {};
        
        await Promise.all(
          selectedInstances.map(async (instance) => {
            const data = await History.getSeriesForMonitor(
              instance,
              selectedService,
              rangeValue
            );
            seriesData[instance] = Array.isArray(data) ? data : [];
          })
        );
        
        if (isMounted) {
          setSeriesByInstance(seriesData);
          console.log(`✅ Datos cargados: ${Object.keys(seriesData).length} sedes`);
        }
      } catch (error) {
        console.error("Error cargando datos:", error);
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };
    
    fetchData();
    
    return () => {
      isMounted = false;
    };
  }, [selectedService, selectedInstances, rangeValue, selectedRange.label]);

  // 7) Preparar datos para el chart
  const chartSeries = useMemo(() => {
    return selectedInstances.map(instance => ({
      id: instance,
      label: instance,
      color: getColorForInstance(instance),
      points: seriesByInstance[instance] || []
    }));
  }, [selectedInstances, seriesByInstance]);

  const hasService = !!selectedService;
  const hasSeries = chartSeries.length > 0 && chartSeries.some(s => s.points.length > 0);

  // Detectar modo oscuro
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      return document.body.classList.contains('dark-mode');
    }
    return false;
  });

  useEffect(() => {
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === 'class') {
          setIsDark(document.body.classList.contains('dark-mode'));
        }
      });
    });
    
    observer.observe(document.body, { attributes: true });
    return () => observer.disconnect();
  }, []);

  // Estilos
  const styles = {
    container: {
      padding: '24px',
      backgroundColor: isDark ? '#0f1217' : '#ffffff',
      color: isDark ? '#e5e7eb' : '#1f2937',
      borderRadius: '12px',
    },
    header: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: '24px',
    },
    title: {
      margin: 0,
      fontSize: '1.5rem',
      fontWeight: '600',
      color: isDark ? '#f1f5f9' : '#111827',
    },
    rangeBadge: {
      padding: '6px 14px',
      backgroundColor: isDark ? '#1a1e24' : '#f3f4f6',
      border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
      borderRadius: '20px',
      fontSize: '0.85rem',
      color: isDark ? '#94a3b8' : '#6b7280',
    },
    filterGroup: {
      backgroundColor: isDark ? '#1a1e24' : '#f9fafb',
      border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
      borderRadius: '8px',
      padding: '16px',
      marginBottom: '16px',
    },
    filterLabel: {
      display: 'block',
      fontSize: '0.8rem',
      fontWeight: '600',
      textTransform: 'uppercase',
      letterSpacing: '0.05em',
      color: isDark ? '#94a3b8' : '#6b7280',
      marginBottom: '8px',
    },
    select: {
      width: '100%',
      maxWidth: '400px',
      padding: '10px 12px',
      backgroundColor: isDark ? '#0f1217' : '#ffffff',
      border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
      borderRadius: '6px',
      color: isDark ? '#e5e7eb' : '#1f2937',
      fontSize: '0.95rem',
    },
    chipsContainer: {
      display: 'flex',
      gap: '8px',
      flexWrap: 'wrap',
      marginTop: '8px',
    },
    chip: {
      padding: '6px 14px',
      borderRadius: '20px',
      border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
      background: 'transparent',
      color: isDark ? '#e5e7eb' : '#1f2937',
      fontSize: '0.85rem',
      cursor: 'pointer',
      transition: 'all 0.2s ease',
    },
    chipActive: {
      background: isDark ? '#2563eb' : '#3b82f6',
      borderColor: isDark ? '#2563eb' : '#3b82f6',
      color: 'white',
    },
    chartContainer: {
      position: 'relative',
      marginTop: '20px',
      minHeight: '380px',
    },
    loadingOverlay: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: isDark ? 'rgba(0,0,0,0.7)' : 'rgba(255,255,255,0.7)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      borderRadius: '8px',
      backdropFilter: 'blur(2px)',
    },
  };

  return (
    <div style={styles.container}>
      {/* Header con título y rango actual */}
      <div style={styles.header}>
        <h2 style={styles.title}>Comparar servicio HTTP por sede</h2>
        <div style={styles.rangeBadge}>
          📊 {selectedRange.label}
        </div>
      </div>

      {/* Selector de servicio */}
      <div style={styles.filterGroup}>
        <label style={styles.filterLabel} htmlFor="service-select">
          Servicio HTTP
        </label>
        <select
          id="service-select"
          value={selectedService}
          onChange={(e) => setSelectedService(e.target.value)}
          style={styles.select}
        >
          <option value="">Selecciona un servicio...</option>
          {services.map(service => (
            <option key={service.name} value={service.name}>
              {service.name} · {service.count} {service.count === 1 ? 'sede' : 'sedes'}
            </option>
          ))}
        </select>
      </div>

      {/* 🟢 BOTONES DE SEDES - RESTAURADOS */}
      {hasService && instancesWithService.length > 0 && (
        <div style={styles.filterGroup}>
          <span style={styles.filterLabel}>Sedes</span>
          <div style={styles.chipsContainer}>
            {instancesWithService.map((name) => {
              const isActive = selectedInstances.includes(name);
              return (
                <button
                  key={name}
                  type="button"
                  onClick={() => toggleInstance(name)}
                  style={{
                    ...styles.chip,
                    ...(isActive ? styles.chipActive : {}),
                  }}
                  onMouseEnter={(e) => {
                    if (!isActive) {
                      e.currentTarget.style.background = isDark ? '#2d3238' : '#f3f4f6';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (!isActive) {
                      e.currentTarget.style.background = 'transparent';
                    }
                  }}
                >
                  {name}
                </button>
              );
            })}
          </div>
          <div style={{ marginTop: '8px', fontSize: '0.8rem', color: isDark ? '#94a3b8' : '#6b7280' }}>
            {selectedInstances.length} de {instancesWithService.length} sedes seleccionadas
          </div>
        </div>
      )}

      {/* Contenedor de la gráfica */}
      <div style={styles.chartContainer}>
        {!hasService && (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: isDark ? '#94a3b8' : '#6b7280' }}>
            Selecciona un servicio HTTP para ver su comportamiento en todas las sedes.
          </div>
        )}
        
        {hasService && selectedInstances.length === 0 && (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: isDark ? '#94a3b8' : '#6b7280' }}>
            No hay sedes seleccionadas. Haz click en los botones para seleccionar sedes.
          </div>
        )}
        
        {hasService && selectedInstances.length > 0 && !hasSeries && !loading && (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: isDark ? '#94a3b8' : '#6b7280' }}>
            No hay datos históricos disponibles para {selectedRange.label.toLowerCase()}.
          </div>
        )}
        
        {hasService && selectedInstances.length > 0 && hasSeries && !loading && (
          <HistoryChart 
            mode="multi" 
            seriesMulti={chartSeries} 
            h={380}
          />
        )}
        
        {loading && (
          <div style={styles.loadingOverlay}>
            <span style={{
              padding: '8px 16px',
              background: isDark ? '#1a1e24' : '#ffffff',
              border: `1px solid ${isDark ? '#2d3238' : '#e5e7eb'}`,
              borderRadius: '20px',
              color: isDark ? '#e5e7eb' : '#1f2937',
            }}>
              Cargando datos para {selectedRange.label}...
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
EOF

echo "✅ MultiServiceView.jsx reemplazado - BOTONES DE SEDES RESTAURADOS"
echo ""

# ========== 4. AGREGAR TIMERANGESELECTOR AL DASHBOARD ==========
echo "[4] Agregando TimeRangeSelector al Dashboard..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

if ! grep -q "TimeRangeSelector" "$DASHBOARD_FILE"; then
    # Agregar import
    sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "$DASHBOARD_FILE"
    
    # Agregar componente después del filtro de tipo
    sed -i '/{·*Filtro por tipo de servicio/,/<\/select>/ {
        /<\/select>/a\
\
                {/* Selector de rango de tiempo */}\
                <TimeRangeSelector />
    }' "$DASHBOARD_FILE"
    
    echo "✅ TimeRangeSelector agregado al Dashboard"
else
    echo "✅ TimeRangeSelector ya existe en Dashboard"
fi
echo ""

# ========== 5. LIMPIAR CACHÉ ==========
echo "[5] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"
echo ""

# ========== 6. REINICIAR FRONTEND ==========
echo "[6] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ BOTONES DE MULTISERVICEVIEW RESTAURADOS ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. ✅ TimeRangeSelector.jsx: CREADO"
echo "   2. ✅ MultiServiceView.jsx: REEMPLAZADO"
echo "   3. ✅ Botones de sedes: RESTAURADOS"
echo "   4. ✅ Selector de rango: AGREGADO al Dashboard"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ DEBES VER el selector 📊 en el Dashboard"
echo "   3. Ve a 'Comparar'"
echo "   4. ✅ DEBES VER los BOTONES de sedes"
echo "   5. ✅ Haz click en los botones para seleccionar/deseleccionar sedes"
echo "   6. ✅ Cambia el rango de tiempo - LA GRÁFICA DEBE ACTUALIZARSE"
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
