// src/historyEngine.js - VERSIÓN CON DEBUG
import { historyApi } from './services/historyApi.js';

function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  return data.map(item => ({
    ts: item.timestamp || item.ts,
    ms: item.avgResponseTime || item.responseTime || item.ms || 0,
    sec: (item.avgResponseTime || item.responseTime || item.ms || 0) / 1000,
    x: item.timestamp || item.ts,
    y: ((item.avgResponseTime || item.responseTime || item.ms || 0) / 1000),
  }));
}

const History = {
  async getAvgSeriesByInstance(instance, hours = 1) {
    if (!instance) return [];
    try {
      const sinceMs = hours * 60 * 60 * 1000;
      console.log(`📊 [HistoryEngine] Solicitando promedio de ${instance} (${hours}h)`);
      
      const startTime = Date.now();
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, 60000);
      const elapsed = Date.now() - startTime;
      
      console.log(`📊 [HistoryEngine] Respuesta en ${elapsed}ms: ${apiData?.length || 0} puntos`);
      
      const converted = convertApiToPoint(apiData);
      console.log(`📊 [HistoryEngine] Convertidos: ${converted.length} puntos`);
      
      return converted;
    } catch (error) {
      console.error('[HistoryEngine] Error:', error);
      return [];
    }
  },

  async getAvgSeriesByInstanceRange(instance, from, to) {
    if (!instance) return [];
    try {
      const fromMs = typeof from === 'string' ? new Date(from).getTime() : from;
      const toMs = typeof to === 'string' ? (to === 'now' ? Date.now() : new Date(to).getTime()) : to;
      const sinceMs = toMs - fromMs;
      
      console.log(`📊 [HistoryEngine] Solicitando promedio de ${instance} (${new Date(fromMs).toLocaleString()} → ${new Date(toMs).toLocaleString()})`);
      
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
      console.log(`📊 [HistoryEngine] Solicitando ${name} en ${instance} (${hours}h)`);
      
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  },

  async getSeriesForMonitorRange(instance, name, from, to) {
    if (!instance || !name) return [];
    try {
      const monitorId = `${instance}_${name}`.replace(/\s+/g, '_');
      const fromMs = typeof from === 'string' ? new Date(from).getTime() : from;
      const toMs = typeof to === 'string' ? (to === 'now' ? Date.now() : new Date(to).getTime()) : to;
      const sinceMs = toMs - fromMs;
      
      console.log(`📊 [HistoryEngine] Solicitando ${name} en ${instance} (rango absoluto)`);
      
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      return convertApiToPoint(apiData);
    } catch (error) {
      console.error(error);
      return [];
    }
  }
};

export default History;
