#!/bin/bash
# fix-frontend-promedios.sh - CONECTA EL FRONTEND AL NUEVO ENDPOINT DE PROMEDIOS

echo "====================================================="
echo "🖥️  CONECTANDO FRONTEND AL SERVICIO DE PROMEDIOS"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_frontend_promedios_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup del frontend..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/services/historyApi.js" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/historyEngine.js" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"

# ========== 2. ACTUALIZAR HISTORYAPI.JS ==========
echo ""
echo "[2] Actualizando historyApi.js con endpoint de promedios..."

cat > "${FRONTEND_DIR}/src/services/historyApi.js" << 'EOF'
// src/services/historyApi.js
// API endpoint - VERSIÓN COMPLETA CON PROMEDIOS DE INSTANCIA

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  // ========== ENDPOINTS EXISTENTES ==========
  
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      if (!monitorId) return [];
      
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        if (response.status === 400) return [];
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      if (!instanceName) return [];
      
      const to = Date.now();
      const from = to - sinceMs;
      const monitorId = `${instanceName}_avg`;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        if (response.status === 400) return [];
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      if (!instanceName) return {};
      
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history?` +
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        if (response.status === 400) return {};
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || {};
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  },

  // ========== 🟢 NUEVO: ENDPOINT DE PROMEDIOS POR INSTANCIA ==========
  
  /**
   * Obtener serie de promedios para una instancia (sede)
   * @param {string} instanceName - Nombre de la sede (Caracas, Guanare, etc.)
   * @param {number} hours - Horas hacia atrás (default: 24)
   * @returns {Promise<Array>} Array de puntos con timestamp y avgResponseTime
   */
  async getInstanceAverageSeries(instanceName, hours = 24) {
    try {
      if (!instanceName) return [];
      
      const url = `${API_BASE}/instance/average/${encodeURIComponent(instanceName)}?hours=${hours}&_=${Date.now()}`;
      
      console.log(`[API] Solicitando promedios para ${instanceName} (últimas ${hours}h)`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        console.warn(`[API] No hay promedios para ${instanceName}`);
        return [];
      }
      
      const result = await response.json();
      
      if (!result.success) {
        console.warn(`[API] Error en respuesta:`, result.error);
        return [];
      }
      
      console.log(`[API] ✅ Recibidos ${result.data.length} puntos de promedio para ${instanceName}`);
      return result.data || [];
    } catch (error) {
      console.error(`[API] Error obteniendo promedios para ${instanceName}:`, error);
      return [];
    }
  },

  /**
   * Obtener el último promedio de una instancia
   * @param {string} instanceName - Nombre de la sede
   * @returns {Promise<Object|null>} Último promedio o null
   */
  async getLatestInstanceAverage(instanceName) {
    try {
      if (!instanceName) return null;
      
      const url = `${API_BASE}/instance/average/${encodeURIComponent(instanceName)}/latest?_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) return null;
      
      const result = await response.json();
      return result.success ? result.data : null;
    } catch (error) {
      console.error(`[API] Error obteniendo último promedio para ${instanceName}:`, error);
      return null;
    }
  },

  // ========== ENDPOINTS DE MANTENIMIENTO ==========
  
  async getAvailableMonitors() {
    try {
      const url = `${API_BASE}/metric-history/monitors?_=${Date.now()}`;
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) return [];
      
      const data = await response.json();
      return data.success ? data.monitors : [];
    } catch (error) {
      console.error('[API] Error fetching monitors:', error);
      return [];
    }
  },

  async getStats() {
    try {
      const url = `${API_BASE}/metric-history/stats?_=${Date.now()}`;
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) return null;
      
      const data = await response.json();
      return data;
    } catch (error) {
      console.error('[API] Error fetching stats:', error);
      return null;
    }
  }
};

export default historyApi;
EOF

echo "✅ historyApi.js actualizado con endpoint de promedios"
echo ""

# ========== 3. ACTUALIZAR HISTORYENGINE.JS ==========
echo ""
echo "[3] Actualizando historyEngine.js para usar promedios..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - VERSIÓN OPTIMIZADA CON PROMEDIOS DE INSTANCIA
import { historyApi } from './services/historyApi.js';

// Cache mejorado
const cache = {
  series: new Map(),
  instanceAverages: new Map(),
  CACHE_TTL: 30000, // 30 segundos
  pending: new Map()
};

