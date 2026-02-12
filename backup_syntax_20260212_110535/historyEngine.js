// src/historyEngine.js - VERSIÓN QUE USA DATOS REALES SIEMPRE
import { historyApi } from './services/historyApi.js';

// Cache MÍNIMO - solo 2 segundos para no saturar
const cache = {
  avg: new Map(),
  series: new Map(),
  pending: new Map(),
  AVG_TTL: 2000,
  SERIES_TTL: 2000
};

function buildMonitorId(instance, name) {
  return `${instance}_${name}`.replace(/\s+/g, '_');
}

function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  
  return data.map(item => ({
    ts: item.timestamp,
    ms: item.avgResponseTime || 0,
    sec: (item.avgResponseTime || 0) / 1000,
    x: item.timestamp,
    y: (item.avgResponseTime || 0) / 1000,
    value: (item.avgResponseTime || 0) / 1000,
    avgMs: item.avgResponseTime || 0,
    status: item.avgStatus > 0.5 ? 'up' : 'down'
  }));
}

const History = {
  // ✅ PROMEDIO DE SEDE - USA DATOS REALES DEL BACKEND
  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    if (!instance) return [];
    
    const cacheKey = `avg:${instance}:${sinceMs}`;
    
    // Cache corto para evitar llamadas duplicadas
    const cached = cache.avg.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.AVG_TTL) {
      return cached.data;
    }
    
    try {
      const monitorId = `${instance}_avg`;
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

  // ✅ MONITOR INDIVIDUAL - USA DATOS REALES DEL BACKEND
  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    if (!instance || !name) return [];
    
    const monitorId = buildMonitorId(instance, name);
    if (!monitorId) return [];
    
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.SERIES_TTL) {
      return cached.data;
    }
    
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

// ✅ FUNCIÓN AGREGADA PARA COMPATIBILIDAD
addSnapshot(monitors) {
  // No hace nada, solo para evitar el error
  console.log('[HIST] addSnapshot llamado (compatibilidad)');
  return;
}
