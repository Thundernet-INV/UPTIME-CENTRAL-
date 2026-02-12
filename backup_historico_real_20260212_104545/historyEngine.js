// src/historyEngine.js - VERSIÓN ULTRA RÁPIDA
import { historyApi } from './services/historyApi.js';

// Cache ultra rápido - 2 segundos para promedios, 5 segundos para monitores
const cache = {
  avg: new Map(),
  series: new Map(),
  pending: new Map(),
  AVG_TTL: 2000,     // 2 segundos para promedios
  SERIES_TTL: 5000   // 5 segundos para monitores
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
  addSnapshot(monitors) {},

  // ✅ PROMEDIO DE SEDE - Caché de 2 SEGUNDOS
  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    if (!instance) return [];
    
    const cacheKey = `avg:${instance}:${sinceMs}`;
    
    // Caché ultra rápido
    const cached = cache.avg.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.AVG_TTL) {
      return cached.data;
    }
    
    // Evitar múltiples peticiones simultáneas
    if (cache.pending.has(cacheKey)) {
      return cache.pending.get(cacheKey);
    }
    
    console.log(`[HIST] Cargando promedio de ${instance}...`);
    
    const promise = (async () => {
      try {
        const monitorId = `${instance}_avg`;
        const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, bucketMs);
        const points = (apiData && apiData.length > 0) ? convertApiToPoint(apiData) : [];
        
        // Cache por 2 segundos
        cache.avg.set(cacheKey, {
          data: points,
          timestamp: Date.now()
        });
        
        return points;
      } catch (error) {
        console.error(`[HIST] Error: ${instance}`, error);
        return [];
      } finally {
        cache.pending.delete(cacheKey);
      }
    })();
    
    cache.pending.set(cacheKey, promise);
    return promise;
  },

  // ✅ MONITOR INDIVIDUAL - Caché de 5 SEGUNDOS
  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    if (!instance || !name) return [];
    
    const monitorId = buildMonitorId(instance, name);
    if (!monitorId) return [];
    
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.SERIES_TTL) {
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

  // ✅ CARGA INICIAL RÁPIDA - Sin esperar
  async quickLoadAvg(instance) {
    const cacheKey = `avg:${instance}:quick`;
    const cached = cache.avg.get(cacheKey);
    if (cached) return cached.data;
    
    try {
      const monitorId = `${instance}_avg`;
      const apiData = await historyApi.getSeriesForMonitor(monitorId, 3600000, 60000);
      const points = (apiData && apiData.length > 0) ? convertApiToPoint(apiData) : [];
      
      cache.avg.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      return points;
    } catch (error) {
      return [];
    }
  },

  clearCache() {
    cache.avg.clear();
    cache.series.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  }
};

export default History;
