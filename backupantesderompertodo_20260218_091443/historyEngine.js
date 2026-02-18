// src/historyEngine.js - CON SOPORTE PARA TIMESTAMPS
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
  // ✅ VERSIÓN ORIGINAL (para rangos relativos)
  async getAvgSeriesByInstance(instance, hours = 1) {
    if (!instance) return [];
    try {
      const sinceMs = hours * 60 * 60 * 1000;
      console.log(`📊 Cargando promedio de ${instance} (${hours}h)`);
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  },

  // ✅ VERSIÓN CON TIMESTAMPS (para rango absoluto)
  async getAvgSeriesByInstanceRange(instance, from, to) {
    if (!instance) return [];
    try {
      const fromMs = typeof from === 'string' ? new Date(from).getTime() : from;
      const toMs = typeof to === 'string' ? (to === 'now' ? Date.now() : new Date(to).getTime()) : to;
      const sinceMs = toMs - fromMs;
      
      console.log(`📊 Cargando promedio de ${instance} (${new Date(fromMs).toLocaleString()} → ${new Date(toMs).toLocaleString()})`);
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  },

  async getSeriesForMonitor(instance, name, hours = 1) {
    if (!instance || !name) return [];
    try {
      const monitorId = `${instance}_${name}`.replace(/\s+/g, '_');
      const sinceMs = hours * 60 * 60 * 1000;
      console.log(`📊 Cargando ${name} en ${instance} (${hours}h)`);
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  },

  // ✅ VERSIÓN CON TIMESTAMPS PARA MONITORES
  async getSeriesForMonitorRange(instance, name, from, to) {
    if (!instance || !name) return [];
    try {
      const monitorId = `${instance}_${name}`.replace(/\s+/g, '_');
      const fromMs = typeof from === 'string' ? new Date(from).getTime() : from;
      const toMs = typeof to === 'string' ? (to === 'now' ? Date.now() : new Date(to).getTime()) : to;
      const sinceMs = toMs - fromMs;
      
      console.log(`📊 Cargando ${name} en ${instance} (${new Date(fromMs).toLocaleString()} → ${new Date(toMs).toLocaleString()})`);
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  }
};

export default History;
