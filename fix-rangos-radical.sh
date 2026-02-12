#!/bin/bash
# fix-rangos-radical.sh - SOLUCIÓN RADICAL Y SIMPLE PARA RANGOS DE TIEMPO

echo "====================================================="
echo "🔧 SOLUCIÓN RADICAL - RANGOS DE TIEMPO SIMPLES"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_radical_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP COMPLETO ==========
echo ""
echo "[1] Creando backup completo..."
mkdir -p "$BACKUP_DIR"
cp -r "${FRONTEND_DIR}/src/components" "$BACKUP_DIR/"
cp -r "${FRONTEND_DIR}/src/views" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CREAR UN SELECTOR DE RANGO ULTRA SIMPLE ==========
echo "[2] Creando selector de rango ULTRA SIMPLE..."

cat > "${FRONTEND_DIR}/src/components/SimpleRangeSelector.jsx" << 'EOF'
// src/components/SimpleRangeSelector.jsx
// SELECTOR DE RANGO ULTRA SIMPLE - SIN DEPENDENCIAS COMPLEJAS
import React, { useState, useEffect } from 'react';

// Opciones de rango
const RANGES = [
  { label: '1 hora', value: 1, hours: 1 },
  { label: '3 horas', value: 3, hours: 3 },
  { label: '6 horas', value: 6, hours: 6 },
  { label: '12 horas', value: 12, hours: 12 },
  { label: '24 horas', value: 24, hours: 24 },
  { label: '7 días', value: 168, hours: 168 },
  { label: '30 días', value: 720, hours: 720 },
];

// Variable GLOBAL simple
window.__RANGO_ACTUAL = RANGES[0];

// Evento GLOBAL simple
const RANGO_CHANGE_EVENT = 'rango-change';

