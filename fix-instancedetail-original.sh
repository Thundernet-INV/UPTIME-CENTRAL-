#!/bin/bash
# fix-instancedetail-original.sh - RESTAURAR VERSIÓN ORIGINAL Y CORREGIR SELECTOR

echo "====================================================="
echo "🔧 RESTAURANDO INSTANCEDETAIL.JSX ORIGINAL"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_instancedetail_original_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. RESTAURAR INSTANCEDETAIL.JSX ORIGINAL ==========
echo "[2] Restaurando InstanceDetail.jsx - VERSIÓN ORIGINAL FUNCIONAL..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
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

  // 🟢 PROMEDIO DE SEDE - Usa getAvgSeriesByInstance
  useEffect(() => {
    let alive = true;
    
    const fetchAvg = async () => {
      try {
        console.log(`🏢 Cargando promedio de ${instanceName}`);
        const series = await History.getAvgSeriesByInstance(instanceName, 60 * 60 * 1000);
        if (alive) {
          setAvgSeries(series || []);
          console.log(`✅ Promedio de ${instanceName}: ${series?.length || 0} puntos`);
        }
      } catch (error) {
        console.error(`Error cargando promedio de ${instanceName}:`, error);
        if (alive) setAvgSeries([]);
      }
    };
    
    fetchAvg();
    
    return () => { alive = false; };
  }, [instanceName, tick]);

  // 🟢 MONITORES INDIVIDUALES
  useEffect(() => {
    let alive = true;
    
    const fetchMonitors = async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const series = await History.getSeriesForMonitor(
              instanceName,
              name,
              60 * 60 * 1000
            );
            return [name, series || []];
          })
        );
        
        if (alive) {
          setSeriesMonMap(new Map(entries));
        }
      } catch (error) {
        console.error(`Error cargando monitores de ${instanceName}:`, error);
        if (alive) setSeriesMonMap(new Map());
      }
    };
    
    fetchMonitors();
    
    return () => { alive = false; };
  }, [instanceName, group.length, tick]);

  // Datos para la gráfica
  const chartData = focus 
    ? seriesMonMap.get(focus) || [] 
    : avgSeries;

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
          <HistoryChart
            mode={focus ? "monitor" : "instance"}
            seriesMon={chartData}
            title={focus || `Promedio de ${instanceName}`}
          />

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
EOF

echo "✅ InstanceDetail.jsx restaurado - VERSIÓN ORIGINAL FUNCIONAL"
echo ""

# ========== 3. CORREGIR TIMERANGESELECTOR.JSX ==========
echo "[3] Corrigiendo TimeRangeSelector.jsx - SELECTOR CLICKEABLE..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN SIMPLE Y FUNCIONAL

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
          console.log('📊 Click en selector de tiempo');
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
        onMouseEnter={(e) => {
          e.currentTarget.style.background = 'var(--bg-hover, #e5e7eb)';
        }}
        onMouseLeave={(e) => {
          e.currentTarget.style.background = 'var(--bg-secondary, #f3f4f6)';
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
                console.log(`📊 Seleccionando rango: ${range.label}`);
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
          console.log(`📊 useTimeRange - rango inicial: ${parsed.label}`);
        }
      }
    } catch (e) {}

    const handleRangeChange = (e) => {
      console.log(`📡 useTimeRange - evento recibido: ${e.detail.label}`);
      setRange(e.detail);
    };

    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  return range;
}
EOF

echo "✅ TimeRangeSelector.jsx corregido - SELECTOR CLICKEABLE"
echo ""

# ========== 4. ACTUALIZAR DASHBOARD.JSX PARA USAR SELECTOR ==========
echo "[4] Actualizando Dashboard.jsx - Agregar selector de rango..."

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
echo "✅✅ INSTANCEDETAIL RESTAURADO Y SELECTOR CORREGIDO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🏢 InstanceDetail.jsx: VERSIÓN ORIGINAL RESTAURADA"
echo "      • Las cards muestran las gráficas SIN hacer click"
echo "      • El promedio de sede se carga automáticamente"
echo "      • Click en card selecciona el monitor"
echo ""
echo "   2. 📊 TimeRangeSelector.jsx: SELECTOR CLICKEABLE"
echo "      • Botón con cursor pointer"
echo "      • Hover effects"
echo "      • Dropdown funcional"
echo "      • Eventos globales funcionando"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ Busca el selector 📊 en el dashboard - DEBE SER CLICKEABLE"
echo "   3. ✅ Haz click - DEBE abrir el dropdown"
echo "   4. ✅ Selecciona un rango - DEBE cambiar"
echo "   5. ✅ Entra a Caracas o Guanare"
echo "   6. ✅ LA GRÁFICA DE PROMEDIO DEBE APARECER INMEDIATAMENTE"
echo "   7. ✅ Las cards muestran sus sparklines SIN hacer click"
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
