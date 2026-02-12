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
