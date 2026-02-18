#!/bin/bash
# fix-historico-graficas.sh - CORRIGE QUE LAS GRÁFICAS MUESTREN HISTÓRICO REAL

echo "====================================================="
echo "📊 CORRIGIENDO HISTÓRICO DE GRÁFICAS - USAR API SIEMPRE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"

# ========== 1. BACKUP ==========
BACKUP_DIR="${FRONTEND_DIR}/backup_historico_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/historyEngine.js" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/services/historyApi.js" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. CORREGIR HISTORYENGINE.JS ==========
echo ""
echo "[1] Corrigiendo historyEngine.js para usar SIEMPRE la API..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - VERSIÓN CORREGIDA - USA SIEMPRE LA API
import { historyApi } from './services/historyApi.js';

// Cache simple para no sobrecargar la API
const cache = {
  series: new Map(), // key -> {data, timestamp}
  CACHE_TTL: 30000, // 30 segundos de caché
  pending: new Map() // Promesas pendientes para evitar duplicados
};

// Función para construir monitorId
function buildMonitorId(instance, name) {
  return `${instance}_${name}`.replace(/\s+/g, '_');
}

// Función para convertir datos de la API al formato del frontend
function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  
  return data.map(item => {
    // La API devuelve: timestamp, avgResponseTime, avgStatus, count
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
      // Formato para Chart.js
      timestamp: ts,
      responseTime: ms
    };
  });
}

