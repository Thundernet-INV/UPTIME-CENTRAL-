// src/services/historyApi.js
// API endpoint - VERSIÓN COMPLETA CON PROMEDIOS DE INSTANCIA

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  // ========== ENDPOINTS EXISTENTES ==========
  
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      if (!monitorId) return [];
      
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
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

  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      if (!instanceName) return [];
      
      const to = Date.now();
      const from = to - sinceMs;
      const monitorId = `${instanceName}_avg`;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
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

  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      if (!instanceName) return {};
      
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history?` +
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        if (response.status === 400) return {};
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || {};
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  },

  // ========== 🟢 NUEVO: ENDPOINT DE PROMEDIOS POR INSTANCIA ==========
  
  /**
   * Obtener serie de promedios para una instancia (sede)
   * @param {string} instanceName - Nombre de la sede (Caracas, Guanare, etc.)
   * @param {number} hours - Horas hacia atrás (default: 24)
   * @returns {Promise<Array>} Array de puntos con timestamp y avgResponseTime
   */
  async getInstanceAverageSeries(instanceName, hours = 24) {
    try {
      if (!instanceName) return [];
      
      const url = `${API_BASE}/instance/average/${encodeURIComponent(instanceName)}?hours=${hours}&_=${Date.now()}`;
      
      console.log(`[API] Solicitando promedios para ${instanceName} (últimas ${hours}h)`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        console.warn(`[API] No hay promedios para ${instanceName}`);
        return [];
      }
      
      const result = await response.json();
      
      if (!result.success) {
        console.warn(`[API] Error en respuesta:`, result.error);
        return [];
      }
      
      console.log(`[API] ✅ Recibidos ${result.data.length} puntos de promedio para ${instanceName}`);
      return result.data || [];
    } catch (error) {
      console.error(`[API] Error obteniendo promedios para ${instanceName}:`, error);
      return [];
    }
  },

  /**
   * Obtener el último promedio de una instancia
   * @param {string} instanceName - Nombre de la sede
   * @returns {Promise<Object|null>} Último promedio o null
   */
  async getLatestInstanceAverage(instanceName) {
    try {
      if (!instanceName) return null;
      
      const url = `${API_BASE}/instance/average/${encodeURIComponent(instanceName)}/latest?_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) return null;
      
      const result = await response.json();
      return result.success ? result.data : null;
    } catch (error) {
      console.error(`[API] Error obteniendo último promedio para ${instanceName}:`, error);
      return null;
    }
  },

  // ========== ENDPOINTS DE MANTENIMIENTO ==========
  
  async getAvailableMonitors() {
    try {
      const url = `${API_BASE}/metric-history/monitors?_=${Date.now()}`;
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) return [];
      
      const data = await response.json();
      return data.success ? data.monitors : [];
    } catch (error) {
      console.error('[API] Error fetching monitors:', error);
      return [];
    }
  },

  async getStats() {
    try {
      const url = `${API_BASE}/metric-history/stats?_=${Date.now()}`;
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) return null;
      
      const data = await response.json();
      return data;
    } catch (error) {
      console.error('[API] Error fetching stats:', error);
      return null;
    }
  }
};

export default historyApi;
