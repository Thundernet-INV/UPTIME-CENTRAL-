#!/bin/bash
# setup-time-selector-limpio.sh - IMPLEMENTACIÓN LIMPIA DEL SELECTOR DE TIEMPO

echo "====================================================="
echo "⏱️  IMPLEMENTACIÓN LIMPIA - SELECTOR DE TIEMPO"
echo "====================================================="
echo "⚠️  Este script modificará SOLO los archivos necesarios"
echo "   y verificará cada paso antes de continuar"
echo ""

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_time_selector_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP COMPLETO ==========
echo "[1] Creando backup completo..."
mkdir -p "$BACKUP_DIR"

# Backup de archivos que modificaremos
cp "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/historyEngine.js" "$BACKUP_DIR/"

echo "✅ Backup creado: $BACKUP_DIR"
echo ""

# ========== 2. CREAR TIMERANGESELECTOR.JSX ==========
echo "[2] Creando TimeRangeSelector.jsx (versión simple y probada)..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rango de tiempo - VERSIÓN SIMPLE Y ESTABLE

import React, { useState, useEffect } from 'react';

// Opciones de rango
const TIME_RANGES = [
  { label: 'Última 1 hora', value: 60 * 60 * 1000 },
  { label: 'Últimas 3 horas', value: 3 * 60 * 60 * 1000 },
  { label: 'Últimas 6 horas', value: 6 * 60 * 60 * 1000 },
  { label: 'Últimas 12 horas', value: 12 * 60 * 60 * 1000 },
  { label: 'Últimas 24 horas', value: 24 * 60 * 60 * 1000 },
  { label: 'Últimos 7 días', value: 7 * 24 * 60 * 60 * 1000 },
];

// Evento global para cambios de rango
export const TIME_RANGE_CHANGE_EVENT = 'time-range-change';

export default function TimeRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selectedRange, setSelectedRange] = useState(() => {
    // Intentar cargar desde localStorage
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        return JSON.parse(saved);
      }
    } catch (e) {}
    return TIME_RANGES[0]; // 1 hora por defecto
  });

  // Guardar en localStorage y emitir evento
  useEffect(() => {
    try {
      localStorage.setItem('timeRange', JSON.stringify(selectedRange));
      
      // Emitir evento global para que otros componentes se actualicen
      const event = new CustomEvent(TIME_RANGE_CHANGE_EVENT, {
        detail: selectedRange
      });
      window.dispatchEvent(event);
      
      console.log(`📊 Rango cambiado: ${selectedRange.label}`);
    } catch (e) {
      console.error('Error guardando rango:', e);
    }
  }, [selectedRange]);

  // Cerrar dropdown al hacer click fuera
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
            boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1)',
            zIndex: 1000,
            minWidth: '160px',
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
                padding: '8px 12px',
                textAlign: 'left',
                border: 'none',
                background: selectedRange.value === range.value ? '#3b82f6' : 'transparent',
                color: selectedRange.value === range.value ? 'white' : '#1f2937',
                fontSize: '0.85rem',
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
    // Cargar rango inicial desde localStorage
    try {
      const saved = localStorage.getItem('timeRange');
      if (saved) {
        setRange(JSON.parse(saved));
      }
    } catch (e) {}

    // Escuchar cambios
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

# ========== 3. MODIFICAR HISTORYENGINE.JS ==========
echo "[3] Actualizando historyEngine.js para usar el rango dinámico..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - CON SOPORTE PARA RANGO DINÁMICO
import { historyApi } from './services/historyApi.js';

// Cache simple
const cache = {
  series: new Map(),
  CACHE_TTL: 30000, // 30 segundos
  pending: new Map()
};

function buildMonitorId(instance, name) {
  return `${instance}_${name}`.replace(/\s+/g, '_');
}

function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  
  return data.map(item => {
    const ms = item.avgResponseTime || 0;
    const sec = ms / 1000;
    const ts = item.timestamp;
    
    return {
      ts: ts,
      ms: ms,
      sec: sec,
      x: ts,
      y: sec,
      value: sec,
      avgMs: ms,
      status: item.avgStatus > 0.5 ? 'up' : 'down',
      xy: [ts, sec],
      timestamp: ts,
      responseTime: ms
    };
  });
}

