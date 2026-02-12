// src/services/historyApi.js
// API endpoint - IP fija 10.10.31.31
// CORREGIDO: Formato de monitorId

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  /**
   * Obtener serie de datos para un monitor específico
   * @param {string} monitorId - ID del monitor en formato "instance_name"
   */
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      // VALIDAR que monitorId no esté vacío
      if (!monitorId || monitorId === 'undefined' || monitorId === 'null') {
        console.error('[API] monitorId inválido:', monitorId);
        return [];
      }
      
      const to = Date.now();
      const from = to - sinceMs;
      
      // CONSTRUIR URL CORRECTAMENTE
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] GET ${monitorId} (${Math.round(sinceMs/60000)} min)`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        if (response.status === 400) {
          console.warn(`[API] monitorId no válido para el backend: ${monitorId}`);
          return []; // No es error, es que el monitor no existe en el backend
        }
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  /**
   * Obtener serie promediada por instancia
   * @param {string} instanceName - Nombre de la instancia (sede)
   */
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      if (!instanceName) {
        console.error('[API] instanceName inválido:', instanceName);
        return [];
      }
      
      const to = Date.now();
      const from = to - sinceMs;
      
      // IMPORTANTE: El backend espera "instance_avg" como monitorId
      const monitorId = `${instanceName}_avg`;
      
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] GET avg ${instanceName}`);
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        if (response.status === 400) {
          console.warn(`[API] No hay datos de promedio para: ${instanceName}`);
          return [];
        }
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  /**
   * Obtener todos los datos de una instancia
   * @param {string} instanceName - Nombre de la instancia (sede)
   */
  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      if (!instanceName) {
        console.error('[API] instanceName inválido:', instanceName);
        return {};
      }
      
      const to = Date.now();
      const from = to - sinceMs;
      
      // CORREGIDO: Usar el endpoint correcto para datos de instancia
      // El backend espera /history?instance=Caracas
      const url = `${API_BASE}/history?` +
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`;
      
      console.log(`[API] GET all ${instanceName} (${Math.round(sinceMs/60000)} min)`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        if (response.status === 400) {
          console.warn(`[API] No hay datos para la instancia: ${instanceName}`);
          return {};
        }
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      
      // El backend devuelve { data: { monitor1: [...], monitor2: [...] } }
      return data.data || {};
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  }
};

export default historyApi;
