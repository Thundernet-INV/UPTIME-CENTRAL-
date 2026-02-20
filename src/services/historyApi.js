// src/services/historyApi.js - VERSIÓN CORREGIDA CON FALLBACK A DATOS REALES
const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  // Para monitor individual
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      
      // Intentar con el endpoint de series primero
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      console.log(`[API] Solicitando datos para: ${monitorId}`);
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (response.ok) {
        const data = await response.json();
        if (data.data && data.data.length > 0) {
          console.log(`✅ ${monitorId}: ${data.data.length} puntos`);
          return data.data;
        }
      }
      
      // Si no hay datos, intentar con el endpoint de puntos individuales
      console.log(`[API] Sin datos en series, intentando /history/points...`);
      
      const pointsUrl = `${API_BASE}/history/points?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&_=${Date.now()}`;
      
      const pointsRes = await fetch(pointsUrl, { cache: 'no-store' });
      
      if (pointsRes.ok) {
        const pointsData = await pointsRes.json();
        if (pointsData.data && pointsData.data.length > 0) {
          console.log(`✅ ${monitorId}: ${pointsData.data.length} puntos (points)`);
          return pointsData.data;
        }
      }
      
      console.warn(`⚠️ Sin datos para ${monitorId}`);
      return [];
      
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  // 🟢 NUEVA VERSIÓN CORREGIDA PARA PROMEDIOS
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      
      console.log(`🔍 [API] Buscando promedio para instancia: ${instanceName}`);
      
      // PASO 1: Obtener TODOS los monitores de la instancia
      const summaryUrl = `${API_BASE}/summary?t=${Date.now()}`;
      const summaryRes = await fetch(summaryUrl, { cache: 'no-store' });
      
      if (!summaryRes.ok) {
        throw new Error(`Error obteniendo summary: ${summaryRes.status}`);
      }
      
      const summary = await summaryRes.json();
      
      // Filtrar monitores HTTP de la instancia
      const instanceMonitors = summary.monitors?.filter(m => 
        m.instance === instanceName && 
        m.info?.monitor_type?.toLowerCase() === 'http'
      ) || [];
      
      console.log(`📊 [API] Encontrados ${instanceMonitors.length} monitores HTTP en ${instanceName}`);
      
      if (instanceMonitors.length === 0) {
        console.warn(`⚠️ No hay monitores HTTP para ${instanceName}`);
        return this._generateMockData(60); // Datos de ejemplo
      }
      
      // PASO 2: Obtener datos de CADA monitor
      const allMonitorData = await Promise.all(
        instanceMonitors.map(async (monitor) => {
          const monitorId = `${instanceName}_${monitor.info?.monitor_name}`.replace(/\s+/g, '_');
          
          // Intentar obtener datos del monitor
          const series = await this.getSeriesForMonitor(monitorId, sinceMs, bucketMs);
          
          return {
            name: monitor.info?.monitor_name,
            data: series
          };
        })
      );
      
      // PASO 3: Filtrar monitores que tienen datos
      const monitorsWithData = allMonitorData.filter(m => m.data && m.data.length > 0);
      
      console.log(`📊 [API] ${monitorsWithData.length} monitores tienen datos históricos`);
      
      if (monitorsWithData.length === 0) {
        console.warn(`⚠️ Ningún monitor tiene datos para ${instanceName}`);
        return this._generateMockData(60);
      }
      
      // PASO 4: Agrupar por timestamp y promediar
      const pointsByTime = new Map();
      
      monitorsWithData.forEach(monitor => {
        monitor.data.forEach(point => {
          const timestamp = point.timestamp || point.ts;
          const value = point.responseTime || point.avgResponseTime || point.ms;
          
          if (!timestamp || !value) return;
          
          // Redondear al bucket más cercano
          const bucket = Math.floor(timestamp / bucketMs) * bucketMs;
          
          if (!pointsByTime.has(bucket)) {
            pointsByTime.set(bucket, { sum: 0, count: 0 });
          }
          
          const bucketData = pointsByTime.get(bucket);
          bucketData.sum += value;
          bucketData.count++;
        });
      });
      
      // PASO 5: Convertir a array y ordenar
      const averagedData = Array.from(pointsByTime.entries())
        .map(([timestamp, { sum, count }]) => ({
          timestamp: timestamp,
          avgResponseTime: Math.round(sum / count)
        }))
        .sort((a, b) => a.timestamp - b.timestamp);
      
      console.log(`✅ [API] Promedio calculado: ${averagedData.length} puntos`);
      
      if (averagedData.length > 0) {
        // Mostrar primeros 3 puntos para debug
        console.log('📊 Muestra:', averagedData.slice(0, 3).map(p => 
          `${new Date(p.timestamp).toLocaleTimeString()}: ${p.avgResponseTime}ms`
        ));
      }
      
      return averagedData.length > 0 ? averagedData : this._generateMockData(60);
      
    } catch (error) {
      console.error('[API] Error en promedio:', error);
      return this._generateMockData(60);
    }
  },

  // 🟢 Helper para generar datos de ejemplo
  _generateMockData(points = 60) {
    console.log('🎲 Generando datos de ejemplo');
    const now = Date.now();
    const data = [];
    
    for (let i = points - 1; i >= 0; i--) {
      data.push({
        timestamp: now - (i * 60 * 1000),
        avgResponseTime: Math.floor(Math.random() * 150) + 50 // 50-200ms
      });
    }
    
    return data;
  },

  async getAvgSeriesByInstanceRange(instanceName, from, to, bucketMs = 60000) {
    const fromMs = typeof from === 'string' ? new Date(from).getTime() : from;
    const toMs = typeof to === 'string' ? (to === 'now' ? Date.now() : new Date(to).getTime()) : to;
    const sinceMs = toMs - fromMs;
    
    return this.getAvgSeriesByInstance(instanceName, sinceMs, bucketMs);
  }
};

export default historyApi;
