// src/historyEngine.js - VERSIÓN CORREGIDA
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
  // ✅ FUNCIÓN AGREGADA CORRECTAMENTE
  addSnapshot(monitors) {
    console.log('[HIST] addSnapshot llamado (compatibilidad)');
    return;
  },

  // ✅ PROMEDIO DE SEDE
  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    if (!instance) return [];
    
    const cacheKey = `avg:${instance}:${sinceMs}`;
    
    const cached = cache.avg.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.AVG_TTL) {
      return cached.data;
    }
    
    try {
      console.log(`[HIST] Consultando promedio REAL de ${instance} en BD...`);
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
      const points = convertApiToPoint(apiData);
      
      console.log(`[HIST] ✅ Promedio REAL de ${instance}: ${points.length} puntos`);
      
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

  // ✅ MONITOR INDIVIDUAL
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
        console.log(`[HIST] Consultando datos REALES de ${instance}/${name}...`);
        const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
        const points = convertApiToPoint(apiData);
        
        console.log(`[HIST] ✅ Datos REALES de ${name}: ${points.length} puntos`);
        
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

  // ✅ FUNCIONES DE COMPATIBILIDAD
  async getAllForInstance(instance, sinceMs = 60 * 60 * 1000) {
    console.log(`[HIST] getAllForInstance llamado - usando getAvgSeriesByInstance`);
    return await this.getAvgSeriesByInstance(instance, sinceMs);
  },

  clearCache() {
    cache.series.clear();
    cache.avg.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  }
};

export default History;