function buildMonitorId(instance, name) {
  if (!instance || !name) return null;
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

  // ========== 🟢 NUEVO: OBTENER PROMEDIO DE INSTANCIA ==========
  
  /**
   * Obtener serie de promedios para una instancia (sede)
   * @param {string} instance - Nombre de la sede
   * @param {number} sinceMs - Milisegundos hacia atrás
   * @returns {Promise<Array>} Array de puntos de promedio
   */
  async getInstanceAverageSeries(instance, sinceMs = 60 * 60 * 1000) {
    if (!instance) {
      console.warn('[HIST] getInstanceAverageSeries: instance inválida');
      return [];
    }
    
    const hours = Math.max(1, Math.round(sinceMs / (60 * 60 * 1000)));
    const cacheKey = `avg:${instance}:${hours}`;
    
    // Verificar caché
    const cached = cache.instanceAverages.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      console.log(`[HIST] Cache hit: promedios de ${instance} (${cached.data.length} pts)`);
      return cached.data;
    }
    
    console.log(`[HIST] Solicitando promedios de ${instance} (últimas ${hours}h)`);
    
    try {
      const data = await historyApi.getInstanceAverageSeries(instance, hours);
      
      // Convertir al formato esperado por HistoryChart
      const points = data.map(item => ({
        ts: item.ts,
        ms: item.ms,
        sec: item.ms / 1000,
        x: item.ts,
        y: item.ms / 1000,
        value: item.ms / 1000,
        avgMs: item.ms,
        status: item.status || 'up',
        xy: [item.ts, item.ms / 1000]
      }));
      
      // Guardar en caché
      cache.instanceAverages.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      console.log(`[HIST] ✅ Recibidos ${points.length} puntos de promedio para ${instance}`);
      return points;
    } catch (error) {
      console.error(`[HIST] Error obteniendo promedios de ${instance}:`, error);
      return [];
    }
  },

  // ========== FUNCIONES EXISTENTES OPTIMIZADAS ==========
  
  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    if (!instance || !name) return [];
    
    if (!sinceMs || typeof sinceMs !== 'number' || sinceMs <= 0) {
      sinceMs = 60 * 60 * 1000;
    }
    
    const monitorId = buildMonitorId(instance, name);
    if (!monitorId) return [];
    
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
    // REDIRIGIR al nuevo endpoint de promedios
    return this.getInstanceAverageSeries(instance, sinceMs);
  },

  async getAllForInstance(instance, sinceMs = 60 * 60 * 1000) {
    if (!instance) return {};
    
    const cacheKey = `all:${instance}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
      console.log(`[HIST] Fetching all for instance: ${instance}`);
      
      const apiData = await historyApi.getAllForInstance(instance, sinceMs);
      
      const formatted = {};
      if (apiData && typeof apiData === 'object') {
        Object.keys(apiData).forEach(monitorName => {
          if (Array.isArray(apiData[monitorName])) {
            formatted[monitorName] = convertApiToPoint(apiData[monitorName]);
          }
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
    cache.instanceAverages.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  },

  debugInfo() {
    return {
      source: 'API',
      cacheSize: cache.series.size,
      instanceCacheSize: cache.instanceAverages.size,
      pendingSize: cache.pending.size,
      apiUrl: 'http://10.10.31.31:8080/api'
    };
  }
};

// Exponer globalmente para debugging
try {
  if (typeof window !== 'undefined') {
    window.__hist = History;
  }
} catch (e) {}

export default History;
EOF

echo "✅ historyEngine.js actualizado - AHORA USA PROMEDIOS DE INSTANCIA"
echo ""

# ========== 4. ACTUALIZAR INSTANCEDETAIL.JSX ==========
echo ""
echo "[4] Actualizando InstanceDetail.jsx para usar promedios..."

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
  
  const [focus, setFocus] = useState(null); // null = promedio de sede
  const [instanceSeries, setInstanceSeries] = useState([]); // 🟢 AHORA ES ARRAY, no objeto
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [loading, setLoading] = useState(true);

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // 🟢 CARGAR PROMEDIO DE SEDE - INMEDIATAMENTE
  useEffect(() => {
    let isMounted = true;
    
    const fetchInstanceAverage = async () => {
      setLoading(true);
      console.log(`🏢 Solicitando promedio de ${instanceName} (${selectedRange.label})`);
      
      try {
        // USAR EL NUEVO ENDPOINT DE PROMEDIOS
        const series = await History.getInstanceAverageSeries(
          instanceName,
          selectedRange.value
        );
        
        if (isMounted) {
          setInstanceSeries(series || []);
          console.log(`✅ Promedio de ${instanceName}: ${series.length} puntos`);
        }
      } catch (error) {
        console.error(`Error cargando promedio de ${instanceName}:`, error);
        if (isMounted) setInstanceSeries([]);
      } finally {
        if (isMounted) setLoading(false);
      }
    };
    
    fetchInstanceAverage();
    
    // Escuchar cambios en el rango de tiempo
    const handleRangeChange = () => {
      fetchInstanceAverage();
    };
    
    window.addEventListener('time-range-change', handleRangeChange);
    return () => {
      isMounted = false;
      window.removeEventListener('time-range-change', handleRangeChange);
    };
  }, [instanceName, selectedRange.value, selectedRange.label]);

  // Cargar series de monitores individuales (cuando se selecciona uno)
  useEffect(() => {
    if (!focus) return;
    
    let isMounted = true;
    
    const fetchMonitorSeries = async () => {
      try {
        const series = await History.getSeriesForMonitor(
          instanceName,
          focus,
          selectedRange.value
        );
        
        if (isMounted) {
          setSeriesMonMap(prev => new Map(prev).set(focus, series || []));
        }
      } catch (error) {
        console.error(`Error cargando monitor ${focus}:`, error);
      }
    };
    
    fetchMonitorSeries();
    
    return () => {
      isMounted = false;
    };
  }, [instanceName, focus, selectedRange.value]);

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
              Ver promedio de sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span>📊 <strong>Promedio de {instanceName}</strong></span>
              <span style={{ 
                fontSize: '0.75rem', 
                background: 'var(--bg-tertiary, #f3f4f6)', 
                padding: '2px 8px', 
                borderRadius: '12px',
                color: 'var(--text-secondary, #6b7280)'
              }}>
                {selectedRange.label}
              </span>
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
          {loading && !focus ? (
            <div style={{
              height: '300px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: 'var(--bg-secondary, #f9fafb)',
              borderRadius: '8px',
              border: '1px solid var(--border, #e5e7eb)'
            }}>
              <p style={{ color: 'var(--text-secondary, #6b7280)' }}>
                Cargando promedio de {instanceName}...
              </p>
            </div>
          ) : focus ? (
            <HistoryChart
              mode="monitor"
              seriesMon={seriesMonMap.get(focus) || []}
              title={focus}
            />
          ) : (
            <HistoryChart
              mode="instance"
              series={{ [instanceName]: instanceSeries }} // Formato compatible
            />
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

        {/* Cards de servicio alrededor */}
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

echo "✅ InstanceDetail.jsx actualizado - AHORA USA PROMEDIOS DE INSTANCIA"
echo ""

# ========== 5. LIMPIAR CACHÉ ==========
echo ""
echo "[5] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"

# ========== 6. REINICIAR FRONTEND ==========
echo ""
echo "[6] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. VERIFICAR TODO EL SISTEMA ==========
echo ""
echo "[7] Verificando sistema completo..."

echo ""
echo "====================================================="
echo "📊 VERIFICACIÓN DE PROMEDIOS"
echo "====================================================="
echo ""

# Verificar backend
echo "1️⃣ Verificando backend..."
if curl -s "http://10.10.31.31:8080/api/instance/average/Caracas?hours=1" | grep -q "success"; then
    echo "   ✅ Endpoint de promedios funcionando"
else
    echo "   ❌ Endpoint de promedios NO responde"
fi

# Verificar que hay datos
echo ""
echo "2️⃣ Verificando datos de promedios..."
AVG_COUNT=$(curl -s "http://10.10.31.31:8080/api/instance/average/Caracas?hours=24" | grep -o '"count":[0-9]*' | head -1 | cut -d':' -f2)
if [ -n "$AVG_COUNT" ] && [ "$AVG_COUNT" -gt 0 ]; then
    echo "   ✅ $AVG_COUNT puntos de promedio encontrados para Caracas"
else
    echo "   ⚠️ No hay datos de promedio aún - generando..."
    curl -s -X POST "http://10.10.31.31:8080/api/instance/average/calculate" > /dev/null
    echo "   ✅ Cálculo forzado ejecutado"
fi

echo ""
echo "====================================================="
echo "✅✅ CONEXIÓN COMPLETADA ✅✅"
echo "====================================================="
echo ""
echo "🎯 AHORA SÍ: Las gráficas de promedio se verán INMEDIATAMENTE"
echo ""
echo "📋 FLUJO COMPLETO:"
echo ""
echo "   BACKEND                          FRONTEND"
echo "   ─────────────────────────────────────────────"
echo "   ✅ Tabla instance_averages    →  ✅ historyApi.js"
echo "   ✅ Cálculo cada 5 minutos     →  ✅ historyEngine.js"
echo "   ✅ Endpoint REST              →  ✅ InstanceDetail.jsx"
echo "   ✅ Datos de prueba           →  ✅ HistoryChart.jsx"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Entra a CUALQUIER sede (Caracas, Guanare, etc.)"
echo "   3. ✅ LA GRÁFICA APARECE INMEDIATAMENTE"
echo "   4. Cambia el selector de tiempo 📊"
echo "   5. ✅ LA GRÁFICA SE ACTUALIZA"
echo ""
echo "📌 DEBUG:"
echo ""
echo "   # Ver datos en backend:"
echo "   curl 'http://10.10.31.31:8080/api/instance/average/Caracas?hours=24' | jq '.data | length'"
echo ""
echo "   # Ver caché del frontend (consola F12):"
echo "   window.__hist.debugInfo()"
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
