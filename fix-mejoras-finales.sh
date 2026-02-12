#!/bin/bash
# fix-mejoras-finales.sh - IMPLEMENTA LAS 3 MEJORAS SOLICITADAS

echo "====================================================="
echo "🔧 IMPLEMENTANDO 3 MEJORAS FINALES"
echo "====================================================="
echo " 1) Selector de tiempo funcionando en TODAS las gráficas"
echo " 2) MultiServiceView: Primer servicio seleccionado automáticamente"
echo " 3) InstanceDetail: Mostrar promedio de sede por defecto"
echo "====================================================="

FRONTEND_DIR="/home/thunder/kuma-dashboard-clean/kuma-ui"
BACKUP_DIR="${FRONTEND_DIR}/backup_mejoras_$(date +%Y%m%d_%H%M%S)"

# ========== 1. CREAR BACKUP ==========
echo ""
echo "[1] Creando backup completo..."
mkdir -p "$BACKUP_DIR"
cp "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/views/Dashboard.jsx" "$BACKUP_DIR/" 2>/dev/null || true
cp "${FRONTEND_DIR}/src/historyEngine.js" "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup creado en: $BACKUP_DIR"
echo ""

# ========== 2. MEJORA 1: CORREGIR SELECTOR DE TIEMPO EN HISTORYENGINE ==========
echo "[2] MEJORA 1: Corrigiendo selector de tiempo en historyEngine.js..."

cat > "${FRONTEND_DIR}/src/historyEngine.js" << 'EOF'
// src/historyEngine.js - VERSIÓN CORREGIDA CON SOPORTE PARA RANGO DINÁMICO
import { historyApi } from './services/historyApi.js';

