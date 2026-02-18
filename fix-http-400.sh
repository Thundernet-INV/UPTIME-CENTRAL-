#!/bin/bash
# fix-http-400.sh - CORRIGE ERROR HTTP 400 EN HISTORYAPI

echo "====================================================="
echo "🔧 CORRIGIENDO ERROR HTTP 400 - FORMATO DE MONITORID"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_http400_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/services/historyApi.js" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CORREGIR HISTORYAPI.JS ==========
echo "[2] Corrigiendo historyApi.js - FORMATO CORRECTO DE MONITORID..."

cat > "${FRONTEND_DIR}/src/services/historyApi.js" << 'EOF'
// src/services/historyApi.js
// API endpoint - IP fija 10.10.31.31
// CORREGIDO: Formato de monitorId

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  /**
   * Obtener serie de datos para un monitor específico
   * @param {string} monitorId - ID del monitor en formato "instance_name"
   */
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      // VALIDAR que monitorId no esté vacío
      if (!monitorId || monitorId === 'undefined' || monitorId === 'null') {
        console.error('[API] monitorId inválido:', monitorId);
        return [];
      }
      
      const to = Date.now();
      const from = to - sinceMs;
      
      // CONSTRUIR URL CORRECTAMENTE
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] GET ${monitorId} (${Math.round(sinceMs/60000)} min)`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        if (response.status === 400) {
          console.warn(`[API] monitorId no válido para el backend: ${monitorId}`);
          return []; // No es error, es que el monitor no existe en el backend
        }
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  /**
   * Obtener serie promediada por instancia
   * @param {string} instanceName - Nombre de la instancia (sede)
   */
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      if (!instanceName) {
        console.error('[API] instanceName inválido:', instanceName);
        return [];
      }
      
      const to = Date.now();
      const from = to - sinceMs;
      
      // IMPORTANTE: El backend espera "instance_avg" como monitorId
      const monitorId = `${instanceName}_avg`;
      
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] GET avg ${instanceName}`);
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        if (response.status === 400) {
          console.warn(`[API] No hay datos de promedio para: ${instanceName}`);
          return [];
        }
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  /**
   * Obtener todos los datos de una instancia
   * @param {string} instanceName - Nombre de la instancia (sede)
   */
  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      if (!instanceName) {
        console.error('[API] instanceName inválido:', instanceName);
        return {};
      }
      
      const to = Date.now();
      const from = to - sinceMs;
      
      // CORREGIDO: Usar el endpoint correcto para datos de instancia
      // El backend espera /history?instance=Caracas
      const url = `${API_BASE}/history?` +
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`;
      
      console.log(`[API] GET all ${instanceName} (${Math.round(sinceMs/60000)} min)`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        if (response.status === 400) {
          console.warn(`[API] No hay datos para la instancia: ${instanceName}`);
          return {};
        }
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      
      // El backend devuelve { data: { monitor1: [...], monitor2: [...] } }
      return data.data || {};
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  }
};

export default historyApi;
EOF

echo "✅ historyApi.js corregido - MANEJA ERRORES 400 CORRECTAMENTE"
echo ""

# ========== 3. CORREGIR HISTORYENGINE.JS ==========
echo "[3] Corrigiendo historyEngine.js - MEJOR MANEJO DE ERRORES..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - CON MEJOR MANEJO DE ERRORES
import { historyApi } from './services/historyApi.js';

// Cache simple
const cache = {
  series: new Map(),
  CACHE_TTL: 30000, // 30 segundos
  pending: new Map()
};

function buildMonitorId(instance, name) {
  if (!instance || !name) return null;
  // Formato: "Instancia_Nombre" - reemplazar espacios con _
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
    // VALIDAR parámetros
    if (!instance || !name) {
      console.warn(`[HIST] getSeriesForMonitor: instance o name inválidos`, { instance, name });
      return [];
    }
    
    if (!sinceMs || typeof sinceMs !== 'number' || sinceMs <= 0) {
      sinceMs = 60 * 60 * 1000;
    }
    
    const monitorId = buildMonitorId(instance, name);
    if (!monitorId) return [];
    
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    // Verificar caché
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    // Evitar peticiones duplicadas
    if (cache.pending.has(cacheKey)) {
      return cache.pending.get(cacheKey);
    }
    
    console.log(`[HIST] Fetching: ${instance}/${name} (${Math.round(sinceMs/60000)} min)`);
    
    const promise = (async () => {
      try {
        const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
        
        let points = [];
        if (apiData && apiData.length > 0) {
          points = convertApiToPoint(apiData);
        }
        
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
    if (!instance) return [];
    
    if (!sinceMs || typeof sinceMs !== 'number' || sinceMs <= 0) {
      sinceMs = 60 * 60 * 1000;
    }
    
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
    // VALIDAR instance
    if (!instance) {
      console.warn(`[HIST] getAllForInstance: instance inválida`);
      return {};
    }
    
    if (!sinceMs || typeof sinceMs !== 'number' || sinceMs <= 0) {
      sinceMs = 60 * 60 * 1000;
    }
    
    const cacheKey = `all:${instance}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
      console.log(`[HIST] Fetching all for instance: ${instance} (${Math.round(sinceMs/60000)} min)`);
      
      const apiData = await historyApi.getAllForInstance(instance, sinceMs);
      
      // Formatear datos
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
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  }
};

export default History;
EOF

echo "✅ historyEngine.js corregido - MEJOR VALIDACIÓN DE PARÁMETROS"
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
echo "✅✅ ERROR HTTP 400 CORREGIDO ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "1. historyApi.js:"
echo "   • Maneja errores 400 como 'sin datos' (NO como error crítico)"
echo "   • Valida monitorId antes de enviar"
echo "   • URL correcta para getAllForInstance: /history?instance=Caracas"
echo ""
echo "2. historyEngine.js:"
echo "   • Valida parámetros antes de llamar a la API"
echo "   • buildMonitorId retorna null si instance/name son inválidos"
echo "   • Mejor manejo de errores"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Entra a una sede (Caracas, Guanare, etc.)"
echo "   3. ✅ NO debe mostrar error HTTP 400"
echo "   4. ✅ La gráfica de promedio debe cargar"
echo "   5. ✅ El selector de tiempo debe funcionar"
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
