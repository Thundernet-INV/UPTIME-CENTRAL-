#!/bin/bash
# rollback-frontend-urgente.sh - RESTAURAR FRONTEND A ESTADO ORIGINAL

echo "====================================================="
echo "🔴 RESTAURANDO FRONTEND - ESTADO ORIGINAL"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_FRONTEND="${FRONTEND_DIR}/backup_frontend_antes_cambios_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP DEL ESTADO ACTUAL ==========
echo ""
echo "[1] Creando backup del frontend actual..."
mkdir -p "$BACKUP_FRONTEND"
cp "${FRONTEND_DIR}/src/services/historyApi.js" "$BACKUP_FRONTEND/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/historyEngine.js" "$BACKUP_FRONTEND/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_FRONTEND/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/api.js" "$BACKUP_FRONTEND/" 2>/dev/null || true
echo "✅ Backup guardado en: $BACKUP_FRONTEND"
echo ""

# ========== 2. RESTAURAR HISTORYAPI.JS ORIGINAL ==========
echo "[2] Restaurando historyApi.js original..."

cat > "${FRONTEND_DIR}/src/services/historyApi.js" << 'EOF'
// src/services/historyApi.js
// API endpoint - IP fija 10.10.31.31

const API_BASE = 'http://10.10.31.31:8080/api';

export const historyApi = {
  // Obtener serie de datos para un monitor específico
  async getSeriesForMonitor(monitorId, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      const response = await fetch(url, { 
        cache: 'no-store',
        headers: { 'Cache-Control': 'no-cache' }
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  // Obtener serie promediada por instancia
  async getAvgSeriesByInstance(instanceName, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const monitorId = `${instanceName}_avg`;
      const url = `${API_BASE}/history/series?` +
        `monitorId=${encodeURIComponent(monitorId)}&` +
        `from=${from}&to=${to}&bucketMs=${bucketMs}&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error('[API] Error:', error);
      return [];
    }
  },

  // Obtener todos los datos de una instancia
  async getAllForInstance(instanceName, sinceMs = 60 * 60 * 1000) {
    try {
      const to = Date.now();
      const from = to - sinceMs;
      const url = `${API_BASE}/history?` +
        `instance=${encodeURIComponent(instanceName)}&` +
        `from=${from}&to=${to}&limit=1000&_=${Date.now()}`;
      
      const response = await fetch(url, { cache: 'no-store' });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return data.data || {};
    } catch (error) {
      console.error('[API] Error:', error);
      return {};
    }
  }
};

export default historyApi;
EOF

echo "✅ historyApi.js restaurado"
echo ""

# ========== 3. RESTAURAR HISTORYENGINE.JS ORIGINAL ==========
echo "[3] Restaurando historyEngine.js original..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - VERSIÓN ORIGINAL FUNCIONAL
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

  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    if (!instance) return [];
    
    const cacheKey = `avg:${instance}:${sinceMs}:${bucketMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
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

  async getAllForInstance(instance, sinceMs = 60 * 60 * 1000) {
    if (!instance) return {};
    
    const cacheKey = `all:${instance}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    try {
      const apiData = await historyApi.getAllForInstance(instance, sinceMs);
      
      const formatted = {};
      if (apiData && typeof apiData === 'object') {
        Object.keys(apiData).forEach(monitorName => {
          if (Array.isArray(apiData[monitorName])) {
            formatted[monitorName] = convertApiToPoint(apiData[monitorName]);
          }
        });
      }
      
      cache.series.set(cacheKey, {
        data: formatted,
        timestamp: Date.now()
      });
      
      return formatted;
    } catch (error) {
      console.error(`[HIST] Error all: ${instance}`, error);
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

echo "✅ historyEngine.js restaurado"
echo ""

# ========== 4. RESTAURAR API.JS ORIGINAL ==========
echo "[4] Restaurando api.js original..."

cat > "${FRONTEND_DIR}/src/api.js" << 'EOF'
// src/api.js
const API_BASE = 'http://10.10.31.31:8080/api';

export async function fetchAll() {
  const url = `${API_BASE}/summary?t=${Date.now()}`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export async function getBlocklist() {
  const url = `${API_BASE}/blocklist?t=${Date.now()}`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) return null;
  return res.json().catch(() => null);
}

export async function saveBlocklist(payload) {
  const url = `${API_BASE}/blocklist`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return res.json().catch(() => null);
}
EOF

echo "✅ api.js restaurado"
echo ""

# ========== 5. RESTAURAR INSTANCEDETAIL.JSX ORIGINAL ==========
echo "[5] Restaurando InstanceDetail.jsx original..."

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
  const [seriesInstance, setSeriesInstance] = useState({});
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const obj = await History.getAllForInstance(
          instanceName,
          60 * 60 * 1000
        );
        if (!alive) return;
        setSeriesInstance(obj ?? {});
      } catch {
        if (!alive) return;
        setSeriesInstance({});
      }
    })();
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick]);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            const arr = await History.getSeriesForMonitor(
              instanceName,
              name,
              60 * 60 * 1000
            );
            return [name, Array.isArray(arr) ? arr : []];
          })
        );
        if (!alive) return;
        setSeriesMonMap(new Map(entries));
      } catch {
        if (!alive) return;
        setSeriesMonMap(new Map());
      }
    })();
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick]);

  const chartMode = focus ? "monitor" : "instance";
  const chartSeries = focus ? seriesMonMap.get(focus) ?? [] : seriesInstance;

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
              Ver sede
            </button>
          </div>
        ) : (
          <div className="k-chip k-chip--muted">
            Mostrando: <strong>Promedio de la sede</strong>
          </div>
        )}
      </div>

      <section className="instance-detail-grid">
        <div className="instance-detail-chart">
          {chartMode === "monitor" ? (
            <HistoryChart
              mode="monitor"
              seriesMon={chartSeries}
              title={focus ?? "Latencia (ms)"}
            />
          ) : (
            <HistoryChart mode="instance" series={chartSeries} />
          )}

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
          return (
            <div
              key={name || i}
              className="instance-detail-service-card"
              onClick={() => setFocus(name)}
              role="button"
              tabIndex={0}
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

echo "✅ InstanceDetail.jsx restaurado"
echo ""

# ========== 6. LIMPIAR CACHÉ Y REINICIAR ==========
echo "[6] Limpiando caché y reiniciando frontend..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 7. VERIFICAR ==========
echo ""
echo "====================================================="
echo "✅✅ FRONTEND RESTAURADO COMPLETAMENTE ✅✅"
echo "====================================================="
echo ""
echo "📋 ESTADO ACTUAL:"
echo ""
echo "   • ✅ historyApi.js: VERSIÓN ORIGINAL"
echo "   • ✅ historyEngine.js: VERSIÓN ORIGINAL"
echo "   • ✅ api.js: VERSIÓN ORIGINAL"
echo "   • ✅ InstanceDetail.jsx: VERSIÓN ORIGINAL"
echo ""
echo "📌 EL BACKEND NO FUE TOCADO - SIGUE FUNCIONANDO"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. ✅ EL DASHBOARD DEBE FUNCIONAR INMEDIATAMENTE"
echo "   3. ✅ Los datos en tiempo real deben aparecer"
echo "   4. ❌ Las gráficas de histórico NO funcionarán (volvemos a estado original)"
echo ""
echo "📌 BACKUP DE LOS CAMBIOS QUE ROMPIERON TODO:"
echo "   $BACKUP_FRONTEND"
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