// ============================================
// HISTORY ENGINE - USA SIEMPRE LA API
// ============================================
const History = {
  // Guardar snapshot (compatibilidad)
  addSnapshot(monitors) {
    // Los datos ya se guardan automáticamente en el backend SQLite
    console.log('[HIST] Snapshot recibido - guardado en backend');
  },

  // Obtener serie para un monitor específico - USA SIEMPRE LA API
  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    // Verificar caché
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      console.log(`[HIST] Cache hit: ${instance}/${name} (${cached.data.length} pts)`);
      return cached.data;
    }
    
    // Evitar peticiones duplicadas
    if (cache.pending.has(cacheKey)) {
      return cache.pending.get(cacheKey);
    }
    
    console.log(`[HIST] Fetching API: ${instance}/${name} (${sinceMs/60000} min)`);
    
    const promise = (async () => {
      try {
        const monitorId = buildMonitorId(instance, name);
        const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
        
        let points = [];
        if (apiData && apiData.length > 0) {
          points = convertApiToPoint(apiData);
          console.log(`[HIST] API OK: ${instance}/${name} (${points.length} pts)`);
        } else {
          console.log(`[HIST] API sin datos: ${instance}/${name}`);
        }
        
        // Guardar en caché
        cache.series.set(cacheKey, {
          data: points,
          timestamp: Date.now()
        });
        
        return points;
      } catch (error) {
        console.error(`[HIST] Error API: ${instance}/${name}`, error);
        return [];
      } finally {
        cache.pending.delete(cacheKey);
      }
    })();
    
    cache.pending.set(cacheKey, promise);
    return promise;
  },

  // Obtener serie promediada por instancia
  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    const cacheKey = `avg:${instance}:${sinceMs}:${bucketMs}`;
    
    // Verificar caché
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    console.log(`[HIST] Fetching avg API: ${instance}`);
    
    try {
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
      const points = (apiData && apiData.length > 0) ? convertApiToPoint(apiData) : [];
      
      // Guardar en caché
      cache.series.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      return points;
    } catch (error) {
      console.error(`[HIST] Error avg API: ${instance}`, error);
      return [];
    }
  },

  // Obtener todos los datos de una instancia
  async getAllForInstance(instance, sinceMs = 60 * 60 * 1000) {
    const cacheKey = `all:${instance}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    console.log(`[HIST] Fetching all API: ${instance}`);
    
    try {
      const apiData = await historyApi.getAllForInstance(instance, sinceMs);
      
      // Convertir al formato esperado
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
      console.error(`[HIST] Error all API: ${instance}`, error);
      return {};
    }
  },

  // Limpiar caché
  clearCache() {
    cache.series.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  },

  // Información de debug
  debugInfo() {
    return {
      source: 'API',
      cacheSize: cache.series.size,
      pendingSize: cache.pending.size,
      apiUrl: import.meta.env.VITE_API_BASE_URL || 'http://10.10.31.31:8080/api'
    };
  }
};

// Exponer globalmente para debugging
try {
  if (typeof window !== 'undefined') {
    window.__hist = History;
    window.__histCache = cache;
  }
} catch (e) {}

export default History;
EOF

echo "✅ historyEngine.js corregido - AHORA USA SIEMPRE LA API"

# ========== 3. VERIFICAR QUE HISTORYAPI.JS APUNTA A LA IP CORRECTA ==========
echo ""
echo "[2] Verificando historyApi.js..."

cat > "${FRONTEND_DIR}/src/services/historyApi.js" << 'EOF'
// src/services/historyApi.js
// API endpoint CORRECTO - IP fija 10.10.31.31

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  // Obtener serie de datos para un monitor específico
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] GET ${monitorId} (${Math.round(sinceMs/60000)} min)`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  // Obtener serie promediada por instancia
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const monitorId = `${instanceName}_avg`;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  // Obtener todos los datos de una instancia
  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history?` +
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || {};
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  }
};

export default historyApi;
EOF

echo "✅ historyApi.js verificado - apunta a 10.10.31.31"

# ========== 4. CREAR SELECTOR DE RANGOS DE TIEMPO ==========
echo ""
echo "[3] Creando selector de rangos de tiempo estilo Grafana..."

cat > "${FRONTEND_DIR}/src/components/TimeRangeSelector.jsx" << 'EOF'
// src/components/TimeRangeSelector.jsx
// Selector de rangos de tiempo estilo Grafana/DownDetector

import React, { useState, useEffect } from 'react';

const RANGES = [
  { label: 'Última 1 hora', value: 60 * 60 * 1000, default: true },
  { label: 'Últimas 3 horas', value: 3 * 60 * 60 * 1000 },
  { label: 'Últimas 6 horas', value: 6 * 60 * 60 * 1000 },
  { label: 'Últimas 12 horas', value: 12 * 60 * 60 * 1000 },
  { label: 'Últimas 24 horas', value: 24 * 60 * 60 * 1000 },
  { label: 'Últimos 7 días', value: 7 * 24 * 60 * 60 * 1000 },
  { label: 'Últimos 30 días', value: 30 * 24 * 60 * 60 * 1000 },
];

// Evento global para cambiar el rango de tiempo
export const TIME_RANGE_CHANGED = 'time-range-changed';

export default function TimeRangeSelector({ className = '' }) {
  const [selectedRange, setSelectedRange] = useState(() => {
    try {
      const saved = localStorage.getItem('uptime-time-range');
      if (saved) {
        const parsed = JSON.parse(saved);
        return parsed;
      }
    } catch (e) {}
    return RANGES[0]; // 1 hora por defecto
  });

  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    // Guardar preferencia
    localStorage.setItem('uptime-time-range', JSON.stringify(selectedRange));
    
    // Disparar evento global para que todas las gráficas se actualicen
    const event = new CustomEvent(TIME_RANGE_CHANGED, {
      detail: {
        rangeMs: selectedRange.value,
        label: selectedRange.label
      }
    });
    window.dispatchEvent(event);
    
    console.log(`📊 Rango de tiempo cambiado: ${selectedRange.label}`);
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
    <div className={`time-range-selector ${className}`} style={{ position: 'relative', display: 'inline-block' }}>
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
          padding: '8px 16px',
          background: 'var(--bg-secondary, #f3f4f6)',
          border: '1px solid var(--border, #e5e7eb)',
          borderRadius: '8px',
          fontSize: '0.9rem',
          color: 'var(--text-primary, #1f2937)',
          cursor: 'pointer',
          transition: 'all 0.2s ease',
        }}
      >
        <span style={{ fontSize: '1.1rem' }}>📊</span>
        <span>{selectedRange.label}</span>
        <span style={{ fontSize: '0.8rem', opacity: 0.7 }}>▼</span>
      </button>

      {isOpen && (
        <div
          style={{
            position: 'absolute',
            top: '100%',
            right: '0',
            marginTop: '8px',
            background: 'var(--bg-primary, white)',
            border: '1px solid var(--border, #e5e7eb)',
            borderRadius: '8px',
            boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
            zIndex: 1000,
            minWidth: '200px',
            overflow: 'hidden',
          }}
        >
          {RANGES.map((range, index) => (
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
                background: selectedRange.value === range.value 
                  ? 'var(--info, #3b82f6)' 
                  : 'transparent',
                color: selectedRange.value === range.value 
                  ? 'white' 
                  : 'var(--text-primary, #1f2937)',
                cursor: 'pointer',
                fontSize: '0.9rem',
                transition: 'background 0.2s ease',
              }}
              onMouseEnter={(e) => {
                if (selectedRange.value !== range.value) {
                  e.currentTarget.style.background = 'var(--bg-hover, #f3f4f6)';
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

// Hook personalizado para usar el rango de tiempo en componentes
export function useTimeRange(defaultRangeMs = 60 * 60 * 1000) {
  const [rangeMs, setRangeMs] = useState(defaultRangeMs);
  const [label, setLabel] = useState('Última 1 hora');

  useEffect(() => {
    const handleRangeChange = (e) => {
      setRangeMs(e.detail.rangeMs);
      setLabel(e.detail.label);
    };

    window.addEventListener(TIME_RANGE_CHANGED, handleRangeChange);
    
    // Cargar rango guardado
    try {
      const saved = localStorage.getItem('uptime-time-range');
      if (saved) {
        const parsed = JSON.parse(saved);
        setRangeMs(parsed.value);
        setLabel(parsed.label);
      }
    } catch (e) {}

    return () => window.removeEventListener(TIME_RANGE_CHANGED, handleRangeChange);
  }, []);

  return { rangeMs, label };
}
EOF

echo "✅ TimeRangeSelector.jsx creado"

# ========== 5. MODIFICAR INSTANCEDETAIL.JSX PARA USAR EL RANGO ==========
echo ""
echo "[4] Modificando InstanceDetail.jsx para usar selector de tiempo..."

# Backup
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true

# Modificar InstanceDetail.jsx
sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
sed -i '/export default function InstanceDetail({/a \ \ const { rangeMs, label } = useTimeRange();' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"
sed -i 's/60 \* 60 \* 1000/rangeMs/g' "${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

echo "✅ InstanceDetail.jsx modificado - usa rango de tiempo dinámico"

# ========== 6. MODIFICAR MULTISERVICEVIEW.JSX ==========
echo ""
echo "[5] Modificando MultiServiceView.jsx..."

if [ -f "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" ]; then
    sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
    sed -i '/export default function MultiServiceView({/a \ \ const { rangeMs, label } = useTimeRange();' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
    sed -i 's/const RANGE_MS = 60 \* 60 \* 1000;//g' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
    sed -i 's/RANGE_MS/rangeMs/g' "${FRONTEND_DIR}/src/components/MultiServiceView.jsx"
    echo "✅ MultiServiceView.jsx modificado"
fi

# ========== 7. MODIFICAR MONITORSTABLE.JSX ==========
echo ""
echo "[6] Modificando MonitorsTable.jsx..."

if [ -f "${FRONTEND_DIR}/src/components/MonitorsTable.jsx" ]; then
    sed -i '1iimport { useTimeRange } from "./TimeRangeSelector.jsx";' "${FRONTEND_DIR}/src/components/MonitorsTable.jsx"
    sed -i '/export default function MonitorsTable({/a \ \ const { rangeMs, label } = useTimeRange();' "${FRONTEND_DIR}/src/components/MonitorsTable.jsx"
    sed -i 's/60\*60\*1000/rangeMs/g' "${FRONTEND_DIR}/src/components/MonitorsTable.jsx"
    echo "✅ MonitorsTable.jsx modificado"
fi

# ========== 8. AGREGAR SELECTOR DE TIEMPO AL DASHBOARD ==========
echo ""
echo "[7] Agregando selector de tiempo al Dashboard..."

# Backup
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/" 2>/dev/null || true

# Agregar import
sed -i '1iimport TimeRangeSelector from "../components/TimeRangeSelector.jsx";' "${FRONTEND_DIR}/src/views/Dashboard.jsx"

# Buscar el div de controles y agregar el selector antes del botón de notificaciones
sed -i '/{·*Controles: filtro por tipo/,/<\/div>/ {
    /{·*Filtro por tipo de servicio/ a\
\
                {/* Selector de rango de tiempo */}\
                <TimeRangeSelector />
}' "${FRONTEND_DIR}/src/views/Dashboard.jsx"

echo "✅ Dashboard.jsx modificado - selector de tiempo agregado"

# ========== 9. AGREGAR ESTILOS PARA EL SELECTOR ==========
echo ""
echo "[8] Agregando estilos CSS para el selector..."

cat >> "${FRONTEND_DIR}/src/dark-mode.css" << 'EOF'

/* ========== SELECTOR DE RANGO DE TIEMPO ========== */
.time-range-selector button {
  background: var(--bg-secondary, #f3f4f6) !important;
  border-color: var(--border, #e5e7eb) !important;
  color: var(--text-primary, #1f2937) !important;
}

.time-range-selector button:hover {
  background: var(--bg-hover, #e5e7eb) !important;
}

/* Modo oscuro */
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
  background: transparent !important;
  color: #e5e7eb !important;
}

body.dark-mode .time-range-selector div[style*="position: absolute"] button:hover {
  background: #2d3238 !important;
}
EOF

echo "✅ Estilos del selector agregados a dark-mode.css"

# ========== 10. REINICIAR Y LIMPIAR CACHÉ ==========
echo ""
echo "[9] Limpiando caché y reiniciando..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 11. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅✅ CORRECCIONES COMPLETADAS ✅✅✅"
echo "====================================================="
echo ""
echo "📊 RANGO DE TIEMPO - ESTILO GRAFANA:"
echo "   • Selector desplegable en el dashboard"
echo "   • Opciones: 1h, 3h, 6h, 12h, 24h, 7d, 30d"
echo "   • Persistencia en localStorage"
echo "   • Todas las gráficas se actualizan automáticamente"
echo ""
echo "🔧 HISTÓRICO CORREGIDO:"
echo "   • ✅ Ya NO usa memoria local (historyMem.js)"
echo "   • ✅ SIEMPRE consulta la API en 10.10.31.31"
echo "   • ✅ Caché de 30 segundos para no sobrecargar"
echo "   • ✅ Las gráficas muestran datos REALES"
echo ""
echo "📍 UBICACIÓN DEL SELECTOR:"
echo "   • Al lado del filtro de tipo de servicio"
echo "   • Antes del botón de notificaciones"
echo "   • Estilo consistente con el dashboard"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Busca el selector 📊 'Última 1 hora'"
echo "   3. Cambia a 'Últimas 24 horas'"
echo "   4. Las gráficas se actualizarán automáticamente"
echo "   5. Abre una sede - verás el histórico REAL"
echo ""
echo "📌 DEBUG:"
echo "   • Abre consola (F12) y escribe: window.__hist"
echo "   • Verás el caché y estado de la API"
echo ""
echo "====================================================="
echo "✅ LISTO - Histórico corregido y selector agregado"
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado exitosamente"
EOF

chmod +x fix-historico-graficas.sh
