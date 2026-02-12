#!/bin/bash
# fix-historico-real.sh - USA LOS DATOS REALES DE SQLITE

echo "====================================================="
echo "📊 CORRIGIENDO CONSULTA - USAR DATOS REALES DE SQLITE"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_historico_real_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/services/historyApi.js" "$BACKUP_DIR/"
cp "${FRONTEND_DIR}/src/historyEngine.js" "$BACKUP_DIR/"
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. CORREGIR HISTORYAPI.JS - ENDPOINT CORRECTO ==========
echo "[2] Corrigiendo historyApi.js - CONSULTAR DATOS REALES..."

cat > "${FRONTEND_DIR}/src/services/historyApi.js" << 'EOF'
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
EOF

echo "✅ historyApi.js corregido - CONSULTA DATOS REALES"
echo ""

# ========== 3. CORREGIR HISTORYENGINE.JS - SIN CACHÉ ==========
echo "[3] Corrigiendo historyEngine.js - CONSULTAR SIEMPRE DATOS FRESCOS..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - VERSIÓN QUE USA DATOS REALES SIEMPRE
import { historyApi } from './services/historyApi.js';

// Cache MÍNIMO - solo 2 segundos para no saturar
const cache = {
  avg: new Map(),
  series: new Map(),
  pending: new Map(),
  AVG_TTL: 2000,
  SERIES_TTL: 2000
};

function buildMonitorId(instance, name) {
  return `${instance}_${name}`.replace(/\s+/g, '_');
}

function convertApiToPoint(data) {
  if (!data || !Array.isArray(data)) return [];
  
  return data.map(item => ({
    ts: item.timestamp,
    ms: item.avgResponseTime || 0,
    sec: (item.avgResponseTime || 0) / 1000,
    x: item.timestamp,
    y: (item.avgResponseTime || 0) / 1000,
    value: (item.avgResponseTime || 0) / 1000,
    avgMs: item.avgResponseTime || 0,
    status: item.avgStatus > 0.5 ? 'up' : 'down'
  }));
}

const History = {
  // ✅ PROMEDIO DE SEDE - USA DATOS REALES DEL BACKEND
  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    if (!instance) return [];
    
    const cacheKey = `avg:${instance}:${sinceMs}`;
    
    // Cache corto para evitar llamadas duplicadas
    const cached = cache.avg.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.AVG_TTL) {
      return cached.data;
    }
    
    try {
      const monitorId = `${instance}_avg`;
      console.log(`[HIST] Consultando promedio REAL de ${instance} en BD...`);
      
      const apiData = await historyApi.getAvgSeriesByInstance(instance, sinceMs, bucketMs);
      const points = convertApiToPoint(apiData);
      
      console.log(`[HIST] ✅ Promedio REAL de ${instance}: ${points.length} puntos`);
      
      cache.avg.set(cacheKey, {
        data: points,
        timestamp: Date.now()
      });
      
      return points;
    } catch (error) {
      console.error(`[HIST] Error consultando promedio de ${instance}:`, error);
      return [];
    }
  },

  // ✅ MONITOR INDIVIDUAL - USA DATOS REALES DEL BACKEND
  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    if (!instance || !name) return [];
    
    const monitorId = buildMonitorId(instance, name);
    if (!monitorId) return [];
    
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.SERIES_TTL) {
      return cached.data;
    }
    
    try {
      console.log(`[HIST] Consultando datos REALES de ${instance}/${name}...`);
      
      const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
      const points = convertApiToPoint(apiData);
      
      console.log(`[HIST] ✅ Datos REALES de ${name}: ${points.length} puntos`);
      
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

  clearCache() {
    cache.avg.clear();
    cache.series.clear();
    cache.pending.clear();
    console.log('[HIST] Caché limpiado');
  }
};

export default History;
EOF

echo "✅ historyEngine.js corregido - SIEMPRE USA DATOS REALES"
echo ""

# ========== 4. VERIFICAR QUE EL BACKEND TIENE LOS DATOS ==========
echo ""
echo "[4] Verificando que el backend tiene datos reales..."

echo ""
echo "📊 Verificando datos de Caracas_avg..."
curl -s "http://10.10.31.31:8080/api/history/series?monitorId=Caracas_avg&from=$(($(date +%s%3N)-3600000))&to=$(date +%s%3N)" | head -c 200
echo ""
echo ""

echo "📊 Verificando datos de Guanare_avg..."
curl -s "http://10.10.31.31:8080/api/history/series?monitorId=Guanare_avg&from=$(($(date +%s%3N)-3600000))&to=$(date +%s%3N)" | head -c 200
echo ""
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
echo "✅✅ CONSULTA DE DATOS REALES CORREGIDA ✅✅"
echo "====================================================="
echo ""
echo "📋 CAMBIOS REALIZADOS:"
echo ""
echo "   • ✅ ELIMINADOS todos los datos de ejemplo"
echo "   • ✅ SOLO consulta endpoints reales: /api/history/series"
echo "   • ✅ Monitor individual: monitorId=Instancia_Servicio"
echo "   • ✅ Promedio de sede: monitorId=Instancia_avg"
echo ""
echo "📊 ESTADO DE LA BASE DE DATOS:"
echo ""
echo "   • Caracas_avg: $(curl -s "http://10.10.31.31:8080/api/history/series?monitorId=Caracas_avg&from=$(($(date +%s%3N)-3600000))&to=$(date +%s%3N)" | grep -o '"timestamp":[0-9]*' | wc -l) puntos"
echo "   • Guanare_avg: $(curl -s "http://10.10.31.31:8080/api/history/series?monitorId=Guanare_avg&from=$(($(date +%s%3N)-3600000))&to=$(date +%s%3N)" | grep -o '"timestamp":[0-9]*' | wc -l) puntos"
echo ""
echo "🔄 PRUEBA AHORA:"
echo ""
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Abre la consola (F12)"
echo "   3. Entra a Caracas o Guanare"
echo "   4. ✅ DEBES VER: '[HIST] ✅ Promedio REAL de Caracas: X puntos'"
echo "   5. ✅ LA GRÁFICA DEBE MOSTRAR LOS DATOS REALES"
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
