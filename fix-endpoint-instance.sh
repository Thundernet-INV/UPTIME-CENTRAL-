#!/bin/bash
# fix-endpoint-instance.sh - CORREGIR ENDPOINT DE INSTANCIA

echo "====================================================="
echo "🔧 CORRIGIENDO ENDPOINT DE INSTANCIA"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_endpoint_instance_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/services/historyApi.js" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/historyEngine.js" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CORREGIR HISTORYAPI.JS ==========
echo "[2] Corrigiendo historyApi.js - ELIMINAR ENDPOINT INEXISTENTE..."

cat > "${FRONTEND_DIR}/src/services/historyApi.js" << 'EOF'
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
EOF

echo "✅ historyApi.js corregido - ENDPOINT INEXISTENTE ELIMINADO"
echo ""

# ========== 3. CORREGIR HISTORYENGINE.JS ==========
echo "[3] Corrigiendo historyEngine.js - USAR ENDPOINTS CORRECTOS..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - VERSIÓN CORREGIDA
import { historyApi } from './services/historyApi.js';

const cache = {
  series: new Map(),
  CACHE_TTL: 30000,
  pending: new Map()
};

function buildMonitorId(instance, name) {
  return `${instance}_${name}`.replace(/\s+/g, '_');
}

function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  
  return data.map(item => {
    const ms = item.avgResponseTime || 0;
    const sec = ms / 1000;
    const ts = item.timestamp;
    
    return {
      ts: ts,
      ms: ms,
      sec: sec,
      x: ts,
      y: sec,
      value: sec,
      avgMs: ms,
      status: item.avgStatus > 0.5 ? 'up' : 'down',
      xy: [ts, sec],
      timestamp: ts,
      responseTime: ms
    };
  });
}

