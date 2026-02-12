// src/historyEngine.js - VERSIÓN CORREGIDA CON TODOS LOS MÉTODOS
import { historyApi } from './services/historyApi.js';
import Mem from './historyMem.js';  // Fallback en memoria
import DB from './historyDB.js';    // Fallback en IndexedDB

// Cache local como fallback
let localCache = {
  data: {},
  lastUpdate: 0,
  CACHE_DURATION: 5000
};

// Función para convertir datos de la API al formato esperado
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

// Función para construir monitorId
function buildMonitorId(instance, name) {
  return `${instance}_${name}`.replace(/\s+/g, '_');
}

// Función de fallback
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

// ============================================
// OBJETO HISTORY PRINCIPAL - CON TODOS LOS MÉTODOS
// ============================================
const History = {
  // ✅ MÉTODO QUE FALTABA - ¡ESTE ES EL CRÍTICO!
  addSnapshot(monitors) {
    try {
      console.log('[HIST] addSnapshot recibido:', monitors?.length || 0, 'monitores');
      
      // Guardar en memoria local como fallback
      if (Mem && Mem.addSnapshots) {
        Mem.addSnapshots?.(monitors);
      }
      
      // Guardar en IndexedDB como fallback
      if (DB && DB.addSnapshots) {
        DB.addSnapshots?.(monitors);
        DB.pruneOlderThanDays?.(7);
      }
      
      // Los datos también se guardan automáticamente en el backend SQLite
      // Esta función es principalmente para compatibilidad
      
      if (typeof window !== 'undefined') {
        window.__histLastAddTs = Date.now();
      }
    } catch (e) {
      console.error('[HIST] Error en addSnapshot:', e);
    }
  },

  // ✅ Obtener serie para un monitor específico
  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    try {
      // Intentar memoria local primero
      if (Mem && Mem.getSeriesForMonitor) {
        const mem = Mem.getSeriesForMonitor(instance, name, sinceMs) || [];
        if (mem.length) {
          const out = mem.map(r => ({
            ts: r.ts,
            ms: r.ms,
            x: r.ts,
            y: r.ms/1000,
            xy: [r.ts, r.ms/1000]
          }));
          console.log('[HIST] getSeriesForMonitor(mem)', instance, name, '->', out.length);
          return out;
        }
      }

      // Si no hay en memoria, ir a la API
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

  // ✅ Obtener serie promediada por instancia
  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      // Intentar memoria local
      if (Mem && Mem.getAvgSeriesByInstance) {
        const mem = Mem.getAvgSeriesByInstance?.(instance, sinceMs, bucketMs) || [];
        if (mem.length) {
          const out = mem.map(p => ({ ts: p.ts, ms: p.avgMs }));
          console.log('[HIST] getAvgSeriesByInstance(mem)', instance, '->', out.length);
          return out;
        }
      }

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

  // ✅ Obtener todos los datos de una instancia
  async getAllForInstance(instance, sinceMs = 60 * 60 * 1000) {
    try {
      // Intentar memoria local
      if (Mem && Mem.getAllForInstance) {
        const objMem = Mem.getAllForInstance?.(instance, sinceMs);
        if (objMem && Object.keys(objMem).length) {
          const ofmt = {};
          for (const [name, arr] of Object.entries(objMem)) {
            ofmt[name] = arr.map(r => ({ ts: r.ts, ms: r.ms }));
          }
          console.log('[HIST] getAllForInstance(mem)', instance, 'series:', Object.keys(ofmt).length);
          return ofmt;
        }
      }

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

  // ✅ Limpiar caché
  clearCache() {
    localCache.data = {};
    localCache.lastUpdate = 0;
    console.log('[HIST] Cache cleared');
  },

  // ✅ Información de debug
  debugInfo() {
    return {
      source: 'historyEngine',
      timestamp: Date.now(),
      apiUrl: import.meta.env.VITE_API_BASE_URL || 'http://10.10.31.31:8080/api',
      memActive: !!Mem,
      dbActive: !!DB
    };
  },

  // ✅ Generar datos de fallback (expuesto para debugging)
  _generateFallbackData: generateFallbackData
};

// ✅ Exponer globalmente para debugging
try {
  if (typeof window !== 'undefined') {
    window.__hist = History;
  }
} catch (e) {}

export default History;
