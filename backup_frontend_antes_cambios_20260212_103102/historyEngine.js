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
