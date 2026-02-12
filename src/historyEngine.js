// src/historyEngine.js - VERSIÓN SIMPLE
import { historyApi } from './services/historyApi.js';

function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  return data.map(item => ({
    ts: item.timestamp,
    ms: item.avgResponseTime || 0,
    sec: (item.avgResponseTime || 0) / 1000,
    x: item.timestamp,
    y: (item.avgResponseTime || 0) / 1000,
  }));
}

const History = {
  // ✅ PROMEDIO DE SEDE - acepta horas directamente
  async getAvgSeriesByInstance(instance, hours = 1) {
    if (!instance) return [];
    try {
      console.log(`📊 Cargando promedio de ${instance} (${hours}h)`);
      const sinceMs = hours * 60 * 60 * 1000;
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  },

  // ✅ MONITOR INDIVIDUAL - acepta horas directamente
  async getSeriesForMonitor(instance, name, hours = 1) {
    if (!instance || !name) return [];
    try {
      const monitorId = `${instance}_${name}`.replace(/\s+/g, '_');
      console.log(`📊 Cargando ${name} en ${instance} (${hours}h)`);
      const sinceMs = hours * 60 * 60 * 1000;
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  }
};

export default History;