const History = {
  addSnapshot(monitors) {},

  // ✅ Para monitores individuales
  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    if (!instance || !name) return [];
    
    const monitorId = buildMonitorId(instance, name);
    if (!monitorId) return [];
    
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      const points = (apiData && apiData.length > 0) ? convertApiToPoint(apiData) : [];
      
      cache.series.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      return points;
    } catch (error) {
      console.error(`[HIST] Error: ${instance}/${name}`, error);
      return [];
    }
  },

  // ✅ Para promedios de instancia (USA EL MISMO ENDPOINT CON monitorId = "Caracas_avg")
  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    if (!instance) return [];
    
    const cacheKey = `avg:${instance}:${sinceMs}:${bucketMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
      console.log(`[HIST] Solicitando promedio para ${instance}`);
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
      const points = (apiData && apiData.length > 0) ? convertApiToPoint(apiData) : [];
      
      cache.series.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      return points;
    } catch (error) {
      console.error(`[HIST] Error avg: ${instance}`, error);
      return [];
    }
  },

  // ❌ ELIMINADO: getAllForInstance - NO EXISTE EN EL BACKEND
  
  // ✅ NUEVO: Obtener datos de instancia vía summary filtrado
  async getInstanceMonitors(instance) {
    if (!instance) return {};
    
    try {
      const data = await historyApi.getMonitorsByInstance(instance);
      return data;
    } catch (error) {
      console.error(`[HIST] Error obteniendo monitores de ${instance}:`, error);
      return {};
    }
  },

  clearCache() {
    cache.series.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  }
};

export default History;
EOF

echo "✅ historyEngine.js corregido - getAllForInstance ELIMINADO"
echo ""

# ========== 4. CORREGIR INSTANCEDETAIL.JSX ==========
echo "[4] Corrigiendo InstanceDetail.jsx - USAR getInstanceMonitors..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  const [focus, setFocus] = useState(null);
  const [avgSeries, setAvgSeries] = useState([]);
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  // Refresco periódico
  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  // Monitores de la sede actual (desde props)
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // ✅ PROMEDIO DE SEDE - Usa getAvgSeriesByInstance
  useEffect(() => {
    let alive = true;
    
    const fetchAvg = async () => {
      try {
        console.log(`🏢 Cargando promedio de ${instanceName}`);
        const series = await History.getAvgSeriesByInstance(instanceName, 60 * 60 * 1000);
        if (alive) {
          setAvgSeries(series || []);
          console.log(`✅ Promedio de ${instanceName}: ${series.length} puntos`);
        }
      } catch (error) {
        console.error(`Error cargando promedio de ${instanceName}:`, error);
        if (alive) setAvgSeries([]);
      }
    };
    
    fetchAvg();
    
    return () => { alive = false; };
  }, [instanceName, tick]);

  // ✅ MONITORES INDIVIDUALES
  useEffect(() => {
    let alive = true;
    
    const fetchMonitors = async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const series = await History.getSeriesForMonitor(
              instanceName,
              name,
              60 * 60 * 1000
            );
            return [name, series || []];
          })
        );
        
        if (alive) {
          setSeriesMonMap(new Map(entries));
        }
      } catch (error) {
        console.error(`Error cargando monitores de ${instanceName}:`, error);
        if (alive) setSeriesMonMap(new Map());
      }
    };
    
    fetchMonitors();
    
    return () => { alive = false; };
  }, [instanceName, group.length, tick]);

  // Datos para la gráfica
  const chartData = focus 
    ? seriesMonMap.get(focus) || [] 
    : avgSeries;

  return (
    <div className="instance-detail-page">
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
      </div>

      <div className="instance-detail-chip-row">
        {focus ? (
          <div className="k-chip">
            Mostrando: <strong>{focus}</strong>
            <button
              className="k-btn k-btn--ghost k-chip-action"
              onClick={() => setFocus(null)}
            >
              Ver promedio de sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            <span>📊 <strong>Promedio de {instanceName}</strong></span>
          </div>
        )}
      </div>

      <section className="instance-detail-grid">
        <div className="instance-detail-chart">
          <HistoryChart
            mode={focus ? "monitor" : "instance"}
            seriesMon={chartData}
            title={focus || "Promedio de sede"}
          />

          <div className="instance-detail-actions">
            <button
              className="k-btn k-btn--danger"
              onClick={() => onHideAll?.(instanceName)}
            >
              Ocultar todos
            </button>
            <button
              className="k-btn k-btn--ghost"
              onClick={() => onUnhideAll?.(instanceName)}
            >
              Mostrar todos
            </button>
          </div>
        </div>

        {group.map((m, i) => {
          const name = m.info?.monitor_name ?? "";
          const seriesMon = seriesMonMap.get(name) ?? [];
          const isSelected = focus === name;
          
          return (
            <div
              key={name || i}
              className={`instance-detail-service-card ${isSelected ? 'selected' : ''}`}
              onClick={() => setFocus(name)}
              style={{ cursor: 'pointer' }}
            >
              <ServiceCard service={m} series={seriesMon} />
            </div>
          );
        })}
      </section>
    </div>
  );
}
EOF

echo "✅ InstanceDetail.jsx corregido - USA getAvgSeriesByInstance"
echo ""

# ========== 5. LIMPIAR CACHÉ ==========
echo ""
echo "[5] Limpiando caché de Vite..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
echo "✅ Caché limpiada"

# ========== 6. REINICIAR FRONTEND ==========
echo ""
echo "[6] Reiniciando frontend..."

pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. INSTRUCCIONES ==========
echo ""
echo "====================================================="
echo "✅✅ CORRECCIÓN APLICADA ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   • ❌ ELIMINADO: getAllForInstance (no existe en backend)"
echo "   • ✅ USA: getAvgSeriesByInstance para promedios de sede"
echo "   • ✅ USA: getSeriesForMonitor para monitores individuales"
echo "   • ✅ USA: datos en tiempo real de /api/summary"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Entra a una sede (Caracas, Guanare, San Felipe)"
echo "   3. ✅ DEBE mostrar la gráfica de promedio"
echo "   4. ✅ NO debe mostrar error 400"
echo ""
echo "📌 NOTA: El histórico de promedios se cargará desde:"
echo "   http://10.10.31.31:8080/api/history/series?monitorId=Caracas_avg"
echo ""
echo "====================================================="

# Preguntar si quiere abrir el navegador
read -p "¿Abrir el dashboard ahora? (s/N): " OPEN_BROWSER
if [[ "$OPEN_BROWSER" =~ ^[Ss]$ ]]; then
    xdg-open "http://10.10.31.31:5173" 2>/dev/null || \
    open "http://10.10.31.31:5173" 2>/dev/null || \
    echo "Abre http://10.10.31.31:5173 en tu navegador"
fi

echo ""
echo "✅ Script completado"