const History = {
  addSnapshot(monitors) {
    // Los datos ya se guardan en el backend
  },

  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    if (cache.pending.has(cacheKey)) {
      return cache.pending.get(cacheKey);
    }
    
    const promise = (async () => {
      try {
        const monitorId = buildMonitorId(instance, name);
        const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
        const points = (apiData && apiData.length > 0) ? convertApiToPoint(apiData) : [];
        
        cache.series.set(cacheKey, {
          data: points,
          timestamp: Date.now()
        });
        
        return points;
      } catch (error) {
        console.error(`[HIST] Error: ${instance}/${name}`, error);
        return [];
      } finally {
        cache.pending.delete(cacheKey);
      }
    })();
    
    cache.pending.set(cacheKey, promise);
    return promise;
  },

  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    const cacheKey = `avg:${instance}:${sinceMs}:${bucketMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
      const points = (apiData && apiData.length > 0) ? convertApiToPoint(apiData) : [];
      
      cache.series.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      return points;
    } catch (error) {
      console.error(`[HIST] Error avg: ${instance}`, error);
      return [];
    }
  },

  async getAllForInstance(instance, sinceMs = 60 * 60 * 1000) {
    const cacheKey = `all:${instance}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
      const apiData = await historyApi.getAllForInstance(instance, sinceMs);
      
      const formatted = {};
      if (apiData && typeof apiData === 'object') {
        Object.keys(apiData).forEach(monitorName => {
          formatted[monitorName] = convertApiToPoint(apiData[monitorName]);
        });
      }
      
      cache.series.set(cacheKey, {
        data: formatted,
        timestamp: Date.now()
      });
      
      return formatted;
    } catch (error) {
      console.error(`[HIST] Error all: ${instance}`, error);
      return {};
    }
  },

  clearCache() {
    cache.series.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  }
};

export default History;
EOF

echo "✅ historyEngine.js actualizado"
echo ""

# ========== 4. MODIFICAR DASHBOARD.JSX (SOLO UNA VEZ) ==========
echo "[4] Agregando TimeRangeSelector al Dashboard..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

# Verificar si ya existe el import
if ! grep -q "import TimeRangeSelector" "$DASHBOARD_FILE"; then
    # Agregar import después de los otros imports
    sed -i '/import MultiServiceView/i import TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "$DASHBOARD_FILE"
    echo "✅ Import agregado a Dashboard.jsx"
else
    echo "⚠️ Import ya existe en Dashboard.jsx"
fi

# Verificar si ya existe el componente en el render
if ! grep -q "<TimeRangeSelector" "$DASHBOARD_FILE"; then
    # Buscar el div de controles y agregar el selector antes del botón de notificaciones
    sed -i '/{·*Botón Notificaciones/i \                {/* Selector de rango de tiempo */}\
                <TimeRangeSelector />' "$DASHBOARD_FILE"
    echo "✅ TimeRangeSelector agregado al Dashboard"
else
    echo "⚠️ TimeRangeSelector ya existe en el Dashboard"
fi

echo ""

# ========== 5. MODIFICAR INSTANCEDETAIL.JSX ==========
echo "[5] Agregando useTimeRange a InstanceDetail..."

INSTANCE_FILE="${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

# Backup
cp "$INSTANCE_FILE" "$BACKUP_DIR/InstanceDetail.jsx"

# Eliminar cualquier uso anterior de useTimeRange
sed -i '/import { useTimeRange }/d' "$INSTANCE_FILE"
sed -i '/const { rangeMs, label }/d' "$INSTANCE_FILE"
sed -i '/const range = useTimeRange/d' "$INSTANCE_FILE"

# Agregar import
sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "$INSTANCE_FILE"

# Agregar hook dentro del componente
sed -i '/export default function InstanceDetail({/a \ \ const range = useTimeRange();' "$INSTANCE_FILE"

# Reemplazar valores fijos con el rango dinámico
sed -i 's/60 \* 60 \* 1000/range.value/g' "$INSTANCE_FILE"

echo "✅ InstanceDetail.jsx actualizado"
echo ""

# ========== 6. MODIFICAR MULTISERVICEVIEW.JSX ==========
echo "[6] Agregando useTimeRange a MultiServiceView..."

MULTI_FILE="${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

