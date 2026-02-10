// Servicio para obtener datos históricos del backend
// Compatible con la interfaz original de historyEngine.js
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/api';
export const historyApi = {
  /**
   * Obtener serie de datos para un monitor específico
   * @param {string} monitorId - ID del monitor (formato: instancia_nombre)
   * @param {number} sinceMs - Milisegundos hacia atrás (default: 1 hora)
   * @param {number} bucketMs - Tamaño de bucket en ms (default: 60000 = 1 min)
   * @returns {Promise<Array>} Array de puntos de datos
   */
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const response = await fetch(
        `${API_BASE}/history/series?` + 
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`,
        {
          cache: 'no-store',
        }
      );
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error fetching monitor series:', error);
      return [];
    }
  },
  /**
   * Obtener serie promediada por instancia
   * @param {string} instanceName - Nombre de la instancia
   * @param {number} sinceMs - Milisegundos hacia atrás
   * @param {number} bucketMs - Tamaño de bucket en ms
   * @returns {Promise<Array>} Array de puntos de datos
   */
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      // El backend espera monitorId en formato "instancia_avg"
      const monitorId = `${instanceName}_avg`;
      const response = await fetch(
        `${API_BASE}/history/series?` + 
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`,
        {
          cache: 'no-store',
        }
      );
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error fetching instance avg series:', error);
      return [];
    }
  },
  /**
   * Obtener todos los datos de una instancia (raw)
   * @param {string} instanceName - Nombre de la instancia
   * @param {number} sinceMs - Milisegundos hacia atrás
   * @returns {Promise<Object>} Datos de la instancia
   */
  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      // Primero intentamos obtener datos agregados por instancia
      // Si no funciona, podemos obtener todos los monitores de esa instancia
      const response = await fetch(
        `${API_BASE}/history?` + 
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`,
        {
          cache: 'no-store',
        }
      );
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const data = await response.json();
      return data.data || {};
    } catch (error) {
      console.error('[API] Error fetching instance data:', error);
      return {};
    }
  }
};
export default historyApi;
