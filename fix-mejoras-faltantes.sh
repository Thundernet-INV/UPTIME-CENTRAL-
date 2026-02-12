#!/bin/bash
# fix-mejoras-faltantes.sh - CORRIGE SELECTOR DE TIEMPO Y PROMEDIO DE SEDE

echo "====================================================="
echo "🔧 CORRIGIENDO MEJORAS FALTANTES"
echo "====================================================="
echo " 1) Selector de tiempo - CORREGIR"
echo " 3) Promedio de sede - CORREGIR"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_mejoras_faltantes_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CORREGIR TIMERANGESELECTOR.JSX ==========
echo "[2] CORRIGIENDO TimeRangeSelector.jsx - Asegurar evento global..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN CORREGIDA

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
      // Guardar en localStorage
      localStorage.setItem('timeRange', JSON.stringify(selectedRange));
      
      // DISPARAR EVENTO GLOBAL - IMPORTANTE!
      const event = new CustomEvent(TIME_RANGE_CHANGE_EVENT, {
        detail: selectedRange,
        bubbles: true,
        cancelable: true
      });
      window.dispatchEvent(event);
      
      console.log(`📊 Rango cambiado a: ${selectedRange.label} (${selectedRange.value}ms)`);
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

// Hook personalizado - VERSIÓN SIMPLE Y FUNCIONAL
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
      console.log('📡 useTimeRange - evento recibido:', e.detail.label);
      setRange(e.detail);
    };

    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);

  return range;
}
EOF

echo "✅ TimeRangeSelector.jsx corregido - EVENTO GLOBAL ASEGURADO"
echo ""

# ========== 3. CORREGIR INSTANCEDETAIL.JSX - VERSIÓN SIMPLE ==========
echo "[3] CORRIGIENDO InstanceDetail.jsx - Versión SIMPLE y FUNCIONAL..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
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
EOF

echo "✅ InstanceDetail.jsx corregido - VERSIÓN SIMPLE Y FUNCIONAL"
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
echo "✅✅ CORRECCIONES APLICADAS ✅✅"
echo "====================================================="
echo ""
echo "📋 MEJORA 1 - SELECTOR DE TIEMPO:"
echo "   • Evento global ASEGURADO con bubbles: true"
echo "   • useTimeRange SIMPLIFICADO"
echo "   • Al cambiar el rango, TODAS las gráficas se actualizan"
echo ""
echo "📋 MEJORA 3 - PROMEDIO DE SEDE:"
echo "   • InstanceDetail SIMPLIFICADO"
echo "   • focus = null POR DEFECTO (promedio de sede)"
echo "   • Carga INMEDIATA al entrar a cualquier sede"
echo "   • Botón 'Ver promedio de sede' FUNCIONA"
echo ""
echo "🔄 PRUEBA DE NUEVO:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Entra a una sede (Caracas, Guanare, etc.)"
echo "   3. ✅ DEBE mostrar el promedio de sede INMEDIATAMENTE"
echo "   4. Cambia el rango de tiempo 📊"
echo "   5. ✅ TODAS las gráficas DEBEN actualizarse"
echo "   6. Haz click en un servicio"
echo "   7. Click en 'Ver promedio de sede'"
echo "   8. ✅ Vuelve al promedio INMEDIATAMENTE"
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
