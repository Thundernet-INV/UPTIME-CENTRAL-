// src/services/historyApi.js
// VERSIÓN CORREGIDA - SOLO ENDPOINTS QUE EXISTEN

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  // ✅ ENDPOINT QUE SÍ FUNCIONA - Para monitores individuales
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] getSeriesForMonitor: ${monitorId}`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
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

  // ✅ ENDPOINT QUE SÍ FUNCIONA - Para promedios de instancia (monitorId = "Caracas_avg")
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const monitorId = `${instanceName}_avg`;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] getAvgSeriesByInstance: ${instanceName} (como ${monitorId})`);
      
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

  // ❌ ELIMINADO: getAllForInstance - NO EXISTE EN EL BACKEND
  // El backend NO tiene endpoint /api/history?instance=...
  
  // ✅ NUEVO: Obtener todos los monitores de una instancia vía /api/summary
  async getMonitorsByInstance(instanceName) {
    try {
      const url = `${API_BASE}/summary?_=${Date.now()}`;
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      
      const data = await response.json();
      
      // Filtrar monitores por instancia
      const monitors = data.monitors?.filter(m => m.instance === instanceName) || [];
      
      // Agrupar por nombre de monitor
      const result = {};
      monitors.forEach(m => {
        const name = m.info?.monitor_name || 'unknown';
        if (!result[name]) result[name] = [];
        
        // Crear un punto de datos con el timestamp actual
        result[name].push({
          ts: Date.now(),
          ms: m.latest?.responseTime || 0,
          status: m.latest?.status === 1 ? 'up' : 'down'
        });
      });
      
      return result;
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  }
};

export default historyApi;
