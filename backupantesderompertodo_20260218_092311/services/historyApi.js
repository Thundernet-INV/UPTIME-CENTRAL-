// src/services/historyApi.js
// VERSIÓN CORREGIDA - USA LOS ENDPOINTS QUE TIENEN DATOS REALES

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  // ✅ ENDPOINT CORRECTO PARA MONITORES INDIVIDUALES - TIENE DATOS
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] Solicitando datos reales para: ${monitorId}`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        console.warn(`[API] Sin datos para ${monitorId}`);
        return [];
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  // ✅ ENDPOINT CORRECTO PARA PROMEDIOS DE INSTANCIA - TIENE DATOS
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const monitorId = `${instanceName}_avg`;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] Solicitando promedio real de: ${instanceName}`);
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        console.warn(`[API] Sin datos de promedio para ${instanceName}`);
        return [];
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  }
};

export default historyApi;
