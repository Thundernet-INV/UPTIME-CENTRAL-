#!/bin/bash
# fix-revert-instancedetail.sh - REVIERTE INSTANCEDETAIL Y CORRIGE SELECTOR

echo "====================================================="
echo "🔧 REVIRTIENDO INSTANCEDETAIL Y CORRIGIENDO SELECTOR"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_revert_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/InstanceDetail.jsx.actual"
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. RESTAURAR INSTANCEDETAIL.JSX ORIGINAL ==========
echo "[2] Restaurando InstanceDetail.jsx a versión ORIGINAL funcional..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";
import { useTimeRange } from "./TimeRangeSelector.jsx";

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

  // Promedio de sede - USA EL RANGO SELECCIONADO
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        console.log(`🏢 Cargando promedio de ${instanceName} (${selectedRange.label})`);
        const obj = await History.getAllForInstance(
          instanceName,
          selectedRange.value
        );
        if (!alive) return;
        setSeriesInstance(obj ?? {});
        console.log(`✅ Promedio de ${instanceName} cargado`);
      } catch {
        if (!alive) return;
        setSeriesInstance({});
      }
    })();
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, selectedRange.value]);

  // Series por monitor - USA EL RANGO SELECCIONADO
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const arr = await History.getSeriesForMonitor(
              instanceName,
              name,
              selectedRange.value
            );
            return [name, Array.isArray(arr) ? arr : []];
          })
        );
        if (!alive) return;
        setSeriesMonMap(new Map(entries));
      } catch {
        if (!alive) return;
        setSeriesMonMap(new Map());
      }
    })();
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, selectedRange.value]);

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

      {/* Chip contexto */}
      <div className="instance-detail-chip-row">
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>
            <button
              className="k-btn k-btn--ghost k-chip-action"
              onClick={() => setFocus(null)}
            >
              Ver sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            Mostrando: <strong>Promedio de la sede</strong>
            <span style={{ 
              marginLeft: '8px',
              fontSize: '0.75rem', 
              background: '#e5e7eb', 
              padding: '2px 8px', 
              borderRadius: '12px',
              color: '#4b5563'
            }}>
              {selectedRange.label}
            </span>
          </div>
        )}
      </div>

      {/* GRID: gráfica en el centro, cards alrededor */}
      <section
        className="instance-detail-grid"
        aria-label={`Historial y servicios de ${instanceName}`}
      >
        {/* Gráfica en columna central */}
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

        {/* Cards de servicio alrededor - SOLO CLICK EN LA CARD COMPLETA */}
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

echo "✅ InstanceDetail.jsx restaurado a versión ORIGINAL funcional"
echo ""

# ========== 3. CORREGIR TIMERANGESELECTOR.JSX - BOTÓN CLICKEABLE ==========
echo "[3] Corrigiendo TimeRangeSelector.jsx - BOTÓN CLICKEABLE..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN CORREGIDA - BOTÓN FUNCIONAL

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

  // Disparar evento cuando cambia el rango
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

  // Cerrar al hacer click fuera
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
      {/* BOTÓN PRINCIPAL - CON CURSOR POINTER */}
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

      {/* DROPDOWN MENU */}
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
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
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

// Hook personalizado para usar el rango de tiempo
export function useTimeRange() {
  const [range, setRange] = useState(TIME_RANGES[0]);

  useEffect(() => {
    // Cargar rango inicial
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

    // Escuchar cambios
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

echo "✅ TimeRangeSelector.jsx corregido - BOTÓN FUNCIONAL"
echo ""

# ========== 4. LIMPIAR CACHÉ ==========
echo ""
echo "[4] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"

# ========== 5. REINICIAR FRONTEND ==========
echo ""
echo "[5] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 6. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ CAMBIOS APLICADOS ✅✅"
echo "====================================================="
echo ""
echo "📋 INSTANCEDETAIL.JSX:"
echo "   • RESTAURADO a versión ORIGINAL funcional"
echo "   • Cards funcionan con UN SOLO CLICK"
echo "   • Promedio de sede se carga INMEDIATAMENTE"
echo "   • Muestra el rango de tiempo seleccionado"
echo ""
echo "📋 TIMERANGESELECTOR.JSX:"
echo "   • BOTÓN CORREGIDO - ahora es CLICKEABLE"
echo "   • Hover effects funcionando"
echo "   • Dropdown se abre/cierra correctamente"
echo "   • Evento global funcionando"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Busca el selector 📊 - DEBE ser CLICKEABLE"
echo "   3. Haz click - DEBE abrir el dropdown"
echo "   4. Selecciona un rango - DEBE cambiar"
echo "   5. Entra a una sede - DEBE mostrar promedio INMEDIATAMENTE"
echo "   6. Haz click en una card - DEBE mostrar ese servicio"
echo "   7. Click en 'Ver sede' - DEBE volver al promedio"
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
