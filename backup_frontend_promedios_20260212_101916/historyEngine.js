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