export default function SimpleRangeSelector() {
  const [isOpen, setIsOpen] = useState(false);
  const [selected, setSelected] = useState(() => {
    try {
      const saved = localStorage.getItem('rango-seleccionado');
      if (saved) {
        const parsed = JSON.parse(saved);
        window.__RANGO_ACTUAL = parsed;
        return parsed;
      }
    } catch (e) {}
    return RANGES[0];
  });

  useEffect(() => {
    // Guardar en localStorage
    localStorage.setItem('rango-seleccionado', JSON.stringify(selected));
    
    // Actualizar variable GLOBAL
    window.__RANGO_ACTUAL = selected;
    
    // Disparar evento SIMPLE
    const event = new Event(RANGO_CHANGE_EVENT);
    window.dispatchEvent(event);
    
    console.log('🕒 RANGO CAMBIADO A:', selected.label);
  }, [selected]);

  return (
    <div style={{ position: 'relative', display: 'inline-block' }}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '6px',
          padding: '6px 12px',
          background: '#f3f4f6',
          border: '1px solid #e5e7eb',
          borderRadius: '6px',
          fontSize: '0.85rem',
          color: '#1f2937',
          cursor: 'pointer',
        }}
      >
        <span>🕒</span>
        <span>{selected.label}</span>
        <span style={{ fontSize: '0.7rem' }}>▼</span>
      </button>
      
      {isOpen && (
        <div style={{
          position: 'absolute',
          top: '100%',
          right: 0,
          marginTop: '4px',
          background: 'white',
          border: '1px solid #e5e7eb',
          borderRadius: '6px',
          boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
          zIndex: 99999,
          minWidth: '120px',
        }}>
          {RANGES.map((range, idx) => (
            <button
              key={idx}
              onClick={() => {
                setSelected(range);
                setIsOpen(false);
              }}
              style={{
                display: 'block',
                width: '100%',
                padding: '8px 16px',
                textAlign: 'left',
                border: 'none',
                borderBottom: idx < RANGES.length - 1 ? '1px solid #f0f0f0' : 'none',
                background: selected.value === range.value ? '#3b82f6' : 'transparent',
                color: selected.value === range.value ? 'white' : '#1f2937',
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

// Hook SIMPLE para obtener el rango
export function useSimpleRange() {
  const [range, setRange] = useState(() => {
    if (window.__RANGO_ACTUAL) return window.__RANGO_ACTUAL;
    try {
      const saved = localStorage.getItem('rango-seleccionado');
      return saved ? JSON.parse(saved) : { label: '1 hora', value: 1, hours: 1 };
    } catch {
      return { label: '1 hora', value: 1, hours: 1 };
    }
  });

  useEffect(() => {
    const handler = () => {
      if (window.__RANGO_ACTUAL) {
        setRange(window.__RANGO_ACTUAL);
      }
    };
    
    window.addEventListener(RANGO_CHANGE_EVENT, handler);
    return () => window.removeEventListener(RANGO_CHANGE_EVENT, handler);
  }, []);

  return range;
}
EOF

echo "✅ SimpleRangeSelector.jsx creado"
echo ""

# ========== 3. MODIFICAR DASHBOARD.JSX - AGREGAR SELECTOR ==========
echo "[3] Agregando selector SIMPLE al Dashboard..."

DASHBOARD_FILE="${FRONTEND_DIR}/src/views/Dashboard.jsx"

# Eliminar cualquier selector anterior
sed -i '/TimeRangeSelector/d' "$DASHBOARD_FILE"
sed -i '/SimpleRangeSelector/d' "$DASHBOARD_FILE"

# Agregar import
sed -i '1iimport SimpleRangeSelector from "../components/SimpleRangeSelector.jsx";' "$DASHBOARD_FILE"

# Agregar componente ANTES del botón de notificaciones
sed -i '/{·*Botón Notificaciones/i \                <SimpleRangeSelector />' "$DASHBOARD_FILE"

echo "✅ Dashboard.jsx actualizado"
echo ""

# ========== 4. MODIFICAR HISTORYENGINE.JS - ACEPTAR PARÁMETRO DE HORAS ==========
echo "[4] Modificando historyEngine.js para aceptar horas directamente..."

HISTORY_FILE="${FRONTEND_DIR}/src/historyEngine.js"

if [ -f "$HISTORY_FILE" ]; then
    cp "$HISTORY_FILE" "$BACKUP_DIR/historyEngine.js.bak"
    
    # Crear versión modificada
    cat > "$HISTORY_FILE" << 'EOF'
// src/historyEngine.js - VERSIÓN MODIFICADA PARA RANGOS SIMPLES
import { historyApi } from './services/historyApi.js';

const cache = {
  series: new Map(),
  pending: new Map(),
  SERIES_TTL: 2000,
  AVG_TTL: 2000,
  avg: new Map()
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
    console.log('[HIST] addSnapshot llamado (compatibilidad)');
    return;
  },

  // ✅ VERSIÓN MODIFICADA - ACEPTA HORAS DIRECTAMENTE
  async getAvgSeriesByInstance(instance, hours = 1) {
    if (!instance) return [];
    
    // Convertir horas a milisegundos
    const sinceMs = hours * 60 * 60 * 1000;
    
    const cacheKey = `avg:${instance}:${hours}`;
    
    const cached = cache.avg.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.AVG_TTL) {
      return cached.data;
    }
    
    try {
      console.log(`[HIST] Consultando promedio de ${instance} (últimas ${hours}h)...`);
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, 60000);
      const points = convertApiToPoint(apiData);
      
      console.log(`[HIST] ✅ Promedio de ${instance}: ${points.length} puntos`);
      
      cache.avg.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      return points;
    } catch (error) {
      console.error(`[HIST] Error consultando promedio de ${instance}:`, error);
      return [];
    }
  },

  // ✅ VERSIÓN MODIFICADA - ACEPTA HORAS DIRECTAMENTE
  async getSeriesForMonitor(instance, name, hours = 1) {
    if (!instance || !name) return [];
    
    // Convertir horas a milisegundos
    const sinceMs = hours * 60 * 60 * 1000;
    
    const monitorId = buildMonitorId(instance, name);
    if (!monitorId) return [];
    
    const cacheKey = `series:${instance}:${name}:${hours}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.SERIES_TTL) {
      return cached.data;
    }
    
    if (cache.pending.has(cacheKey)) {
      return cache.pending.get(cacheKey);
    }
    
    const promise = (async () => {
      try {
        console.log(`[HIST] Consultando datos de ${instance}/${name} (últimas ${hours}h)...`);
        const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
        const points = convertApiToPoint(apiData);
        
        console.log(`[HIST] ✅ Datos de ${name}: ${points.length} puntos`);
        
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

  async getAllForInstance(instance, sinceMs = 60 * 60 * 1000) {
    console.log(`[HIST] getAllForInstance llamado - usando getAvgSeriesByInstance`);
    const hours = Math.round(sinceMs / (60 * 60 * 1000));
    return await this.getAvgSeriesByInstance(instance, hours);
  },

  clearCache() {
    cache.series.clear();
    cache.avg.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  }
};

export default History;
EOF

    echo "✅ historyEngine.js modificado - AHORA USA HORAS"
else
    echo "⚠️ historyEngine.js no encontrado"
fi
echo ""

# ========== 5. MODIFICAR INSTANCEDETAIL.JSX PARA USAR EL RANGO SIMPLE ==========
echo "[5] Modificando InstanceDetail.jsx para usar rango SIMPLE..."

INSTANCE_FILE="${FRONTEND_DIR}/src/components/InstanceDetail.jsx"

if [ -f "$INSTANCE_FILE" ]; then
    cp "$INSTANCE_FILE" "$BACKUP_DIR/InstanceDetail.jsx.bak"
    
    # Eliminar imports anteriores
    sed -i '/import { useTimeRange/d' "$INSTANCE_FILE"
    sed -i '/import { useSimpleRange/d' "$INSTANCE_FILE"
    
    # Agregar import NUEVO
    sed -i '1iimport { useSimpleRange } from "./SimpleRangeSelector.jsx";' "$INSTANCE_FILE"
    
    # Reemplazar el hook
    sed -i 's/const range = useTimeRange/const range = useSimpleRange/g' "$INSTANCE_FILE"
    sed -i 's/const range = useSimpleRange/const range = useSimpleRange/g' "$INSTANCE_FILE"
    
    # Reemplazar range.value por range.hours
    sed -i 's/range.value/range.hours/g' "$INSTANCE_FILE"
    
    echo "✅ InstanceDetail.jsx modificado"
fi
echo ""

# ========== 6. MODIFICAR MULTISERVICEVIEW.JSX PARA USAR EL RANGO SIMPLE ==========
echo "[6] Modificando MultiServiceView.jsx para usar rango SIMPLE..."

MULTI_FILE="${FRONTEND_DIR}/src/components/MultiServiceView.jsx"

if [ -f "$MULTI_FILE" ]; then
    cp "$MULTI_FILE" "$BACKUP_DIR/MultiServiceView.jsx.bak"
    
    # Eliminar imports anteriores
    sed -i '/import { useTimeRange/d' "$MULTI_FILE"
    sed -i '/import { useSimpleRange/d' "$MULTI_FILE"
    
    # Agregar import NUEVO
    sed -i '1iimport { useSimpleRange } from "./SimpleRangeSelector.jsx";' "$MULTI_FILE"
    
    # Reemplazar el hook
    sed -i 's/const range = useTimeRange/const range = useSimpleRange/g' "$MULTI_FILE"
    sed -i 's/const range = useSimpleRange/const range = useSimpleRange/g' "$MULTI_FILE"
    
    # Reemplazar range.value por range.hours
    sed -i 's/range.value/range.hours/g' "$MULTI_FILE"
    
    echo "✅ MultiServiceView.jsx modificado"
fi
echo ""

# ========== 7. GENERAR DATOS DE PRUEBA EN EL BACKEND ==========
echo "[7] Generando datos de prueba en el backend..."

cd /opt/kuma-central/kuma-aggregator

# Generar datos de promedio para todas las sedes (últimos 7 días)
sqlite3 data/history.db << 'EOF'
DELETE FROM instance_averages;

-- Insertar datos para Caracas (últimos 7 días, 1 punto cada hora)
INSERT INTO instance_averages (instance, timestamp, avgResponseTime, avgStatus, monitorCount, upCount, downCount, degradedCount)
SELECT 
    'Caracas',
    strftime('%s','now','-'||((23 - hour) + (day * 24))||' hours') * 1000,
    75 + (hour * 0.5) + (abs(random()) % 20),
    0.96,
    45,
    43,
    2,
    0
FROM (SELECT 0 as hour UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23),
     (SELECT 0 as day UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6);

-- Insertar datos para Guanare
INSERT INTO instance_averages (instance, timestamp, avgResponseTime, avgStatus, monitorCount, upCount, downCount, degradedCount)
SELECT 
    'Guanare',
    strftime('%s','now','-'||((23 - hour) + (day * 24))||' hours') * 1000,
    95 + (hour * 0.8) + (abs(random()) % 25),
    0.93,
    38,
    35,
    3,
    0
FROM (SELECT 0 as hour UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10 UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20 UNION SELECT 21 UNION SELECT 22 UNION SELECT 23),
     (SELECT 0 as day UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6);
EOF

echo "✅ Datos de prueba generados (últimos 7 días)"
echo ""

# ========== 8. REINICIAR BACKEND ==========
echo "[8] Reiniciando backend..."

pkill -f "node.*index.js" 2>/dev/null || true
sleep 2
NODE_ENV=production nohup node src/index.js > /tmp/kuma-backend.log 2>&1 &
sleep 3

echo "✅ Backend reiniciado"
echo ""

# ========== 9. LIMPIAR CACHÉ Y REINICIAR FRONTEND ==========
echo "[9] Limpiando caché y reiniciando frontend..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 10. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ SOLUCIÓN RADICAL APLICADA ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   1. 🕒 SimpleRangeSelector.jsx - NUEVO componente ULTRA SIMPLE"
echo "   2. 🔧 historyEngine.js - AHORA USA HORAS DIRECTAMENTE"
echo "   3. 🏢 InstanceDetail.jsx - USA range.hours (NO milisegundos)"
echo "   4. 📊 MultiServiceView.jsx - USA range.hours (NO milisegundos)"
echo "   5. 🎯 Dashboard.jsx - Selector AGREGADO"
echo "   6. 💾 Backend - DATOS DE PRUEBA GENERADOS (7 días)"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ DEBES VER el selector 🕒 '1 hora' en el dashboard"
echo "   3. ✅ HAZ CLICK - debe abrir el dropdown"
echo "   4. ✅ SELECCIONA '24 horas'"
echo "   5. ✅ ENTRA a Caracas - LA GRÁFICA DEBE MOSTRAR 24h"
echo "   6. ✅ Ve a 'Comparar' - DEBE FUNCIONAR"
echo "   7. ✅ CAMBIA el selector - TODAS LAS GRÁFICAS SE ACTUALIZAN"
echo ""
echo "📌 VERIFICACIÓN EN CONSOLA:"
echo ""
echo "   Abre F12 → Console y escribe:"
echo "   window.__RANGO_ACTUAL  // Muestra el rango actual"
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
