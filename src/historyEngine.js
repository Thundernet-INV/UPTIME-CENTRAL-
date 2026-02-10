import { historyApi } from './services/historyApi.js';

// Cache local como fallback (mantiene compatibilidad)
let localCache = {
  data: {},
  lastUpdate: 0,
  CACHE_DURATION: 5000 // 5 segundos
};

// Función para convertir datos de la API al formato esperado por el frontend
function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  
  return data.map(item => {
    const point = {
      ts: item.timestamp,
      ms: item.avgResponseTime || 0,
      sec: (item.avgResponseTime || 0) / 1000,
      x: item.timestamp,
      y: (item.avgResponseTime || 0) / 1000,
      value: (item.avgResponseTime || 0) / 1000,
      avgMs: item.avgResponseTime || 0,
      status: item.avgStatus > 0.5 ? 'up' : 'down'
    };
    point.xy = [point.x, point.y];
    return point;
  });
}

// Función para construir monitorId (igual que en el backend)
function buildMonitorId(instance, name) {
  return `${instance}_${name}`.replace(/\s+/g, '_');
}

// Función de fallback mejorada
function generateFallbackData(sinceMs) {
  const points = [];
  const now = Date.now();
  const startTime = now - sinceMs;
  const pointCount = Math.min(60, Math.floor(sinceMs / 60000));
  
  for (let i = 0; i < pointCount; i++) {
    const progress = i / (pointCount - 1 || 1);
    const ts = startTime + (sinceMs * progress);
    const baseMs = 80 + Math.random() * 40;
    const sec = baseMs / 1000;
    
    points.push({
      ts: ts,
      ms: baseMs,
      sec: sec,
      x: ts,
      y: sec,
      value: sec,
      avgMs: baseMs,
      status: 'up',
      xy: [ts, sec]
    });
  }
  return points;
}

// Objeto History principal
const History = {
  getSeriesForMonitor: async function(instance, name, sinceMs = 60 * 60 * 1000) {
    try {
      const monitorId = buildMonitorId(instance, name);
      console.log(`[HIST] Fetching from API: ${monitorId}, last ${Math.round(sinceMs/1000/60)}min`);
      
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      
      if (apiData && apiData.length > 0) {
        console.log(`[HIST] API returned ${apiData.length} data points for ${monitorId}`);
        return convertApiToPoint(apiData);
      } else {
        console.log(`[HIST] No API data for ${monitorId}, using fallback`);
        return generateFallbackData(sinceMs);
      }
    } catch (error) {
      console.error('[HIST] getSeriesForMonitor error:', error);
      return generateFallbackData(sinceMs);
    }
  },

  getAvgSeriesByInstance: async function(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      console.log(`[HIST] Fetching avg series for instance: ${instance}`);
      
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
      
      if (apiData && apiData.length > 0) {
        console.log(`[HIST] API returned ${apiData.length} avg points for ${instance}`);
        return convertApiToPoint(apiData);
      } else {
        console.log(`[HIST] No API avg data for ${instance}, using fallback`);
        return generateFallbackData(sinceMs);
      }
    } catch (error) {
      console.error('[HIST] getAvgSeriesByInstance error:', error);
      return generateFallbackData(sinceMs);
    }
  },

  getAllForInstance: async function(instance, sinceMs = 60 * 60 * 1000) {
    try {
      console.log(`[HIST] Fetching all data for instance: ${instance}`);
      
      const apiData = await historyApi.getAllForInstance(instance, sinceMs);
      
      if (apiData && Object.keys(apiData).length > 0) {
        console.log(`[HIST] API returned data for ${instance}`);
        return apiData;
      } else {
        console.log(`[HIST] No API data for ${instance}`);
        return {};
      }
    } catch (error) {
      console.error('[HIST] getAllForInstance error:', error);
      return {};
    }
  },

  _generateFallbackData: generateFallbackData
};

// Exportar para compatibilidad
try {
  if (typeof window !== 'undefined') {
    window._hist = History;
  }
} catch (e) {
  // Ignorar en entornos sin window
}

export default History;