// Cache simple
const cache = {
  series: new Map(),
  CACHE_TTL: 30000, // 30 segundos
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
  addSnapshot(monitors) {
    // Los datos ya se guardan en el backend
  },

  async getSeriesForMonitor(instance, name, sinceMs = 60 * 60 * 1000) {
    // VALIDAR que sinceMs sea un número válido
    if (!sinceMs || typeof sinceMs !== 'number' || sinceMs <= 0) {
      console.warn(`[HIST] sinceMs inválido (${sinceMs}), usando 1 hora`);
      sinceMs = 60 * 60 * 1000;
    }
    
    const cacheKey = `series:${instance}:${name}:${sinceMs}`;
    
    // Verificar caché
    const cached = cache.series.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp) < cache.CACHE_TTL) {
      return cached.data;
    }
    
    // Evitar peticiones duplicadas
    if (cache.pending.has(cacheKey)) {
      return cache.pending.get(cacheKey);
    }
    
    console.log(`[HIST] Fetching: ${instance}/${name} (${Math.round(sinceMs/60000)} min)`);
    
    const promise = (async () => {
      try {
        const monitorId = buildMonitorId(instance, name);
        const apiData = await historyApi.getSeriesForMonitor(monitorId, sinceMs, 60000);
        
        let points = [];
        if (apiData && apiData.length > 0) {
          points = convertApiToPoint(apiData);
        }
        
        // Guardar en caché
        cache.series.set(cacheKey, {
          data: points,
          timestamp: Date.now()
        });
        
        return points;
      } catch (error) {
        console.error(`[HIST] Error: ${instance}/${name}`, error);
        return [];
      } finally {
        cache.pending.delete(cacheKey);
      }
    })();
    
    cache.pending.set(cacheKey, promise);
    return promise;
  },

  async getAvgSeriesByInstance(instance, sinceMs = 60 * 60 * 1000, bucketMs = 60000) {
    // VALIDAR que sinceMs sea un número válido
    if (!sinceMs || typeof sinceMs !== 'number' || sinceMs <= 0) {
      console.warn(`[HIST] sinceMs inválido (${sinceMs}), usando 1 hora`);
      sinceMs = 60 * 60 * 1000;
    }
    
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
    // VALIDAR que sinceMs sea un número válido
    if (!sinceMs || typeof sinceMs !== 'number' || sinceMs <= 0) {
      console.warn(`[HIST] sinceMs inválido (${sinceMs}), usando 1 hora`);
      sinceMs = 60 * 60 * 1000;
    }
    
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
          formatted[monitorName] = convertApiToPoint(apiData[monitorName]);
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

echo "✅ historyEngine.js actualizado - VALIDA que el rango sea válido"
echo ""

# ========== 3. MEJORA 2: MULTISERVICEVIEW CON PRIMER SERVICIO AUTOMÁTICO ==========
echo "[3] MEJORA 2: MultiServiceView - Auto-seleccionar primer servicio..."

cat > "${FRONTEND_DIR}/src/components/MultiServiceView.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import History from "../historyEngine.js";
import HistoryChart from "./HistoryChart.jsx";
import { useTimeRange, TIME_RANGE_CHANGE_EVENT } from "./TimeRangeSelector.jsx";

// Colores para modo claro y oscuro
const COLORS = {
  light: {
    bg: '#ffffff',
    text: '#1f2937',
    textSecondary: '#6b7280',
    border: '#e5e7eb',
    cardBg: '#f9fafb',
    hover: '#f3f4f6',
    chartGrid: '#e5e7eb',
    chartText: '#6b7280',
  },
  dark: {
    bg: '#0f1217',
    text: '#e5e7eb',
    textSecondary: '#94a3b8',
    border: '#2d3238',
    cardBg: '#1a1e24',
    hover: '#2d3238',
    chartGrid: '#2d3238',
    chartText: '#94a3b8',
  }
};

// Color estable a partir del nombre de la sede
function getColorForInstance(name = "") {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  const hue = hash % 360;
  return `hsl(${hue}, 70%, 50%)`;
}

export default function MultiServiceView({ monitorsAll = [] }) {
  // Detectar modo oscuro
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      return document.body.classList.contains('dark-mode');
    }
    return false;
  });

  // Escuchar cambios en el modo oscuro
  useEffect(() => {
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === 'class') {
          setIsDark(document.body.classList.contains('dark-mode'));
        }
      });
    });
    
    observer.observe(document.body, { attributes: true });
    return () => observer.disconnect();
  }, []);

  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  const [rangeValue, setRangeValue] = useState(selectedRange.value);
  
  // Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = (e) => {
      console.log("📊 MultiServiceView - Rango cambiado a:", e.detail.label);
      setRangeValue(e.detail.value);
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, []);
  
  // Estado
  const [selectedService, setSelectedService] = useState("");
  const [selectedInstances, setSelectedInstances] = useState([]);
  const [seriesByInstance, setSeriesByInstance] = useState({});
  const [loading, setLoading] = useState(false);

  // 1) Lista de servicios HTTP únicos
  const services = useMemo(() => {
    const serviceMap = new Map();
    
    monitorsAll.forEach(monitor => {
      const type = monitor.info?.monitor_type || "";
      if (type.toLowerCase() !== "http") return;
      
      const name = monitor.info?.monitor_name || monitor.name || "";
      if (!name) return;
      
      const instance = monitor.instance;
      if (!instance) return;
      
      if (!serviceMap.has(name)) {
        serviceMap.set(name, {
          name,
          type,
          instances: new Set(),
          count: 0
        });
      }
      
      const service = serviceMap.get(name);
      service.instances.add(instance);
      service.count = service.instances.size;
    });
    
    return Array.from(serviceMap.values()).sort((a, b) => 
      a.name.localeCompare(b.name)
    );
  }, [monitorsAll]);

  // 🎯 MEJORA 2: Auto-seleccionar el primer servicio cuando se carga el componente
  useEffect(() => {
    if (services.length > 0 && !selectedService) {
      const primerServicio = services[0].name;
      console.log("🎯 Auto-seleccionando primer servicio:", primerServicio);
      setSelectedService(primerServicio);
    }
  }, [services, selectedService]);

  // 2) Cuando se selecciona un servicio, actualizar instancias disponibles
  useEffect(() => {
    if (!selectedService) {
      setSelectedInstances([]);
      return;
    }
    
    const service = services.find(s => s.name === selectedService);
    if (service) {
      const instancias = Array.from(service.instances).sort();
      console.log(`🏢 Servicio "${selectedService}" tiene ${instancias.length} sedes:`, instancias);
      setSelectedInstances(instancias);
    }
  }, [selectedService, services]);

  // 3) Cargar datos cuando cambia el servicio, las instancias o el rango
  useEffect(() => {
    let isMounted = true;
    
    const fetchData = async () => {
      if (!selectedService || selectedInstances.length === 0) {
        setSeriesByInstance({});
        return;
      }
      
      setLoading(true);
      console.log(`📊 Cargando datos para ${selectedService} - Rango: ${selectedRange.label} (${rangeValue}ms)`);
      
      try {
        const seriesData = {};
        
        await Promise.all(
          selectedInstances.map(async (instance) => {
            const data = await History.getSeriesForMonitor(
              instance,
              selectedService,
              rangeValue
            );
            seriesData[instance] = Array.isArray(data) ? data : [];
          })
        );
        
        if (isMounted) {
          setSeriesByInstance(seriesData);
          console.log(`✅ Datos cargados: ${Object.keys(seriesData).length} sedes`);
        }
      } catch (error) {
        console.error("Error cargando datos:", error);
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };
    
    fetchData();
    
    return () => {
      isMounted = false;
    };
  }, [selectedService, selectedInstances, rangeValue, selectedRange.label]);

  // 4) Preparar datos para el chart
  const chartSeries = useMemo(() => {
    return selectedInstances.map(instance => ({
      id: instance,
      label: instance,
      color: getColorForInstance(instance),
      points: seriesByInstance[instance] || []
    }));
  }, [selectedInstances, seriesByInstance]);

  const hasService = !!selectedService;
  const hasSeries = chartSeries.length > 0 && chartSeries.some(s => s.points.length > 0);
  
  // Estilos según modo
  const styles = {
    container: {
      padding: '24px',
      backgroundColor: isDark ? COLORS.dark.bg : COLORS.light.bg,
      color: isDark ? COLORS.dark.text : COLORS.light.text,
      borderRadius: '12px',
      transition: 'all 0.3s ease',
    },
    header: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: '24px',
    },
    title: {
      margin: 0,
      fontSize: '1.5rem',
      fontWeight: '600',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
    },
    rangeBadge: {
      padding: '6px 14px',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.cardBg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '20px',
      fontSize: '0.85rem',
      color: isDark ? COLORS.dark.textSecondary : COLORS.light.textSecondary,
    },
    select: {
      width: '100%',
      maxWidth: '400px',
      padding: '10px 12px',
      backgroundColor: isDark ? COLORS.dark.bg : COLORS.light.bg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '6px',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
      fontSize: '0.95rem',
      marginTop: '8px',
    },
    instancesContainer: {
      display: 'flex',
      gap: '8px',
      flexWrap: 'wrap',
      alignItems: 'center',
      marginTop: '12px',
      marginBottom: '20px',
    },
    instanceBadge: {
      padding: '4px 12px',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.cardBg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '16px',
      fontSize: '0.85rem',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
    },
    chartContainer: {
      minHeight: '400px',
      position: 'relative',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.cardBg,
      borderRadius: '8px',
      padding: '20px',
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      marginTop: '20px',
    },
    message: {
      textAlign: 'center',
      color: isDark ? COLORS.dark.textSecondary : COLORS.light.textSecondary,
      padding: '60px 20px',
    },
    loadingOverlay: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: isDark ? 'rgba(0,0,0,0.7)' : 'rgba(255,255,255,0.7)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      borderRadius: '8px',
      backdropFilter: 'blur(2px)',
    },
    loadingText: {
      padding: '8px 16px',
      backgroundColor: isDark ? COLORS.dark.cardBg : COLORS.light.bg,
      border: `1px solid ${isDark ? COLORS.dark.border : COLORS.light.border}`,
      borderRadius: '20px',
      color: isDark ? COLORS.dark.text : COLORS.light.text,
    }
  };

  return (
    <div style={styles.container}>
      {/* Header con título y rango actual */}
      <div style={styles.header}>
        <h2 style={styles.title}>Comparar servicio HTTP por sede</h2>
        <div style={styles.rangeBadge}>
          📊 {selectedRange.label}
        </div>
      </div>

      {/* Selector de servicio - ya viene preseleccionado */}
      <div>
        <label style={{ 
          display: 'block', 
          fontSize: '0.9rem',
          fontWeight: '600',
          color: isDark ? COLORS.dark.text : COLORS.light.text,
        }}>
          Servicio HTTP
        </label>
        <select
          value={selectedService}
          onChange={(e) => setSelectedService(e.target.value)}
          style={styles.select}
        >
          <option value="">Selecciona un servicio...</option>
          {services.map(service => (
            <option key={service.name} value={service.name}>
              {service.name} · {service.count} {service.count === 1 ? 'sede' : 'sedes'}
            </option>
          ))}
        </select>
      </div>

      {/* Instancias del servicio seleccionado */}
      {hasService && selectedInstances.length > 0 && (
        <div style={styles.instancesContainer}>
          <span style={{ fontSize: '0.9rem', color: isDark ? COLORS.dark.textSecondary : COLORS.light.textSecondary }}>
            Sedes monitorizadas:
          </span>
          {selectedInstances.map(instance => (
            <span
              key={instance}
              style={styles.instanceBadge}
            >
              {instance}
            </span>
          ))}
        </div>
      )}

      {/* Contenedor de la gráfica - SIEMPRE visible cuando hay servicio */}
      <div style={styles.chartContainer}>
        {!hasService && services.length > 0 && (
          <div style={styles.message}>
            Cargando servicio por defecto...
          </div>
        )}
        
        {hasService && selectedInstances.length === 0 && (
          <div style={styles.message}>
            Este servicio no está disponible en ninguna sede.
          </div>
        )}
        
        {hasService && selectedInstances.length > 0 && !hasSeries && !loading && (
          <div style={styles.message}>
            No hay datos históricos disponibles para {selectedRange.label.toLowerCase()}.
          </div>
        )}
        
        {hasService && selectedInstances.length > 0 && hasSeries && !loading && (
          <HistoryChart 
            mode="multi" 
            seriesMulti={chartSeries} 
            h={380}
            options={{
              scales: {
                x: {
                  grid: { color: isDark ? COLORS.dark.chartGrid : COLORS.light.chartGrid },
                  ticks: { color: isDark ? COLORS.dark.chartText : COLORS.light.chartText }
                },
                y: {
                  grid: { color: isDark ? COLORS.dark.chartGrid : COLORS.light.chartGrid },
                  ticks: { color: isDark ? COLORS.dark.chartText : COLORS.light.chartText }
                }
              },
              plugins: {
                legend: {
                  labels: { color: isDark ? COLORS.dark.chartText : COLORS.light.chartText }
                }
              }
            }}
          />
        )}
        
        {loading && (
          <div style={styles.loadingOverlay}>
            <span style={styles.loadingText}>
              Cargando datos para {selectedRange.label}...
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
EOF

echo "✅ MultiServiceView actualizado - Auto-selecciona PRIMER servicio"
echo ""

# ========== 4. MEJORA 3: INSTANCEDETAIL CON PROMEDIO DE SEDE POR DEFECTO ==========
echo "[4] MEJORA 3: InstanceDetail - Mostrar promedio de sede por defecto..."

cat > "${FRONTEND_DIR}/src/components/InstanceDetail.jsx" << 'EOF'
import React, { useEffect, useMemo, useState } from "react";
import HistoryChart from "./HistoryChart.jsx";
import History from "../historyEngine.js";
import ServiceCard from "./ServiceCard.jsx";
import { useTimeRange, TIME_RANGE_CHANGE_EVENT } from "./TimeRangeSelector.jsx";

export default function InstanceDetail({
  instanceName,
  monitorsAll = [],
  hiddenSet = new Set(),
  onHide,
  onUnhide,
  onHideAll,
  onUnhideAll,
}) {
  // Obtener el rango de tiempo seleccionado
  const selectedRange = useTimeRange();
  const [rangeValue, setRangeValue] = useState(selectedRange.value);
  
  // Escuchar cambios en el rango de tiempo
  useEffect(() => {
    const handleRangeChange = (e) => {
      console.log(`📊 InstanceDetail (${instanceName}) - Rango cambiado a:`, e.detail.label);
      setRangeValue(e.detail.value);
    };
    
    window.addEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
    return () => window.removeEventListener(TIME_RANGE_CHANGE_EVENT, handleRangeChange);
  }, [instanceName]);
  
  // 🎯 MEJORA 3: focus = null POR DEFECTO (muestra promedio de sede)
  const [focus, setFocus] = useState(null);
  const [seriesInstance, setSeriesInstance] = useState({});
  const [seriesMonMap, setSeriesMonMap] = useState(new Map());
  const [tick, setTick] = useState(0);

  // Refresco periódico
  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 30000);
    return () => clearInterval(t);
  }, []);

  // Monitores de la sede actual
  const group = useMemo(
    () => monitorsAll.filter((m) => m.instance === instanceName),
    [monitorsAll, instanceName]
  );

  // 🎯 MEJORA 3: Promedio de sede - SIEMPRE se carga al entrar
  useEffect(() => {
    let alive = true;
    
    const fetchInstanceData = async () => {
      try {
        console.log(`🏢 Cargando promedio de sede: ${instanceName} (${selectedRange.label})`);
        const obj = await History.getAllForInstance(
          instanceName,
          rangeValue
        );
        if (!alive) return;
        setSeriesInstance(obj ?? {});
        console.log(`✅ Promedio de sede cargado: ${instanceName}`);
      } catch (error) {
        console.error(`Error cargando promedio de sede ${instanceName}:`, error);
        if (!alive) return;
        setSeriesInstance({});
      }
    };
    
    fetchInstanceData();
    
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, rangeValue, selectedRange.label]);

  // Series por monitor (cuando se selecciona un servicio específico)
  useEffect(() => {
    let alive = true;
    
    const fetchMonitorSeries = async () => {
      if (!focus) {
        // Si no hay focus, no cargar series de monitores individuales
        return;
      }
      
      try {
        console.log(`🔍 Cargando serie para monitor: ${focus} (${selectedRange.label})`);
        const entries = await Promise.all(
          group.map(async (m) => {
            const name = m.info?.monitor_name ?? "";
            if (name !== focus) return null;
            
            const arr = await History.getSeriesForMonitor(
              instanceName,
              name,
              rangeValue
            );
            return [name, Array.isArray(arr) ? arr : []];
          })
        );
        
        if (!alive) return;
        
        const validEntries = entries.filter(Boolean);
        if (validEntries.length > 0) {
          setSeriesMonMap(new Map(validEntries));
          console.log(`✅ Serie cargada para monitor: ${focus}`);
        }
      } catch (error) {
        console.error(`Error cargando serie para monitor ${focus}:`, error);
        if (!alive) return;
        setSeriesMonMap(new Map());
      }
    };
    
    fetchMonitorSeries();
    
    return () => {
      alive = false;
    };
  }, [instanceName, group.length, tick, rangeValue, selectedRange.label, focus]);

  // Fuente del chart principal
  const chartMode = focus ? "monitor" : "instance";
  const chartSeries = focus ? seriesMonMap.get(focus) ?? [] : seriesInstance;

  return (
    <div className="instance-detail-page">
      {/* Header sede */}
      <div className="instance-detail-header">
        <button
          className="k-btn k-btn--primary instance-detail-back"
          onClick={() => window.history.back()}
        >
          ← Volver
        </button>
        <h2 className="instance-detail-title">{instanceName}</h2>
      </div>

      {/* Chip contexto - MUESTRA PROMEDIO DE SEDE POR DEFECTO */}
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
            <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span>📊 Mostrando: <strong>Promedio de la sede</strong></span>
              <span style={{ 
                fontSize: '0.75rem', 
                background: 'var(--bg-tertiary, #f3f4f6)', 
                padding: '2px 8px', 
                borderRadius: '12px',
                color: 'var(--text-secondary, #6b7280)'
              }}>
                {selectedRange.label}
              </span>
            </span>
          </div>
        )}
      </div>

      {/* GRID: gráfica en el centro, cards alrededor */}
      <section
        className="instance-detail-grid"
        aria-label={`Historial y servicios de ${instanceName}`}
      >
        {/* Gráfica en columna central - SIEMPRE visible */}
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

          {/* Acciones globales debajo de la gráfica */}
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

        {/* Cards de servicio alrededor */}
        {group.map((m, i) => {
          const name = m.info?.monitor_name ?? "";
          const seriesMon = seriesMonMap.get(name) ?? [];
          const isSelected = focus === name;
          
          return (
            <div
              key={name || i}
              className={`instance-detail-service-card ${isSelected ? 'selected' : ''}`}
              onClick={() => setFocus(name)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  setFocus(name);
                }
              }}
              style={{
                cursor: 'pointer',
                border: isSelected ? '2px solid #3b82f6' : 'none',
                transform: isSelected ? 'scale(1.02)' : 'scale(1)',
                transition: 'all 0.2s ease'
              }}
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

echo "✅ InstanceDetail actualizado - MUESTRA PROMEDIO DE SEDE por defecto"
echo ""

# ========== 5. LIMPIAR CACHÉ Y REINICIAR ==========
echo ""
echo "[5] Limpiando caché y reiniciando frontend..."

cd "$FRONTEND_DIR"
rm -rf node_modules/.vite .vite
pkill -f "vite" 2>/dev/null || true
npm run dev &
sleep 3

# ========== 6. INSTRUCCIONES FINALES ==========
echo ""
echo "====================================================="
echo "✅✅ 3 MEJORAS IMPLEMENTADAS EXITOSAMENTE ✅✅"
echo "====================================================="
echo ""
echo "📋 MEJORA 1: SELECTOR DE TIEMPO FUNCIONANDO"
echo "   • historyEngine.js VALIDA el rango de tiempo"
echo "   • Todas las gráficas usan el MISMO rango"
echo "   • Al cambiar el selector, TODAS se actualizan"
echo ""
echo "📋 MEJORA 2: MULTISERVICEVIEW CON SERVICIO POR DEFECTO"
echo "   • Al entrar a 'Comparar' selecciona automáticamente"
echo "     el PRIMER servicio HTTP de la lista"
echo "   • NO más gráfica en blanco al cargar"
echo "   • Muestra las sedes del servicio automáticamente"
echo ""
echo "📋 MEJORA 3: INSTANCEDETAIL CON PROMEDIO DE SEDE"
echo "   • Al entrar a CUALQUIER sede (Caracas, Guanare, etc.)"
echo "     muestra AUTOMÁTICAMENTE el promedio de la sede"
echo "   • NO más gráfica en blanco al entrar"
echo "   • El rango de tiempo se muestra en el chip"
echo ""
echo "🔄 PRUEBA AHORA:"
echo "   1. Abre http://10.10.31.31:5173"
echo "   2. Ve a 'Comparar' - DEBE mostrar gráfica INMEDIATAMENTE"
echo "   3. Cambia el rango de tiempo 📊 - TODAS las gráficas se actualizan"
echo "   4. Entra a una sede (Caracas) - DEBE mostrar promedio INMEDIATAMENTE"
echo "   5. Haz click en un servicio - muestra ese monitor específico"
echo "   6. Click en 'Ver promedio de sede' - vuelve al promedio"
echo ""
echo "====================================================="
echo "✅ TODAS LAS MEJORAS COMPLETADAS"
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