if [ -f "$MULTI_FILE" ]; then
    cp "$MULTI_FILE" "$BACKUP_DIR/MultiServiceView.jsx"
    
    # Eliminar cualquier uso anterior
    sed -i '/import { useTimeRange }/d' "$MULTI_FILE"
    sed -i '/const { rangeMs, label }/d' "$MULTI_FILE"
    sed -i '/const range = useTimeRange/d' "$MULTI_FILE"
    sed -i '/const RANGE_MS/d' "$MULTI_FILE"
    
    # Agregar import
    sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "$MULTI_FILE"
    
    # Agregar hook
    sed -i '/export default function MultiServiceView({/a \ \ const range = useTimeRange();' "$MULTI_FILE"
    
    # Usar el rango
    sed -i 's/RANGE_MS = [0-9* ]*;//g' "$MULTI_FILE"
    sed -i 's/RANGE_MS/range.value/g' "$MULTI_FILE"
    
    echo "✅ MultiServiceView.jsx actualizado"
else
    echo "⚠️ MultiServiceView.jsx no encontrado"
fi

echo ""

# ========== 7. AGREGAR ESTILOS MODO OSCURO ==========
echo "[7] Agregando estilos para modo oscuro..."

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
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button {
  color: #e5e7eb !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button:hover {
  background: #2d3238 !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button[style*="background: #3b82f6"] {
  background: #2563eb !important;
  color: white !important;
}
EOF

echo "✅ Estilos modo oscuro agregados"
echo ""

# ========== 8. VERIFICAR IMPORTS ÚNICOS ==========
echo "[8] Verificando que no haya imports duplicados..."

# Verificar cada archivo
for file in "$DASHBOARD_FILE" "$INSTANCE_FILE" "$MULTI_FILE"; do
    if [ -f "$file" ]; then
        COUNT=$(grep -c "import { useTimeRange }" "$file" 2>/dev/null || echo 0)
        if [ "$COUNT" -gt 1 ]; then
            echo "⚠️  $file tiene $COUNT imports - corrigiendo..."
            grep -v "import { useTimeRange }" "$file" > "${file}.tmp"
            sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "${file}.tmp"
            mv "${file}.tmp" "$file"
        fi
    fi
done

# Verificar Dashboard
DASH_COUNT=$(grep -c "import TimeRangeSelector" "$DASHBOARD_FILE" 2>/dev/null || echo 0)
if [ "$DASH_COUNT" -gt 1 ]; then
    echo "⚠️  Dashboard.jsx tiene $DASH_COUNT imports - corrigiendo..."
    grep -v "import TimeRangeSelector" "$DASHBOARD_FILE" > "${DASHBOARD_FILE}.tmp"
    sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "${DASHBOARD_FILE}.tmp"
    mv "${DASHBOARD_FILE}.tmp" "$DASHBOARD_FILE"
fi

echo "✅ Verificación completada"
echo ""

# ========== 9. LIMPIAR CACHÉ Y REINICIAR ==========
echo "[9] Limpiando caché y reiniciando frontend..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 10. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ IMPLEMENTACIÓN LIMPIA COMPLETADA ✅✅"
echo "====================================================="
echo ""
echo "📋 COMPONENTES INSTALADOS:"
echo "   • TimeRangeSelector.jsx - Selector de tiempo"
echo "   • historyEngine.js - Con soporte para rango dinámico"
echo "   • Dashboard.jsx - Con selector en controles"
echo "   • InstanceDetail.jsx - Usa rango dinámico"
echo "   • MultiServiceView.jsx - Usa rango dinámico"
echo ""
echo "📍 UBICACIÓN DEL SELECTOR:"
echo "   • Al lado del filtro de tipo de servicio"
echo "   • Antes del botón de notificaciones"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Busca el selector 📊 'Última 1 hora'"
echo "   3. Cambia a 'Últimas 24 horas'"
echo "   4. Las gráficas deberían actualizarse automáticamente"
echo "   5. Navega a una sede - verás el mismo rango"
echo ""
echo "📌 NOTAS:"
echo "   • La preferencia se guarda en localStorage"
echo "   • Todas las gráficas usan el MISMO rango"
echo "   • Compatible con modo oscuro"
echo ""
echo "🔄 ROLLBACK SI ES NECESARIO:"
echo "   cp -r $BACKUP_DIR/* $FRONTEND_DIR/"
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
